// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:anchorkeep/core/vault/vault_file.dart';

/// Куда сохранить бэкап: имя и байты → адрес сохранённого файла
/// или `null`, если пользователь отменил диалог.
typedef BackupSaver = Future<Uri?> Function(String fileName, Uint8List bytes);

/// `.akbackup` — побайтовая копия актуального `.akv`, без перешифровки:
/// SHA-256 заверяется в Solana по байтам файла, любая переупаковка
/// сломала бы проверку Verified. Файл остаётся зашифрованным мастер-паролем.
///
/// Перед сохранением проверяем, что это действительно сейф, чтобы не
/// выгрузить мусор под видом бэкапа (пароль для этого не нужен).
Future<Uri?> exportBackup(
  Uint8List akvBytes,
  BackupSaver save, {
  DateTime Function()? now,
}) async {
  final header = VaultFile.decode(akvBytes).header;
  return save(backupFileName(header, (now ?? DateTime.now)()), akvBytes);
}

/// Имя помогает отличить бэкапы: начало vaultId, revision и время.
/// Секретов в имени нет (vaultId и так публичен в блокчейне).
String backupFileName(VaultHeader header, DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  final id = header.vaultId
      .sublist(0, 4)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final date = '${at.year}${two(at.month)}${two(at.day)}';
  final time = '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  return 'anchorkeep-$id-r${header.revision}-$date-$time.akbackup';
}
