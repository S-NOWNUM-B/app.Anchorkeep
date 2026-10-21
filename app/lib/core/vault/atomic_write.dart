// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

/// Пишем рядом во временный файл, сбрасываем на диск и подменяем
/// одним rename: на диске всегда либо старая, либо новая версия целиком.
Future<void> writeFileAtomic(String path, List<int> bytes) async {
  final tmp = File('$path.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(path);
}
