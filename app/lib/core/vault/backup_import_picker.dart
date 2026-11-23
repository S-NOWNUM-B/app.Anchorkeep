// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:anchorkeep/core/security/auto_lock.dart';
import 'package:anchorkeep/core/vault/backup_import.dart';
import 'package:file_picker/file_picker.dart';

/// Системный диалог выбора бэкапа (Android и Windows). `null`, если
/// пользователь отменил. Размер проверяем до чтения файла в память.
/// Отдельно от `backup_import.dart`, чтобы логика не зависела от плагина.
class PickedBackup {
  const PickedBackup({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<PickedBackup?> pickBackupFile() async {
  final selected = await AutoLockPause.during(
    () => FilePicker.pickFile(dialogTitle: 'Выберите бэкап'),
  );
  final path = selected?.path;
  if (path == null) return null;
  final file = File(path);
  if (await file.length() > maxBackupBytes) {
    throw const FormatException('backup: файл слишком большой');
  }
  return PickedBackup(name: selected!.name, bytes: await file.readAsBytes());
}

Future<Uint8List?> pickBackupBytes() async => (await pickBackupFile())?.bytes;
