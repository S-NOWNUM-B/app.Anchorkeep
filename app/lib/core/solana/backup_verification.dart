// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:cryptography/cryptography.dart';
import 'package:solana/solana.dart';

/// Результат проверки файла сейфа или бэкапа по цепочке (F9).
enum AnchorStatus {
  /// Хеш совпал с заверенным: это последняя заверенная версия.
  verified,

  /// Файл старше заверенной версии: подсунули старый бэкап.
  outdated,

  /// Хеш не совпал, а версия не старше: файл не заверен или изменён.
  /// Так же выглядит свежий файл после правок или смены пароля (ADR 0007),
  /// пока его не заверили заново.
  unknown,

  /// Сейф ещё ни разу не заверяли.
  notAnchored,

  /// Цепочка недоступна: нет сети или RPC не ответил.
  offline,
}

/// Чтение записи сейфа (в приложении — [VaultRegistry.fetchRecord]).
typedef FetchVaultRecord = Future<VaultRecord?> Function(
  Ed25519HDPublicKey owner,
  List<int> vaultId,
);

/// Сравнение файла с записью в цепочке, без сети.
/// [record] == `null` — сейф не заверен.
AnchorStatus classifyAnchor({
  required List<int> fileHash,
  required int revision,
  required VaultRecord? record,
}) {
  if (record == null) return AnchorStatus.notAnchored;
  if (_sameBytes(fileHash, record.hash)) return AnchorStatus.verified;
  // version в цепочке = revision заверенного файла (ADR 0006)
  if (revision < record.version) return AnchorStatus.outdated;
  return AnchorStatus.unknown;
}

/// Проверка файла сейфа или бэкапа: SHA-256 всех байтов, `vaultId` и
/// `revision` из заголовка, `owner` — из payload после расшифровки
/// (ARCHITECTURE.md, «Поток проверки»).
///
/// Файл не в формате `.akv` → [FormatException] до обращения к сети:
/// это ошибка выбора файла, а не статус проверки.
Future<AnchorStatus> verifyVaultFile({
  required List<int> fileBytes,
  required Ed25519HDPublicKey owner,
  required FetchVaultRecord fetch,
}) async {
  final header = VaultFile.decode(fileBytes).header;
  final hash = (await Sha256().hash(fileBytes)).bytes;

  final VaultRecord? record;
  try {
    record = await fetch(owner, header.vaultId);
  } on FormatException {
    // По адресу записи лежит не VaultRecord — заверенной версии нет
    return AnchorStatus.unknown;
  } on Exception {
    // Сокет, таймаут, ошибка RPC: проверить сейчас нельзя
    return AnchorStatus.offline;
  }
  return classifyAnchor(
    fileHash: hash,
    revision: header.revision,
    record: record,
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
