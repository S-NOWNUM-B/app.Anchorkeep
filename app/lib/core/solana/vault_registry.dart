// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:solana/anchor.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

// Клиент программы `vault_registry` без IDL-генерации (ADR 0003): PDA,
// discriminator и borsh-аргументы собираются вручную по
// `program/idl/vault_registry.json`.

/// Длина `vaultId` из заголовка `.akv`.
const vaultIdLength = 16;

/// SHA-256 всего `.akv`-файла.
const vaultHashLength = 32;

/// Первые 8 байт `sha256("global:<method>")` и `sha256("account:<Name>")`.
/// Сверяются с IDL в тестах — переименование в программе их сломает.
const initializeVaultDiscriminator = [48, 191, 163, 44, 71, 129, 63, 164];
const commitVersionDiscriminator = [223, 216, 39, 114, 120, 241, 138, 238];
const vaultRecordDiscriminator = [47, 1, 218, 116, 82, 70, 124, 119];

/// Размер аккаунта: discriminator 8 | owner 32 | vault_id 16 | version 8 |
/// hash 32 | updated_at 8 | bump 1.
const vaultRecordSize = 8 + 32 + vaultIdLength + 8 + vaultHashLength + 8 + 1;

final _programId = Ed25519HDPublicKey.fromBase58(SolanaConfig.programId);

/// PDA записи сейфа: seeds `["vault", owner, vault_id]`.
Future<Ed25519HDPublicKey> vaultRecordAddress(
  Ed25519HDPublicKey owner,
  List<int> vaultId,
) {
  _checkLength(vaultId, vaultIdLength, 'vaultId');
  return Ed25519HDPublicKey.findProgramAddress(
    seeds: [utf8.encode('vault'), owner.bytes, vaultId],
    programId: _programId,
  );
}

/// `initialize_vault(vault_id, hash, version)`; owner — signer и payer.
/// `version` — `revision` заверяемого файла (ADR 0006).
Future<Instruction> initializeVaultInstruction({
  required Ed25519HDPublicKey owner,
  required List<int> vaultId,
  required List<int> hash,
  required int version,
}) async {
  _checkLength(hash, vaultHashLength, 'hash');
  final record = await vaultRecordAddress(owner, vaultId);
  return AnchorInstruction.withDiscriminator(
    programId: _programId,
    discriminator: ByteArray(initializeVaultDiscriminator),
    accounts: [
      AccountMeta.writeable(pubKey: owner, isSigner: true),
      AccountMeta.writeable(pubKey: record, isSigner: false),
      AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
    ],
    arguments: ByteArray([...vaultId, ...hash, ..._u64(version)]),
  );
}

/// `commit_version(new_hash, new_version)`; программа требует
/// `version > record.version`, иначе ошибка `VersionMismatch`.
Future<Instruction> commitVersionInstruction({
  required Ed25519HDPublicKey owner,
  required List<int> vaultId,
  required List<int> hash,
  required int version,
}) async {
  _checkLength(hash, vaultHashLength, 'hash');
  final record = await vaultRecordAddress(owner, vaultId);
  return AnchorInstruction.withDiscriminator(
    programId: _programId,
    discriminator: ByteArray(commitVersionDiscriminator),
    accounts: [
      AccountMeta.writeable(pubKey: record, isSigner: false),
      AccountMeta.readonly(pubKey: owner, isSigner: true),
    ],
    arguments: ByteArray([...hash, ..._u64(version)]),
  );
}

/// Запись сейфа в цепочке.
class VaultRecord {
  const VaultRecord({
    required this.owner,
    required this.vaultId,
    required this.version,
    required this.hash,
    required this.updatedAt,
  });

  /// Разбор данных аккаунта. Чужой аккаунт или битые данные →
  /// [FormatException].
  factory VaultRecord.decode(List<int> data) {
    if (data.length != vaultRecordSize) {
      throw const FormatException('VaultRecord: неверный размер');
    }
    for (var i = 0; i < 8; i++) {
      if (data[i] != vaultRecordDiscriminator[i]) {
        throw const FormatException('VaultRecord: чужой discriminator');
      }
    }
    final bytes = Uint8List.fromList(data);
    final view = ByteData.sublistView(bytes);
    return VaultRecord(
      owner: Ed25519HDPublicKey(bytes.sublist(8, 40)),
      vaultId: bytes.sublist(40, 56),
      version: view.getUint64(56, Endian.little),
      hash: bytes.sublist(64, 96),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        view.getInt64(96, Endian.little) * 1000,
        isUtc: true,
      ),
    );
  }

  final Ed25519HDPublicKey owner;
  final Uint8List vaultId;

  /// `revision` заверенного файла.
  final int version;

  /// SHA-256 заверенного файла.
  final Uint8List hash;
  final DateTime updatedAt;
}

/// Отправка инструкций `vault_registry`. Ключ владельца не хранится —
/// передаётся на время вызова.
class VaultRegistry {
  VaultRegistry(this._client);

  final SolanaClient _client;

  /// Первое заверение сейфа. Возвращает подпись транзакции.
  Future<String> initializeVault({
    required Ed25519HDKeyPair owner,
    required List<int> vaultId,
    required List<int> hash,
    required int version,
  }) async => _send(
    owner,
    await initializeVaultInstruction(
      owner: owner.publicKey,
      vaultId: vaultId,
      hash: hash,
      version: version,
    ),
  );

  /// Заверение новой версии уже созданной записи.
  Future<String> commitVersion({
    required Ed25519HDKeyPair owner,
    required List<int> vaultId,
    required List<int> hash,
    required int version,
  }) async => _send(
    owner,
    await commitVersionInstruction(
      owner: owner.publicKey,
      vaultId: vaultId,
      hash: hash,
      version: version,
    ),
  );

  Future<String> _send(Ed25519HDKeyPair owner, Instruction ix) =>
      _client.sendAndConfirmTransaction(
        message: Message.only(ix),
        signers: [owner],
        commitment: Commitment.confirmed,
      );
}

void _checkLength(List<int> value, int length, String name) {
  if (value.length != length) {
    throw ArgumentError.value(value.length, name, 'ожидалось $length байт');
  }
}

/// borsh u64: little-endian. `revision` ограничен 2^53 (vault_file.dart),
/// поэтому отрицательные значения — ошибка вызывающего кода.
List<int> _u64(int value) {
  if (value < 0) throw ArgumentError.value(value, 'version', 'меньше нуля');
  return (ByteData(8)..setUint64(0, value, Endian.little)).buffer.asUint8List();
}
