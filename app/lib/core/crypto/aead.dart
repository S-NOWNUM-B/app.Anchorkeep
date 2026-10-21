// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Ошибка расшифровки. Намеренно без деталей: неверный пароль
/// и подмена файла снаружи неотличимы (F2).
class VaultAuthException implements Exception {
  const VaultAuthException();

  @override
  String toString() => 'VaultAuthException';
}

/// Результат AES-GCM: nonce и шифротекст с 16-байтным тегом в конце.
class Sealed {
  const Sealed(this.nonce, this.ciphertext);

  final Uint8List nonce;
  final Uint8List ciphertext;
}

const _nonceLength = 12;
const _tagLength = 16;
final _aes = AesGcm.with256bits();
final _rng = Random.secure();

/// Криптостойкие случайные байты.
Uint8List randomBytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

/// Шифрует [plaintext]. Nonce каждый раз новый — его генерирует библиотека.
Future<Sealed> seal(SecretKey key, List<int> plaintext, List<int> aad) async {
  final box = await _aes.encrypt(plaintext, secretKey: key, aad: aad);
  return Sealed(Uint8List.fromList(box.nonce), box.concatenation(nonce: false));
}

/// Расшифровывает и проверяет тег (вместе с [aad]).
Future<Uint8List> unseal(SecretKey key, Sealed sealed, List<int> aad) async {
  final ct = sealed.ciphertext;
  if (sealed.nonce.length != _nonceLength || ct.length < _tagLength) {
    throw const VaultAuthException();
  }
  final box = SecretBox(
    ct.sublist(0, ct.length - _tagLength),
    nonce: sealed.nonce,
    mac: Mac(ct.sublist(ct.length - _tagLength)),
  );
  try {
    return Uint8List.fromList(
      await _aes.decrypt(box, secretKey: key, aad: aad),
    );
  } on SecretBoxAuthenticationError {
    throw const VaultAuthException();
  }
}

/// Шифрует ключ сейфа ключом из пароля. AAD = vaultId (ADR 0005):
/// обёртку нельзя перенести в другой сейф.
Future<Sealed> wrapVaultKey(
  SecretKey kek,
  SecretKey vaultKey,
  List<int> vaultId,
) async => seal(kek, await vaultKey.extractBytes(), vaultId);

Future<SecretKey> unwrapVaultKey(
  SecretKey kek,
  Sealed wrapped,
  List<int> vaultId,
) async {
  final bytes = await unseal(kek, wrapped, vaultId);
  if (bytes.length != 32) throw const VaultAuthException();
  return SecretKey(bytes);
}
