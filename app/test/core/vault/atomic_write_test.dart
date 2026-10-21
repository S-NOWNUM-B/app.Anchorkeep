import 'dart:io';

import 'package:anchorkeep/core/vault/atomic_write.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('akv');
    path = p.join(dir.path, 'vault.akv');
  });
  tearDown(() => dir.delete(recursive: true));

  test('создаёт файл и заменяет существующий', () async {
    await writeFileAtomic(path, [1, 2, 3]);
    await writeFileAtomic(path, [4, 5]);
    expect(await File(path).readAsBytes(), [4, 5]);
    expect(File('$path.tmp').existsSync(), isFalse);
  });

  test('недописанный .tmp после сбоя не портит сейф', () async {
    await writeFileAtomic(path, [1, 2, 3]);
    await File('$path.tmp').writeAsBytes([9]); // имитация обрыва записи
    expect(await File(path).readAsBytes(), [1, 2, 3]);
    await writeFileAtomic(path, [7]);
    expect(await File(path).readAsBytes(), [7]);
  });
}
