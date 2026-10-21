// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// [BackupSaver] для приложения: системный диалог «Сохранить как»
/// (Android и Windows). Отдельно от `backup.dart`, чтобы логика
/// бэкапа не зависела от платформенного плагина и тестировалась без него.
Future<Uri?> saveBackupWithPicker(String fileName, Uint8List bytes) =>
    FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: 'Сохранить бэкап',
    );
