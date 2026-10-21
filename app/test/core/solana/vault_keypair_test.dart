// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/solana/vault_keypair.dart';
import 'package:anchorkeep/core/vault/change_password.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

const pw = 'пароль';

KdfParams fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

Future<VaultSession> newVault() => createVault(pw, kdf: fast());

Uint8List secretOf(VaultSession s) => base64.decode(
  (s.payload['solana']! as Map<String, Object?>)['secretKey']! as String,
);

/// Есть ли [needle] подряд внутри [haystack].
bool containsBytes(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

void main() {
  test('createVault кладёт ключ в payload, сейф ещё не заверен', () async {
    final s = await newVault();

    expect(secretOf(s), hasLength(64));
    expect(lastAnchoredRevision(s.payload), isNull);
  });

  test('у разных сейфов разные ключи', () async {
    final a = await newVault();
    final b = await newVault();
    expect(solanaOwner(a.payload), isNot(solanaOwner(b.payload)));
  });

  test('keypair подписывает, owner совпадает с его публичным ключом', () async {
    final s = await newVault();
    final keypair = await solanaKeypair(s.payload);
    expect(keypair.publicKey, solanaOwner(s.payload));

    final data = utf8.encode('commit_version');
    final signature = await keypair.sign(data);
    // cryptography проверяет подпись только с SimplePublicKey
    final check = Signature(
      signature.bytes,
      publicKey: SimplePublicKey(
        keypair.publicKey.bytes,
        type: KeyPairType.ed25519,
      ),
    );
    expect(await Ed25519().verify(data, signature: check), isTrue);
  });

  test('ключа нет в байтах файла сейфа (ни сырого, ни base64)', () async {
    final s = await newVault();
    final secret = secretOf(s);
    final encoded = utf8.encode(base64.encode(secret));
    final file = await saveVault(s);

    expect(containsBytes(file, secret.sublist(0, 32)), isFalse);
    expect(containsBytes(file, encoded.sublist(0, 43)), isFalse);
  });

  test('ключ переживает сохранение, разблокировку и смену пароля', () async {
    final s = await newVault();
    final owner = solanaOwner(s.payload);

    final reopened = await unlockVault(await saveVault(s), pw);
    expect(solanaOwner(reopened.payload), owner);

    late Uint8List changed;
    await changeMasterPassword(s, pw, 'новый', (b) async => changed = b);
    final afterChange = await unlockVault(changed, 'новый');
    expect(solanaOwner(afterChange.payload), owner);
  });

  test('markAnchored меняет только отметку в памяти', () async {
    final s = await newVault();
    final revision = s.header.revision;
    markAnchored(s.payload, 7);

    expect(lastAnchoredRevision(s.payload), 7);
    expect(s.header.revision, revision);
  });

  group('сейф без секции solana (создан до AK-31)', () {
    test('ensureSolanaSection добавляет ключ', () async {
      final payload = <String, Object?>{'entries': <Object?>[]};
      expect(await ensureSolanaSection(payload), isTrue);
      expect(lastAnchoredRevision(payload), isNull);
      expect(() => solanaOwner(payload), returnsNormally);
    });

    test('существующий ключ ensureSolanaSection не трогает', () async {
      final s = await newVault();
      final owner = solanaOwner(s.payload);
      expect(await ensureSolanaSection(s.payload), isFalse);
      expect(solanaOwner(s.payload), owner);
    });

    test('без секции чтение ключа → FormatException', () {
      expect(() => solanaOwner(<String, Object?>{}), throwsFormatException);
    });
  });

  group('испорченный ключ → FormatException', () {
    Map<String, Object?> withSecret(Object? secret) => {
      'solana': {'secretKey': secret, 'lastAnchoredRevision': null},
    };

    test('не base64', () {
      expect(() => solanaOwner(withSecret('%%%')), throwsFormatException);
    });

    test('не 64 байта', () {
      final short = base64.encode(List.filled(63, 1));
      expect(() => solanaOwner(withSecret(short)), throwsFormatException);
    });

    test('публичная часть не от этого seed', () async {
      final s = await newVault();
      final secret = secretOf(s)..[40] ^= 0xff;
      expect(
        () => solanaKeypair(withSecret(base64.encode(secret))),
        throwsFormatException,
      );
    });

    test('lastAnchoredRevision не число', () {
      final payload = {
        'solana': {'secretKey': '', 'lastAnchoredRevision': 'сорок'},
      };
      expect(() => lastAnchoredRevision(payload), throwsFormatException);
    });
  });
}
