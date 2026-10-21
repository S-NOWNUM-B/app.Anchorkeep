import 'dart:io';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/backup_import.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const pw = 'пароль';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

/// Сейф с записью [title], сохранённый [saves] раз.
Future<(VaultSession, Uint8List)> vaultWith(String title, int saves) async {
  final s = await createVault(pw, kdf: fast());
  s.payload['entries'] = [
    {'title': title},
  ];
  late Uint8List bytes;
  for (var i = 0; i < saves; i++) {
    bytes = await saveVault(s);
  }
  return (s, bytes);
}

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('akimport');
    path = p.join(dir.path, 'vault.akv');
  });
  tearDown(() => dir.delete(recursive: true));

  test('импорт кладёт бэкап в файл сейфа байт в байт', () async {
    final (_, backup) = await vaultWith('с телефона', 3);
    await File(path).writeAsBytes((await vaultWith('старый', 1)).$2);

    final session = await importBackup(backup, pw, path);

    expect(await File(path).readAsBytes(), backup);
    expect(session.payload['entries'], [
      {'title': 'с телефона'},
    ]);
    expect(session.header.revision, 3);
  });

  test('импорт на новом устройстве, где файла сейфа ещё нет', () async {
    final (_, backup) = await vaultWith('данные', 2);
    expect(File(path).existsSync(), isFalse);
    await importBackup(backup, pw, path);
    expect(await File(path).readAsBytes(), backup);
  });

  test(
    'после импорта сейф сохраняется дальше, revision продолжается',
    () async {
      final (_, backup) = await vaultWith('данные', 3);
      final session = await importBackup(backup, pw, path);
      expect(VaultFile.decode(await saveVault(session)).header.revision, 4);
    },
  );

  group('текущий сейф не теряется при ошибке', () {
    late Uint8List current;

    setUp(() async {
      current = (await vaultWith('мои данные', 5)).$2;
      await File(path).writeAsBytes(current);
    });

    Future<void> expectUntouched() async {
      expect(await File(path).readAsBytes(), current);
      expect(dir.listSync().whereType<File>(), hasLength(1));
    }

    test('неверный пароль', () async {
      final (_, backup) = await vaultWith('бэкап', 2);
      await expectLater(
        importBackup(backup, 'не тот', path),
        throwsA(isA<VaultAuthException>()),
      );
      await expectUntouched();
    });

    test('файл не сейф', () async {
      await expectLater(
        importBackup(Uint8List.fromList([1, 2, 3]), pw, path),
        throwsFormatException,
      );
      await expectUntouched();
    });

    test('бэкап подделан (revision изменён)', () async {
      final (_, backup) = await vaultWith('бэкап', 2);
      final f = VaultFile.decode(backup);
      final forged = VaultFile(f.header.withRevision(99), f.payload).encode();
      await expectLater(
        importBackup(forged, pw, path),
        throwsA(isA<VaultAuthException>()),
      );
      await expectUntouched();
    });

    test('не удалось записать файл', () async {
      final (_, backup) = await vaultWith('бэкап', 2);
      final blocked = p.join(dir.path, 'каталог');
      await Directory(blocked).create();
      await expectLater(importBackup(backup, pw, blocked), throwsA(anything));
      await expectUntouched();
    });
  });

  group('previewBackup', () {
    test('читает заголовок без пароля', () async {
      final (s, backup) = await vaultWith('данные', 4);
      final h = previewBackup(backup);
      expect(h.vaultId, s.header.vaultId);
      expect(h.revision, 4);
    });

    test('слишком большой файл → FormatException', () {
      expect(
        () => previewBackup(Uint8List(maxBackupBytes + 1)),
        throwsFormatException,
      );
    });
  });

  group('classifyImport', () {
    test('все случаи', () async {
      final a = (await vaultWith('a', 3)).$2;
      final aSession = await unlockVault(a, pw);
      final aNewer = await saveVault(aSession); // revision 4
      final other = (await vaultWith('b', 3)).$2;

      VaultHeader h(Uint8List b) => VaultFile.decode(b).header;

      expect(classifyImport(h(a), null), ImportKind.newVault);
      expect(classifyImport(h(aNewer), h(a)), ImportKind.sameVaultNewer);
      expect(classifyImport(h(a), h(aNewer)), ImportKind.sameVaultOlder);
      expect(classifyImport(h(a), h(a)), ImportKind.sameVaultSame);
      expect(classifyImport(h(other), h(a)), ImportKind.differentVault);
    });
  });
}
