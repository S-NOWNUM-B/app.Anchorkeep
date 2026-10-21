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
    expect(dir.listSync().whereType<File>().length, 1);
  });

  test('недописанный .tmp после сбоя не портит сейф', () async {
    await writeFileAtomic(path, [1, 2, 3]);
    await File('$path.deadbeef.tmp')
        .writeAsBytes([9]); // имитация обрыва записи
    expect(await File(path).readAsBytes(), [1, 2, 3]);
    await writeFileAtomic(path, [7]);
    expect(await File(path).readAsBytes(), [7]);
  });

  test('параллельные записи не смешиваются', () async {
    final payloads = [
      for (var i = 1; i <= 20; i++) List<int>.filled(i * 1000, i),
    ];
    await Future.wait(payloads.map((b) => writeFileAtomic(path, b)));
    final result = await File(path).readAsBytes();
    expect(payloads.any((b) => b.length == result.length), isTrue);
    expect(result.every((x) => x == result.first), isTrue);
  });

  test('при сбое rename временный файл удаляется', () async {
    await Directory(path).create(); // rename файла поверх каталога упадёт
    await expectLater(writeFileAtomic(path, [1]), throwsA(anything));
    expect(dir.listSync().whereType<File>(), isEmpty);
  });
}
