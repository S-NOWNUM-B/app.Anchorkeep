// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:anchorkeep/core/vault/entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

enum NearbyStage {
  idle,
  waitingForTap,
  finding,
  approval,
  connecting,
  transferring,
  received,
  success,
  error,
}

/// Android: NFC сверяет одноразовый ID рекламируемого endpoint. Содержимое
/// заметки идёт только по защищённому каналу Nearby после подтверждения.
class NearbyTransferController extends ChangeNotifier {
  NearbyTransferController({required this.saveNote}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tokenRead' && call.arguments is String) {
        _expectedToken = call.arguments as String;
        stage = NearbyStage.finding;
        notifyListeners();
        _tryMatch();
      }
    });
  }

  final Future<void> Function(String title, String text) saveNote;
  static const _channel = MethodChannel('anchorkeep/nearby_nfc');
  static const _serviceId = 'app.anchorkeep.anchorkeep';
  final _nearby = Nearby();
  final Map<String, String> _found = {};
  NearbyStage stage = NearbyStage.idle;
  bool sending = false;
  String? error;
  String? authCode;
  String? receivedTitle;
  String? receivedText;
  String? _expectedToken;
  String? _endpoint;
  Entry? _selectedNote;
  bool _disposed = false;
  bool _waitingAckDelivery = false;
  Timer? _cleanupTimer;

  Future<void> startSending(Entry note) async {
    sending = true;
    _selectedNote = note;
    try {
      await _prepare(requireHce: true);
      final rng = Random.secure();
      final token = List.generate(
        8,
        (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _channel.invokeMethod<void>('setToken', {'token': token});
      final started = await _nearby.startAdvertising(
        token,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _serviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      if (!started) throw StateError('advertising unavailable');
      stage = NearbyStage.waitingForTap;
      notifyListeners();
    } on StateError catch (error) {
      _fail(error.message.toString());
    } catch (_) {
      _fail('could not start nearby sharing');
    }
  }

  Future<void> startReceiving() async {
    sending = false;
    try {
      await _prepare(requireHce: false);
      final started = await _nearby.startDiscovery(
        'Anchorkeep',
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _serviceId,
        onEndpointFound: (id, name, _) {
          _found[id] = name;
          _tryMatch();
        },
        onEndpointLost: (id) {
          if (id != null) _found.remove(id);
        },
      );
      if (!started) throw StateError('discovery unavailable');
      await _channel.invokeMethod<void>('startReader');
      stage = NearbyStage.waitingForTap;
      notifyListeners();
    } on StateError catch (error) {
      _fail(error.message.toString());
    } catch (_) {
      _fail('could not start nearby receiving');
    }
  }

  Future<void> openSettings() async {
    if (error == 'permission denied') {
      await openAppSettings();
    } else if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openNfcSettings');
    }
  }

  Future<void> _prepare({required bool requireHce}) async {
    if (!Platform.isAndroid) throw UnsupportedError('Android only');
    final availability = await _channel.invokeMapMethod<String, dynamic>(
      'available',
    );
    if (availability?['enabled'] != true ||
        (requireHce && availability?['hce'] != true)) {
      throw StateError('NFC unavailable');
    }
    final sdk = await _channel.invokeMethod<int>('sdkInt') ?? 0;
    final required = <Permission>[
      if (sdk <= 32) Permission.location,
      if (sdk >= 31) ...[
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ],
      if (sdk >= 33) Permission.nearbyWifiDevices,
    ];
    for (final permission in required) {
      final status = await permission.request();
      if (!status.isGranted) throw StateError('permission denied');
    }
  }

  void _tryMatch() {
    final token = _expectedToken;
    if (token == null || _endpoint != null || sending) return;
    for (final item in _found.entries) {
      if (item.value != token) continue;
      _endpoint = item.key;
      unawaited(_channel.invokeMethod<void>('stopReader'));
      unawaited(_nearby.stopDiscovery());
      unawaited(_request(item.key));
      return;
    }
  }

  Future<void> _request(String id) async {
    try {
      final requested = await _nearby.requestConnection(
        'Anchorkeep',
        id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      if (!requested) _fail('connection rejected');
    } catch (_) {
      _fail('connection failed');
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    if (_disposed) return;
    if (!sending && info.endpointName != _expectedToken) {
      unawaited(_nearby.rejectConnection(id));
      return;
    }
    if (_endpoint != null && _endpoint != id) {
      unawaited(_nearby.rejectConnection(id));
      return;
    }
    _endpoint = id;
    authCode = info.authenticationToken;
    stage = NearbyStage.approval;
    notifyListeners();
  }

  Future<void> approve() async {
    final id = _endpoint;
    if (id == null) return;
    try {
      final accepted = await _nearby.acceptConnection(
        id,
        onPayLoadRecieved: _onPayload,
        onPayloadTransferUpdate: _onTransferUpdate,
      );
      if (!accepted) throw StateError('accept failed');
      stage = NearbyStage.connecting;
      notifyListeners();
    } catch (_) {
      _fail('connection failed');
    }
  }

  void _onConnectionResult(String id, Status status) {
    if (_disposed || id != _endpoint) return;
    if (status != Status.CONNECTED) {
      _fail('connection rejected');
      return;
    }
    if (sending) {
      final note = _selectedNote;
      if (note == null) {
        _fail('note missing');
        return;
      }
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'type': 'note',
            'title': note.title,
            'text': note.fields['text'] ?? '',
          }),
        ),
      );
      if (bytes.length > 32 * 1024) {
        _fail('note too large');
        return;
      }
      stage = NearbyStage.transferring;
      notifyListeners();
      unawaited(
        _nearby
            .sendBytesPayload(id, bytes)
            .catchError((Object _) => _fail('send failed')),
      );
    } else {
      stage = NearbyStage.transferring;
      notifyListeners();
    }
  }

  void _onPayload(String id, Payload payload) {
    if (_disposed || id != _endpoint || payload.type != PayloadType.BYTES) {
      return;
    }
    final bytes = payload.bytes;
    if (bytes == null || bytes.length > 32 * 1024) {
      _fail('invalid payload');
      return;
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (sending && decoded['type'] == 'ack') {
        stage = NearbyStage.success;
        notifyListeners();
        unawaited(_stopTransport());
      } else if (!sending &&
          decoded['type'] == 'note' &&
          decoded['title'] is String &&
          decoded['text'] is String) {
        receivedTitle = decoded['title'] as String;
        receivedText = decoded['text'] as String;
        if (receivedTitle!.isEmpty || receivedText!.isEmpty) {
          throw const FormatException();
        }
        stage = NearbyStage.received;
        notifyListeners();
      } else {
        throw const FormatException();
      }
    } catch (_) {
      _fail('invalid payload');
    }
  }

  void _onTransferUpdate(String id, PayloadTransferUpdate update) {
    if (_disposed || id != _endpoint || !_waitingAckDelivery) return;
    if (update.status == PayloadStatus.SUCCESS ||
        update.status == PayloadStatus.FAILURE) {
      _waitingAckDelivery = false;
      _cleanupTimer?.cancel();
      unawaited(_stopTransport());
    }
  }

  Future<void> acceptNote() async {
    final title = receivedTitle;
    final text = receivedText;
    final id = _endpoint;
    if (title == null || text == null || id == null) return;
    try {
      await saveNote(title, text);
      _waitingAckDelivery = true;
      await _nearby.sendBytesPayload(
        id,
        Uint8List.fromList(utf8.encode('{"type":"ack"}')),
      );
      receivedTitle = null;
      receivedText = null;
      stage = NearbyStage.success;
      notifyListeners();
      _cleanupTimer = Timer(const Duration(seconds: 5), () {
        _waitingAckDelivery = false;
        unawaited(_stopTransport());
      });
    } catch (_) {
      _fail('could not save note');
    }
  }

  void _onDisconnected(String id) {
    if (_disposed || id != _endpoint || stage == NearbyStage.success) return;
    _fail('connection lost');
  }

  void _fail(String reason) {
    if (_disposed) return;
    error = reason;
    stage = NearbyStage.error;
    notifyListeners();
    unawaited(_stopTransport());
  }

  Future<void> _stopTransport() async {
    try {
      await _channel.invokeMethod<void>('stopReader');
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('setToken', {'token': null});
    } catch (_) {}
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
    try {
      await _nearby.stopAllEndpoints();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _cleanupTimer?.cancel();
    _channel.setMethodCallHandler(null);
    unawaited(_stopTransport());
    super.dispose();
  }
}
