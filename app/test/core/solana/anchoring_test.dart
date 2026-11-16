// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/solana/anchoring.dart';
import 'package:anchorkeep/core/solana/backup_verification.dart';
import 'package:anchorkeep/core/solana/chain_failure.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/solana.dart';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

/// Реестр без сети: хранит «цепочку» в памяти, ошибки задаются тестом.
class FakeRegistry extends VaultRegistry {
  FakeRegistry({
    this.record,
    this.fetchError,
    this.sendError,
    this.refetchError,
  }) : super(
         SolanaClient(
           rpcUrl: Uri.parse('http://127.0.0.1:1'),
           websocketUrl: Uri.parse('ws://127.0.0.1:2'),
         ),
       );

  VaultRecord? record;
  Object? fetchError;
  Object? sendError;
  final calls = <String>[];

  /// Ошибка только на повторном чтении (после отправки).
  Object? refetchError;

  @override
  Future<VaultRecord?> fetchRecord(
    Ed25519HDPublicKey owner,
    List<int> vaultId,
  ) async {
    calls.add('fetch');
    if (calls.where((c) => c == 'fetch').length > 1 && refetchError != null) {
      throw refetchError!;
    }
    if (fetchError != null) throw fetchError!;
    return record;
  }

  Future<String> _send(String name, List<int> id, List<int> hash, int v) async {
    calls.add(name);
    if (sendError != null) throw sendError!;
    record = VaultRecord(
      owner: record?.owner ?? (await Ed25519HDKeyPair.random()).publicKey,
      vaultId: Uint8List.fromList(id),
      version: v,
      hash: Uint8List.fromList(hash),
      updatedAt: DateTime.utc(2026, 10, 21),
      bump: 255,
    );
    return 'sig-$name-0123456789';
  }

  @override
  Future<String> initializeVault({
    required Ed25519HDKeyPair owner,
    required List<int> vaultId,
    required List<int> hash,
    required int version,
  }) => _send('init', vaultId, hash, version);

  @override
  Future<String> commitVersion({
    required Ed25519HDKeyPair owner,
    required List<int> vaultId,
    required List<int> hash,
    required int version,
  }) => _send('commit', vaultId, hash, version);
}

void main() {
  late VaultSession session;
  late Ed25519HDKeyPair owner;

  setUp(() async {
    owner = await Ed25519HDKeyPair.random();
    session = await createVault('пароль', kdf: fast());
  });

  Future<VaultRecord> recordFor(Uint8List file) async {
    final h = VaultFile.decode(file).header;
    return VaultRecord(
      owner: owner.publicKey,
      vaultId: h.vaultId,
      version: h.revision,
      hash: Uint8List.fromList((await Sha256().hash(file)).bytes),
      updatedAt: DateTime.utc(2026, 10, 21),
      bump: 255,
    );
  }

  Future<ChainFailure> failureOf(Uint8List file, FakeRegistry registry) async {
    try {
      await anchorVaultFile(bytes: file, owner: owner, registry: registry);
    } on ChainFailure catch (e) {
      return e;
    }
    fail('ожидалась ChainFailure');
  }

  test('сейф не заверяли → initializeVault, затем verified', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry();
    // fake сам не знает owner: проверяем только поток вызовов и статус
    final result = await anchorVaultFile(
      bytes: file,
      owner: owner,
      registry: registry,
    );
    expect(registry.calls, ['fetch', 'init', 'fetch']);
    expect(result.signature, 'sig-init-0123456789');
    expect(result.status, AnchorStatus.verified);
  });

  test('запись есть, версия новее → commitVersion', () async {
    final first = await saveVault(session);
    final second = await saveVault(session);
    final registry = FakeRegistry(record: await recordFor(first));
    final result = await anchorVaultFile(
      bytes: second,
      owner: owner,
      registry: registry,
    );
    expect(registry.calls, ['fetch', 'commit', 'fetch']);
    expect(result.status, AnchorStatus.verified);
  });

  test('версия уже заверена → AlreadyAnchoredFailure без отправки', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(record: await recordFor(file));
    expect(await failureOf(file, registry), isA<AlreadyAnchoredFailure>());
    expect(registry.calls, ['fetch']);
  });

  test('старый бэкап при новой версии в цепочке → AlreadyAnchored', () async {
    final backup = await saveVault(session);
    final current = await saveVault(session);
    final registry = FakeRegistry(record: await recordFor(current));
    expect(await failureOf(backup, registry), isA<AlreadyAnchoredFailure>());
  });

  test('сеть недоступна при чтении → OfflineFailure', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(fetchError: const SocketException('down'));
    expect(await failureOf(file, registry), isA<OfflineFailure>());
  });

  test('таймаут при отправке → OfflineFailure', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(sendError: TimeoutException('rpc'));
    expect(await failureOf(file, registry), isA<OfflineFailure>());
  });

  test('нет SOL на комиссию → NoSolFailure', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(
      sendError: const JsonRpcException(
        'Transaction simulation failed',
        -32002,
        {'err': 'InsufficientFundsForFee'},
      ),
    );
    expect(await failureOf(file, registry), isA<NoSolFailure>());
  });

  test('HTTP 429 → RateLimitedFailure', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(
      sendError: const HttpException(429, 'Too Many Requests'),
    );
    expect(await failureOf(file, registry), isA<RateLimitedFailure>());
  });

  test('прочая ошибка программы → UnknownFailure', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(
      sendError: const JsonRpcException('custom', -32000, null),
    );
    expect(await failureOf(file, registry), isA<UnknownFailure>());
  });

  test('транзакция прошла, перепроверка офлайн → status offline', () async {
    final file = await saveVault(session);
    final registry = FakeRegistry(refetchError: const SocketException('down'));
    final result = await anchorVaultFile(
      bytes: file,
      owner: owner,
      registry: registry,
    );
    expect(result.status, AnchorStatus.offline);
    expect(result.signature, isNotEmpty);
  });

  test('не .akv → FormatException, не ChainFailure', () async {
    final registry = FakeRegistry();
    await expectLater(
      anchorVaultFile(
        bytes: Uint8List.fromList([1, 2, 3]),
        owner: owner,
        registry: registry,
      ),
      throwsFormatException,
    );
    expect(registry.calls, isEmpty);
  });
}
