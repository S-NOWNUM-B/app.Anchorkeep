import 'dart:convert';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:flutter_test/flutter_test.dart';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

const pw = 'пароль-🔑-Ünï';

Future<VaultFile> savedFile() async =>
    VaultFile.decode(await saveVault(await createVault(pw, kdf: fast())));

void main() {
  test('create → save → unlock возвращает payload', () async {
    final s = await createVault(pw, kdf: fast());
    s.payload['entries'] = [
      {'title': 'почта'},
    ];
    final back = await unlockVault(await saveVault(s), pw);
    expect(back.payload['entries'], [
      {'title': 'почта'},
    ]);
    expect(back.header.vaultId, s.header.vaultId);
  });

  test('новый сейф пустой, каждое сохранение +1 к revision', () async {
    final s = await createVault(pw, kdf: fast());
    expect(s.header.revision, 0);
    expect(s.payload['entries'], isEmpty);
    await saveVault(s);
    expect(VaultFile.decode(await saveVault(s)).header.revision, 2);
  });

  test('неверный пароль → VaultAuthException', () async {
    final bytes = (await savedFile()).encode();
    expect(
      () => unlockVault(bytes, 'не тот'),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('подмена revision в файле → VaultAuthException', () async {
    final f = await savedFile();
    final forged = VaultFile(f.header.withRevision(99), f.payload);
    expect(
      () => unlockVault(forged.encode(), pw),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('обёртка ключа из другого сейфа → VaultAuthException', () async {
    final a = await savedFile();
    final b = await savedFile();
    final mixed = VaultFile(
      VaultHeader(
        vaultId: a.header.vaultId,
        revision: a.header.revision,
        kdf: b.header.kdf,
        wrappedKey: b.header.wrappedKey,
      ),
      a.payload,
    );
    expect(
      () => unlockVault(mixed.encode(), pw),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('payload не утекает в файл открытым текстом', () async {
    final s = await createVault(pw, kdf: fast());
    s.payload['entries'] = [
      {'password': 'hunter2'},
    ];
    expect(utf8.decode(await saveVault(s)), isNot(contains('hunter2')));
  });

  test('close стирает payload и уничтожает ключ сейфа', () async {
    final s = await createVault(pw, kdf: fast());
    s.payload['entries'] = [
      {'title': 'почта'},
    ];
    s.close();
    expect(s.payload, isEmpty);
    expect(() => s.vaultKey.extractBytes(), throwsStateError);
    s.close(); // повторный вызов безопасен
  });
}
