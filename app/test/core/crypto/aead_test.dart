import 'dart:convert';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = SecretKey(randomBytes(32));
  final aad = utf8.encode('header');
  final data = utf8.encode('секрет');

  test('seal → unseal возвращает исходные данные', () async {
    final s = await seal(key, data, aad);
    expect(s.nonce.length, 12);
    expect(await unseal(key, s, aad), data);
  });

  test('каждое шифрование — новый nonce', () async {
    final a = await seal(key, data, aad);
    final b = await seal(key, data, aad);
    expect(a.nonce, isNot(b.nonce));
    expect(a.ciphertext, isNot(b.ciphertext));
  });

  test('чужой ключ → VaultAuthException', () async {
    final s = await seal(key, data, aad);
    expect(
      () => unseal(SecretKey(randomBytes(32)), s, aad),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('подмена ciphertext → VaultAuthException', () async {
    final s = await seal(key, data, aad);
    s.ciphertext[0] ^= 1;
    expect(() => unseal(key, s, aad), throwsA(isA<VaultAuthException>()));
  });

  test('подмена AAD → VaultAuthException', () async {
    final s = await seal(key, data, aad);
    expect(
      () => unseal(key, s, utf8.encode('other')),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('обрезанный ciphertext → VaultAuthException', () async {
    final s = await seal(key, data, aad);
    final short = Sealed(s.nonce, s.ciphertext.sublist(0, 10));
    expect(() => unseal(key, short, aad), throwsA(isA<VaultAuthException>()));
  });

  test('wrap/unwrap ключа сейфа', () async {
    final kek = SecretKey(randomBytes(32));
    final vk = SecretKey(randomBytes(32));
    final id = randomBytes(16);
    final w = await wrapVaultKey(kek, vk, id);
    final back = await unwrapVaultKey(kek, w, id);
    expect(await back.extractBytes(), await vk.extractBytes());
    expect(
      () => unwrapVaultKey(kek, w, randomBytes(16)),
      throwsA(isA<VaultAuthException>()),
    );
  });
}
