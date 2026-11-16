// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:anchorkeep/core/solana/backup_verification.dart';
import 'package:anchorkeep/core/solana/chain_failure.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:cryptography/cryptography.dart';
import 'package:solana/solana.dart';

/// Итог заверения: подпись транзакции и повторная проверка файла.
class AnchorResult {
  const AnchorResult({required this.signature, required this.status});

  final String signature;

  /// [AnchorStatus.offline] — транзакция прошла, но перепроверить не вышло.
  final AnchorStatus status;
}

/// Заверяет файл сейфа [bytes] в цепочке: первое заверение —
/// `initialize_vault`, дальше — `commit_version`.
///
/// Версия в цепочке = `revision` файла (ADR 0006). Если она уже заверена,
/// бросает [AlreadyAnchoredFailure] до отправки транзакции. Сетевые и
/// RPC-ошибки приводятся к [ChainFailure]. Ключ [owner] не сохраняется.
Future<AnchorResult> anchorVaultFile({
  required Uint8List bytes,
  required Ed25519HDKeyPair owner,
  required VaultRegistry registry,
}) async {
  try {
    final header = VaultFile.decode(bytes).header;
    final hash = (await Sha256().hash(bytes)).bytes;
    final record = await registry.fetchRecord(owner.publicKey, header.vaultId);
    if (record != null && header.revision <= record.version) {
      throw const AlreadyAnchoredFailure();
    }
    final signature = record == null
        ? await registry.initializeVault(
            owner: owner,
            vaultId: header.vaultId,
            hash: hash,
            version: header.revision,
          )
        : await registry.commitVersion(
            owner: owner,
            vaultId: header.vaultId,
            hash: hash,
            version: header.revision,
          );
    final status = await verifyVaultFile(
      fileBytes: bytes,
      owner: owner.publicKey,
      fetch: registry.fetchRecord,
    );
    return AnchorResult(signature: signature, status: status);
  } on FormatException {
    // Не .akv или чужой аккаунт — ошибка вызывающего, не цепочки
    rethrow;
  } on Object catch (error) {
    throw classifyChainError(error);
  }
}
