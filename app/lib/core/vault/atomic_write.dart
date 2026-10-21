// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:anchorkeep/core/crypto/aead.dart';

/// Пишем рядом во временный файл, сбрасываем на диск и подменяем
/// одним rename: на диске всегда либо старая, либо новая версия целиком.
/// Имя временного файла уникально, чтобы параллельные записи не смешались;
/// при сбое он удаляется.
Future<void> writeFileAtomic(String path, List<int> bytes) async {
  final suffix = randomBytes(4).map((b) => b.toRadixString(16)).join();
  final tmp = File('$path.$suffix.tmp');
  try {
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(path);
  } catch (_) {
    if (tmp.existsSync()) await tmp.delete();
    rethrow;
  }
}
