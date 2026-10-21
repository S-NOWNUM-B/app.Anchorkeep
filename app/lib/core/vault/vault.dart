// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:cryptography/cryptography.dart';

/// Открытый сейф в памяти. Ключ живёт только здесь; при блокировке
/// сессию выбрасываем (MAIN-47).
class VaultSession {
  VaultSession(this.header, this.vaultKey, this.payload);

  VaultHeader header;
  final SecretKey vaultKey;
  final Map<String, Object?> payload;
}

/// Новый сейф: случайные vaultId, VK и соль. revision = 0 до первого save.
Future<VaultSession> createVault(String password, {KdfParams? kdf}) async {
  final params = kdf ?? KdfParams.defaults();
  final vaultId = randomBytes(16);
  final vaultKey = SecretKey(randomBytes(32));
  final kek = await deriveKek(password, params);
  final header = VaultHeader(
    vaultId: vaultId,
    revision: 0,
    kdf: params,
    wrappedKey: await wrapVaultKey(kek, vaultKey, vaultId),
  );
  return VaultSession(header, vaultKey, {
    'entries': <Object?>[],
    'settings': {'autoLockMinutes': 5},
  });
}

/// Пароль → KEK → VK → payload. Неверный пароль или подмена
/// заголовка → [VaultAuthException]; битый формат → [FormatException].
Future<VaultSession> unlockVault(List<int> bytes, String password) async {
  final file = VaultFile.decode(bytes);
  final h = file.header;
  final kek = await deriveKek(password, h.kdf);
  final vaultKey = await unwrapVaultKey(kek, h.wrappedKey, h.vaultId);
  final plain = await unseal(vaultKey, file.payload, h.aadBytes());
  final payload = jsonDecode(utf8.decode(plain));
  if (payload is! Map<String, Object?>) {
    throw const FormatException('vault: payload не объект');
  }
  return VaultSession(h, vaultKey, payload);
}

/// revision + 1 и полное перешифрование payload с новым nonce.
Future<Uint8List> saveVault(VaultSession session) async {
  session.header = session.header.withRevision(session.header.revision + 1);
  final payload = await seal(
    session.vaultKey,
    utf8.encode(jsonEncode(session.payload)),
    session.header.aadBytes(),
  );
  return VaultFile(session.header, payload).encode();
}
