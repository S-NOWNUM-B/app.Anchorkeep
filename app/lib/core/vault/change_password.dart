// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:cryptography/cryptography.dart';

/// Смена мастер-пароля (ADR 0007). Проверяет [current], затем делает НОВЫЙ
/// ключ сейфа, новую соль и новый KEK, перешифровывает payload и отдаёт
/// байты в [write]. Сессия обновляется только после успешной записи, при
/// любой ошибке остаётся как была (и со старым паролем).
///
/// Ключ сейфа меняется намеренно: иначе тот, кто знает старый пароль и имеет
/// любую старую копию файла, получил бы из неё прежний ключ и читал бы все
/// новые файлы, а пароль меняют именно тогда, когда он скомпрометирован.
/// Старые бэкапы при этом остаются открываемы старым паролем.
///
/// Файл меняется (revision + 1), поэтому его нужно заново заверить в Solana.
/// Требовать [current] даже при открытом сейфе нужно, чтобы с разблокированного
/// телефона нельзя было сменить пароль.
Future<void> changeMasterPassword(
  VaultSession session,
  String current,
  String next,
  WriteVault write,
) async {
  if (next.isEmpty) throw ArgumentError.value(next, 'next', 'пустой пароль');

  final old = session.header;
  final oldKek = await deriveKek(current, old.kdf);
  try {
    // Неверный пароль → VaultAuthException; найденный ключ нам не нужен.
    (await unwrapVaultKey(oldKek, old.wrappedKey, old.vaultId)).destroy();
  } finally {
    oldKek.destroy();
  }

  // Стоимость KDF прежняя (подобрана бенчмарком), соль новая.
  final kdf = KdfParams(
    memoryKiB: old.kdf.memoryKiB,
    iterations: old.kdf.iterations,
    parallelism: old.kdf.parallelism,
    salt: randomBytes(16),
  );
  final newKey = SecretKey(randomBytes(32));
  final newKek = await deriveKek(next, kdf);
  final VaultHeader header;
  try {
    header = VaultHeader(
      vaultId: old.vaultId,
      revision: old.revision + 1,
      kdf: kdf,
      wrappedKey: await wrapVaultKey(newKek, newKey, old.vaultId),
    );
  } finally {
    newKek.destroy();
  }

  try {
    await write(await sealVaultFile(header, newKey, session.payload));
  } catch (_) {
    newKey.destroy();
    rethrow;
  }
  session.vaultKey.destroy();
  session.vaultKey = newKey;
  session.header = header;
}
