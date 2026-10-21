import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/change_password.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/core/vault/entry_repository.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:flutter_test/flutter_test.dart';

const oldPw = 'старый-пароль';
const newPw = 'новый-пароль-🔑';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

/// Открытый сейф с записью, сохранённый дважды (revision = 2).
Future<(VaultSession, Uint8List)> openVault() async {
  final s = await createVault(oldPw, kdf: fast());
  s.payload['entries'] = [
    {'title': 'почта'},
  ];
  await saveVault(s);
  final bytes = await saveVault(s);
  return (s, bytes);
}

void main() {
  test('новый пароль открывает файл, старый — нет, данные те же', () async {
    final (s, _) = await openVault();
    late Uint8List written;
    await changeMasterPassword(s, oldPw, newPw, (b) async => written = b);

    final back = await unlockVault(written, newPw);
    expect(back.payload['entries'], [
      {'title': 'почта'},
    ]);
    await expectLater(
      unlockVault(written, oldPw),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test(
    'соль новая, параметры стоимости и vaultId прежние, revision +1',
    () async {
      final (s, _) = await openVault();
      final before = s.header;
      late Uint8List written;
      await changeMasterPassword(s, oldPw, newPw, (b) async => written = b);

      final h = VaultFile.decode(written).header;
      expect(h.kdf.salt, isNot(before.kdf.salt));
      expect(h.kdf.memoryKiB, before.kdf.memoryKiB);
      expect(h.kdf.iterations, before.kdf.iterations);
      expect(h.vaultId, before.vaultId);
      expect(h.revision, before.revision + 1);
      expect(s.header.revision, h.revision, reason: 'сессия обновлена');
    },
  );

  test(
    'ключ сейфа заменён: знание старого пароля не открывает новый файл',
    () async {
      final (s, oldFile) = await openVault();
      // Злоумышленник знает старый пароль и имеет старую копию файла.
      final old = VaultFile.decode(oldFile);
      final oldKek = await deriveKek(oldPw, old.header.kdf);
      final oldVk = await unwrapVaultKey(
        oldKek,
        old.header.wrappedKey,
        old.header.vaultId,
      );

      late Uint8List written;
      await changeMasterPassword(s, oldPw, newPw, (b) async => written = b);

      final fresh = VaultFile.decode(written);
      await expectLater(
        unseal(oldVk, fresh.payload, fresh.header.aadBytes()),
        throwsA(isA<VaultAuthException>()),
      );
    },
  );

  test('старый ключ сейфа в памяти уничтожен', () async {
    final (s, _) = await openVault();
    final oldKey = s.vaultKey;
    await changeMasterPassword(s, oldPw, newPw, (b) async {});
    expect(() => oldKey.extractBytes(), throwsStateError);
    expect(s.vaultKey, isNot(same(oldKey)));
  });

  group('при ошибке сессия и файл не меняются', () {
    test('неверный текущий пароль', () async {
      final (s, _) = await openVault();
      final header = s.header;
      final key = s.vaultKey;
      var writes = 0;
      await expectLater(
        changeMasterPassword(s, 'не тот', newPw, (b) async => writes++),
        throwsA(isA<VaultAuthException>()),
      );
      expect(writes, 0);
      expect(s.header, same(header));
      expect(s.vaultKey, same(key));
    });

    test('сбой записи на диск', () async {
      final (s, _) = await openVault();
      final header = s.header;
      final key = s.vaultKey;
      await expectLater(
        changeMasterPassword(
          s,
          oldPw,
          newPw,
          (b) async => throw StateError('диск'),
        ),
        throwsStateError,
      );
      expect(s.header, same(header));
      expect(s.vaultKey, same(key));
      // сессия по-прежнему работает со старым паролем
      expect(
        (await unlockVault(await saveVault(s), oldPw)).payload['entries'],
        isNotEmpty,
      );
    });

    test('пустой новый пароль', () async {
      final (s, _) = await openVault();
      var writes = 0;
      expect(
        () => changeMasterPassword(s, oldPw, '', (b) async => writes++),
        throwsArgumentError,
      );
      expect(writes, 0);
    });
  });

  test('репозиторий записей продолжает работать после смены пароля', () async {
    final s = await createVault(oldPw, kdf: fast());
    final files = <Uint8List>[];
    final repo = EntryRepository(s, (b) async => files.add(b));
    await repo.add(EntryType.note, 'до смены', {'text': 'x'});
    await changeMasterPassword(s, oldPw, newPw, (b) async => files.add(b));
    await repo.add(EntryType.note, 'после смены', {'text': 'y'});

    final back = await unlockVault(files.last, newPw);
    final titles = EntryRepository(
      back,
      (_) async {},
    ).list().map((e) => e.title);
    expect(titles, ['до смены', 'после смены']);
    expect(VaultFile.decode(files.last).header.revision, 3);
  });
}
