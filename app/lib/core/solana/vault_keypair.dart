// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:solana/solana.dart';

// Devnet-ключ сейфа живёт только в зашифрованном payload (ARCHITECTURE.md,
// «Формат файла»): `solana.secretKey` — 64 байта seed ‖ публичный ключ в
// base64 (как кошелёк solana CLI), `solana.lastAnchoredRevision` — revision
// последнего заверенного файла или `null`, если сейф ещё не заверяли.

const _section = 'solana';
const _secretKey = 'secretKey';
const _lastAnchored = 'lastAnchoredRevision';

/// Новая секция `solana` для payload: случайный ключ, сейф ещё не заверен.
Future<Map<String, Object?>> newSolanaSection() async {
  final seed = randomBytes(32);
  final secret = Uint8List(64);
  try {
    final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: seed,
    );
    secret
      ..setAll(0, seed)
      ..setAll(32, keypair.publicKey.bytes);
    return {_secretKey: base64.encode(secret), _lastAnchored: null};
  } finally {
    // keypair дальше не используется, поэтому seed можно затереть (ADR 0003)
    seed.fillRange(0, seed.length, 0);
    secret.fillRange(0, secret.length, 0);
  }
}

/// Сейф, созданный до AK-31, без секции `solana`: добавляет ключ.
/// `true` — секция добавлена, сейф нужно сохранить.
Future<bool> ensureSolanaSection(Map<String, Object?> payload) async {
  if (payload.containsKey(_section)) return false;
  payload[_section] = await newSolanaSection();
  return true;
}

/// Публичный ключ сейфа — `owner` в `vault_registry`. Секрет не разбирается.
Ed25519HDPublicKey solanaOwner(Map<String, Object?> payload) {
  final secret = _secretBytes(payload);
  try {
    return Ed25519HDPublicKey(secret.sublist(32));
  } finally {
    secret.fillRange(0, secret.length, 0);
  }
}

/// Ключ для подписи заверения. Держать только на время операции: keypair
/// хранит ссылку на seed без копии (ADR 0003). Испорченный ключ (публичная
/// часть не совпадает с seed) → [FormatException].
Future<Ed25519HDKeyPair> solanaKeypair(Map<String, Object?> payload) async {
  final secret = _secretBytes(payload);
  try {
    final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: Uint8List.fromList(secret.sublist(0, 32)),
    );
    final stored = secret.sublist(32);
    final derived = keypair.publicKey.bytes;
    for (var i = 0; i < 32; i++) {
      if (stored[i] != derived[i]) {
        throw const FormatException('solana: ключ повреждён');
      }
    }
    return keypair;
  } finally {
    secret.fillRange(0, secret.length, 0);
  }
}

/// Revision последнего заверенного файла; `null` — сейф не заверяли.
int? lastAnchoredRevision(Map<String, Object?> payload) {
  final value = _sectionOf(payload)[_lastAnchored];
  if (value == null || value is int) return value as int?;
  throw const FormatException('solana: lastAnchoredRevision не число');
}

/// Отметить успешное заверение файла с этой [revision] — только в памяти.
/// Сохранять сейф ради отметки нельзя: сохранение даст revision + 1, и
/// бэкап сразу после заверения проверялся бы как Unknown. Отметка попадёт на
/// диск со следующим обычным сохранением; это подсказка для офлайна, а
/// фактический статус подтверждает цепочка (`verifyVaultFile`).
void markAnchored(Map<String, Object?> payload, int revision) {
  _sectionOf(payload)[_lastAnchored] = revision;
}

Map<String, Object?> _sectionOf(Map<String, Object?> payload) {
  final section = payload[_section];
  if (section is! Map<String, Object?>) {
    throw const FormatException('solana: нет секции в payload');
  }
  return section;
}

Uint8List _secretBytes(Map<String, Object?> payload) {
  final encoded = _sectionOf(payload)[_secretKey];
  if (encoded is! String) {
    throw const FormatException('solana: нет secretKey');
  }
  final Uint8List bytes;
  try {
    bytes = base64.decode(encoded);
  } on FormatException {
    throw const FormatException('solana: secretKey не base64');
  }
  if (bytes.length != 64) {
    bytes.fillRange(0, bytes.length, 0);
    throw const FormatException('solana: secretKey не 64 байта');
  }
  return bytes;
}
