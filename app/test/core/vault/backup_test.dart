import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/backup.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:flutter_test/flutter_test.dart';

const pw = 'пароль';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

/// Сейф с одной записью, сохранённый 3 раза (revision = 3).
Future<Uint8List> savedVault() async {
  final s = await createVault(pw, kdf: fast());
  s.payload['entries'] = [
    {'title': 'почта'},
  ];
  await saveVault(s);
  await saveVault(s);
  return saveVault(s);
}

final fixedNow = DateTime(2026, 10, 21, 9, 5, 7);

void main() {
  test(
    'имя: префикс vaultId, revision и время, расширение .akbackup',
    () async {
      final bytes = await savedVault();
      final h = VaultFile.decode(bytes).header;
      final prefix = h.vaultId
          .sublist(0, 4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        backupFileName(h, fixedNow),
        'anchorkeep-$prefix-r3-20261021-090507.akbackup',
      );
    },
  );

  test('exportBackup отдаёт те же байты и возвращает Uri от saver', () async {
    final bytes = await savedVault();
    String? name;
    Uint8List? got;
    final uri = await exportBackup(bytes, (n, b) async {
      name = n;
      got = b;
      return Uri.file('/tmp/$n');
    }, now: () => fixedNow);
    expect(got, bytes);
    expect(name, endsWith('-r3-20261021-090507.akbackup'));
    expect(uri, Uri.file('/tmp/$name'));
  });

  test('бэкап открывается тем же паролем и содержит те же данные', () async {
    final bytes = await savedVault();
    Uint8List? got;
    await exportBackup(bytes, (n, b) async {
      got = b;
      return Uri.file('/tmp/$n');
    });
    final back = await unlockVault(got!, pw);
    expect(back.payload['entries'], [
      {'title': 'почта'},
    ]);
    expect(back.header.revision, 3);
  });

  test('пользователь отменил диалог → null', () async {
    expect(
      await exportBackup(await savedVault(), (n, b) async => null),
      isNull,
    );
  });

  test('не сейф → FormatException, saver не вызывается', () async {
    var called = false;
    await expectLater(
      exportBackup(Uint8List.fromList([1, 2, 3]), (n, b) async {
        called = true;
        return null;
      }),
      throwsFormatException,
    );
    expect(called, isFalse);
  });

  test('ошибка saver пробрасывается', () async {
    await expectLater(
      exportBackup(
        await savedVault(),
        (n, b) async => throw StateError('диск'),
      ),
      throwsStateError,
    );
  });
}
