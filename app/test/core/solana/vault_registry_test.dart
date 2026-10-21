// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/anchor.dart';
import 'package:solana/encoder.dart' show AccountMeta;
import 'package:solana/solana.dart';

final owner = Ed25519HDPublicKey.fromBase58(
  'FZ3GPBucdPk3J135uzNgSKwGKMoA3voqypEz3vKXgZcz',
);
final vaultId = List<int>.generate(16, (i) => i);
final hash = List<int>.filled(32, 0xab);

/// IDL из program/idl (flutter test запускается из app/).
Future<Map<String, Object?>> loadIdl() async =>
    jsonDecode(await File('../program/idl/vault_registry.json').readAsString())
        as Map<String, Object?>;

List<int> idlDiscriminator(Map<String, Object?> idl, String key, String name) {
  final items = (idl[key]! as List).cast<Map<String, Object?>>();
  final item = items.firstWhere((e) => e['name'] == name);
  return (item['discriminator']! as List).cast<int>();
}

/// Данные аккаунта VaultRecord в раскладке программы.
Uint8List recordBytes({
  List<int> discriminator = vaultRecordDiscriminator,
  int version = 42,
  int updatedAt = 1792540800,
}) {
  final data = ByteData(vaultRecordSize);
  final bytes = data.buffer.asUint8List()
    ..setAll(0, discriminator)
    ..setAll(8, owner.bytes)
    ..setAll(40, vaultId)
    ..setAll(64, hash);
  data
    ..setUint64(56, version, Endian.little)
    ..setInt64(96, updatedAt, Endian.little)
    ..setUint8(104, 254);
  return bytes;
}

void main() {
  group('discriminator', () {
    test('совпадают с sha256 по правилам Anchor', () async {
      expect(
        await computeDiscriminator('global', 'initialize_vault'),
        initializeVaultDiscriminator,
      );
      expect(
        await computeDiscriminator('global', 'commit_version'),
        commitVersionDiscriminator,
      );
      expect(
        await computeDiscriminator('account', 'VaultRecord'),
        vaultRecordDiscriminator,
      );
    });

    test('совпадают с закоммиченным IDL', () async {
      final idl = await loadIdl();
      expect(
        idlDiscriminator(idl, 'instructions', 'initialize_vault'),
        initializeVaultDiscriminator,
      );
      expect(
        idlDiscriminator(idl, 'instructions', 'commit_version'),
        commitVersionDiscriminator,
      );
      expect(
        idlDiscriminator(idl, 'accounts', 'VaultRecord'),
        vaultRecordDiscriminator,
      );
    });
  });

  test('PDA совпадает с solana find-program-derived-address', () async {
    // solana find-program-derived-address <programId> string:vault
    //   pubkey:FZ3G… hex:000102030405060708090a0b0c0d0e0f
    final pda = await vaultRecordAddress(owner, vaultId);
    expect(pda.toBase58(), 'Ei1MMD3azvBW7EQW8T4qH7srF3SpS6AsML2bvNiFmW8X');
  });

  test('initialize_vault: данные и аккаунты как в IDL', () async {
    final ix = await initializeVaultInstruction(
      owner: owner,
      vaultId: vaultId,
      hash: hash,
      version: 0x0102030405,
    );
    final data = ix.data.toList();

    expect(ix.programId.toBase58(), SolanaConfig.programId);
    expect(data.length, 8 + 16 + 32 + 8);
    expect(data.sublist(0, 8), initializeVaultDiscriminator);
    expect(data.sublist(8, 24), vaultId);
    expect(data.sublist(24, 56), hash);
    expect(data.sublist(56), [5, 4, 3, 2, 1, 0, 0, 0]);

    final pda = await vaultRecordAddress(owner, vaultId);
    expect(
      ix.accounts.map((AccountMeta a) => (a.pubKey, a.isWriteable, a.isSigner)),
      [
        (owner, true, true),
        (pda, true, false),
        (SystemProgram.id, false, false),
      ],
    );
  });

  test('commit_version: данные и аккаунты как в IDL', () async {
    final ix = await commitVersionInstruction(
      owner: owner,
      vaultId: vaultId,
      hash: hash,
      version: 43,
    );
    final data = ix.data.toList();

    expect(data.length, 8 + 32 + 8);
    expect(data.sublist(0, 8), commitVersionDiscriminator);
    expect(data.sublist(8, 40), hash);
    expect(data.sublist(40), [43, 0, 0, 0, 0, 0, 0, 0]);

    final pda = await vaultRecordAddress(owner, vaultId);
    expect(
      ix.accounts.map((AccountMeta a) => (a.pubKey, a.isWriteable, a.isSigner)),
      [(pda, true, false), (owner, false, true)],
    );
  });

  test('неверные длины и отрицательная версия → ArgumentError', () {
    expect(
      () => vaultRecordAddress(owner, List.filled(15, 0)),
      throwsArgumentError,
    );
    expect(
      () => initializeVaultInstruction(
        owner: owner,
        vaultId: vaultId,
        hash: List.filled(31, 0),
        version: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => commitVersionInstruction(
        owner: owner,
        vaultId: vaultId,
        hash: hash,
        version: -1,
      ),
      throwsArgumentError,
    );
  });

  group('VaultRecord.decode', () {
    test('разбирает все поля', () {
      final r = VaultRecord.decode(recordBytes());

      expect(r.owner, owner);
      expect(r.vaultId, vaultId);
      expect(r.version, 42);
      expect(r.hash, hash);
      expect(r.updatedAt, DateTime.utc(2026, 10, 21));
      expect(r.bump, 254);
    });

    test('чужой discriminator → FormatException', () {
      expect(
        () => VaultRecord.decode(recordBytes(discriminator: List.filled(8, 0))),
        throwsFormatException,
      );
    });

    test('неверный размер → FormatException', () {
      expect(
        () => VaultRecord.decode(recordBytes().sublist(0, 100)),
        throwsFormatException,
      );
    });
  });
}
