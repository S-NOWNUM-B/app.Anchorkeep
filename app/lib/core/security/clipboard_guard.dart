// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/services.dart';

/// Доступ к системному буферу обмена (подменяется в тестах).
abstract interface class ClipboardPort {
  Future<void> write(String text);

  /// `null`, если буфер пуст или недоступен для чтения.
  Future<String?> read();
}

class SystemClipboard implements ClipboardPort {
  const SystemClipboard();

  @override
  Future<void> write(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> read() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}

/// Копирует секрет в буфер и очищает его через [delay] (30 с по умолчанию).
/// Очищает только если там всё ещё наш секрет: если пользователь успел
/// скопировать что-то другое, его данные не трогаем. Если буфер нельзя
/// прочитать (Android 10+ в фоне), очищаем вслепую: оставить пароль хуже.
class ClipboardGuard {
  ClipboardGuard(
    this._port, {
    this.delay = const Duration(seconds: 30),
    this.schedule = Timer.new,
  });

  final ClipboardPort _port;
  final Duration delay;

  /// Как ставить таймер (подменяется в тестах).
  final Timer Function(Duration, void Function()) schedule;

  Timer? _timer;
  String? _copied;

  Future<void> copy(String text) async {
    _timer?.cancel();
    await _port.write(text);
    _copied = text;
    _timer = schedule(delay, () => unawaited(clear()));
  }

  /// Очистить сейчас (по таймеру или при блокировке сейфа).
  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    final mine = _copied;
    _copied = null; // не держим секрет в памяти дольше нужного
    if (mine == null) return;
    final current = await _port.read();
    if (current == null || current == mine) await _port.write('');
  }
}
