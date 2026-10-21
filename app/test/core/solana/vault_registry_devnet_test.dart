// SPDX-License-Identifier: GPL-3.0-or-later

// Интеграционные тесты против devnet, по умолчанию пропускаются.
// Чтение постоянной тестовой записи — нужна только сеть:
//   ANCHORKEEP_DEVNET=1 flutter test test/core/solana/vault_registry_devnet_test.dart
// Создание и обновление записи — нужен кошелёк с devnet-SOL:
//   ANCHORKEEP_DEVNET_KEYPAIR=~/.config/solana/id.json \
//     flutter test test/core/solana/vault_registry_devnet_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/solana.dart';

final _keypairPath = Platform.environment['ANCHORKEEP_DEVNET_KEYPAIR'];
final _devnet = Platform.environment['ANCHORKEEP_DEVNET'] == '1';

/// Постоянная запись в devnet для теста чтения, создана 2026-10-21 кошельком
/// FZ3G…: vaultId 00..0f, version 1, hash = sha256('anchorkeep devnet fixture').
/// Не заверять поверх неё новые версии — тест сломается.
final fixtureOwner = Ed25519HDPublicKey.fromBase58(
  'FZ3GPBucdPk3J135uzNgSKwGKMoA3voqypEz3vKXgZcz',
);
final fixtureVaultId = List<int>.generate(16, (i) => i);
const fixtureHashHex =
    '0e1b184a61564ebee0bc7a177d135592919e83c62f9c8fd55d3072b8ade04e5e';

/// Кошелёк solana CLI: первые 32 байта — seed. Keypair хранит ссылку на seed,
/// поэтому затираем только исходный буфер (ADR 0003).
Future<Ed25519HDKeyPair> loadKeypair(String path) async {
  final file = File(path.replaceFirst('~', Platform.environment['HOME']!));
  final bytes = (jsonDecode(await file.readAsString()) as List).cast<int>();
  try {
    return await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: Uint8List.fromList(bytes.sublist(0, 32)),
    );
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}

List<int> randomBytes(int n) {
  final rnd = Random.secure();
  return List<int>.generate(n, (_) => rnd.nextInt(256));
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

VaultRegistry devnetRegistry() => VaultRegistry(
  SolanaClient(
    rpcUrl: SolanaConfig.rpcUrl,
    websocketUrl: SolanaConfig.websocketUrl,
  ),
);

void main() {
  test(
    'devnet: чтение постоянной записи VaultRecord',
    () async {
      final record = await devnetRegistry().fetchRecord(
        fixtureOwner,
        fixtureVaultId,
      );

      expect(record, isNotNull);
      expect(record!.owner, fixtureOwner);
      expect(record.vaultId, fixtureVaultId);
      expect(record.version, 1);
      expect(hex(record.hash), fixtureHashHex);
      expect(record.updatedAt.isAfter(DateTime.utc(2026, 10, 21)), isTrue);
      expect(record.bump, inInclusiveRange(0, 255));
    },
    skip: _devnet ? false : 'нет ANCHORKEEP_DEVNET=1',
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'devnet: незаверенный сейф → null',
    () async {
      final record = await devnetRegistry().fetchRecord(
        fixtureOwner,
        randomBytes(vaultIdLength),
      );
      expect(record, isNull);
    },
    skip: _devnet ? false : 'нет ANCHORKEEP_DEVNET=1',
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'devnet: initialize_vault создаёт запись, commit_version обновляет',
    () async {
      final registry = devnetRegistry();
      final owner = await loadKeypair(_keypairPath!);
      final vaultId = randomBytes(vaultIdLength);

      final firstHash = randomBytes(vaultHashLength);
      await registry.initializeVault(
        owner: owner,
        vaultId: vaultId,
        hash: firstHash,
        version: 3,
      );
      var record = (await registry.fetchRecord(owner.publicKey, vaultId))!;
      expect(record.owner, owner.publicKey);
      expect(record.vaultId, vaultId);
      expect(record.version, 3);
      expect(record.hash, firstHash);

      final secondHash = randomBytes(vaultHashLength);
      await registry.commitVersion(
        owner: owner,
        vaultId: vaultId,
        hash: secondHash,
        version: 7,
      );
      record = (await registry.fetchRecord(owner.publicKey, vaultId))!;
      expect(record.version, 7);
      expect(record.hash, secondHash);

      // Та же версия отклоняется программой (VersionMismatch), запись цела
      await expectLater(
        registry.commitVersion(
          owner: owner,
          vaultId: vaultId,
          hash: randomBytes(vaultHashLength),
          version: 7,
        ),
        // VersionMismatch = 6001 = 0x1771 в логах симуляции
        throwsA(predicate((Object e) => e.toString().contains('0x1771'))),
      );
      record = (await registry.fetchRecord(owner.publicKey, vaultId))!;
      expect(record.hash, secondHash);
    },
    skip: _keypairPath == null ? 'нет ANCHORKEEP_DEVNET_KEYPAIR' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
