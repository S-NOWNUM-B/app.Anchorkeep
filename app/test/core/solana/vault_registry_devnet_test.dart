// SPDX-License-Identifier: GPL-3.0-or-later

// Интеграционный тест против devnet: создаёт и обновляет VaultRecord.
// Нужны сеть и кошелёк с devnet-SOL, поэтому по умолчанию пропускается:
//   ANCHORKEEP_DEVNET_KEYPAIR=~/.config/solana/id.json \
//     flutter test test/core/solana/vault_registry_devnet_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

final _keypairPath = Platform.environment['ANCHORKEEP_DEVNET_KEYPAIR'];

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

Future<VaultRecord> fetchRecord(
  SolanaClient client,
  Ed25519HDPublicKey owner,
  List<int> vaultId,
) async {
  final address = await vaultRecordAddress(owner, vaultId);
  final info = await client.rpcClient.getAccountInfo(
    address.toBase58(),
    encoding: Encoding.base64,
    commitment: Commitment.confirmed,
  );
  final data = info.value!.data! as BinaryAccountData;
  return VaultRecord.decode(data.data);
}

void main() {
  test(
    'devnet: initialize_vault создаёт запись, commit_version обновляет',
    () async {
      final client = SolanaClient(
        rpcUrl: SolanaConfig.rpcUrl,
        websocketUrl: SolanaConfig.websocketUrl,
      );
      final registry = VaultRegistry(client);
      final owner = await loadKeypair(_keypairPath!);
      final vaultId = randomBytes(vaultIdLength);

      final firstHash = randomBytes(vaultHashLength);
      await registry.initializeVault(
        owner: owner,
        vaultId: vaultId,
        hash: firstHash,
        version: 3,
      );
      var record = await fetchRecord(client, owner.publicKey, vaultId);
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
      record = await fetchRecord(client, owner.publicKey, vaultId);
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
      record = await fetchRecord(client, owner.publicKey, vaultId);
      expect(record.hash, secondHash);
    },
    skip: _keypairPath == null ? 'нет ANCHORKEEP_DEVNET_KEYPAIR' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
