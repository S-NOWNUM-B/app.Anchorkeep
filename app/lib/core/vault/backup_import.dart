// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:anchorkeep/core/vault/atomic_write.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';

/// Бэкап больше этого размера не открываем: паролей в сейфе мегабайты,
/// а не сотни, зато чужой файл не должен съесть память.
const maxBackupBytes = 64 * 1024 * 1024;

/// Как бэкап соотносится с текущим сейфом на устройстве. UI по этому
/// показывает предупреждение до перезаписи.
enum ImportKind {
  /// Сейфа на устройстве нет (новое устройство).
  newVault,

  /// Тот же сейф, бэкап новее текущего.
  sameVaultNewer,

  /// Тот же сейф, бэкап СТАРЕЕ текущего: свежие записи пропадут.
  sameVaultOlder,

  /// Тот же сейф и та же версия.
  sameVaultSame,

  /// Другой сейф: текущий будет заменён целиком.
  differentVault,
}

/// Заголовок бэкапа без пароля: чтобы показать, что за файл, и проверить
/// формат до ввода пароля. Битый или слишком большой файл → [FormatException].
VaultHeader previewBackup(Uint8List bytes) {
  if (bytes.length > maxBackupBytes) {
    throw const FormatException('backup: файл слишком большой');
  }
  return VaultFile.decode(bytes).header;
}

ImportKind classifyImport(VaultHeader backup, VaultHeader? current) {
  if (current == null) return ImportKind.newVault;
  if (!_sameBytes(backup.vaultId, current.vaultId)) {
    return ImportKind.differentVault;
  }
  if (backup.revision > current.revision) return ImportKind.sameVaultNewer;
  if (backup.revision < current.revision) return ImportKind.sameVaultOlder;
  return ImportKind.sameVaultSame;
}

/// Сначала проверяем бэкап (формат, пароль, целостность), и только потом
/// атомарно заменяем файл сейфа. Любая ошибка до записи оставляет текущий
/// сейф нетронутым.
///
/// Байты пишутся как есть, без повторного сохранения: `saveVault` поднял бы
/// revision и изменил файл, а хеш для проверки в Solana считается по байтам.
Future<VaultSession> importBackup(
  Uint8List bytes,
  String password,
  String vaultPath,
) async {
  previewBackup(bytes);
  final session = await unlockVault(bytes, password);
  await writeFileAtomic(vaultPath, bytes);
  return session;
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
