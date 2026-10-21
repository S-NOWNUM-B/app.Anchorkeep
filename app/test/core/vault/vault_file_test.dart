import 'dart:convert';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:flutter_test/flutter_test.dart';

VaultFile sample() => VaultFile(
  VaultHeader(
    vaultId: randomBytes(16),
    revision: 7,
    kdf: KdfParams.defaults(),
    wrappedKey: Sealed(randomBytes(12), randomBytes(48)),
  ),
  Sealed(randomBytes(12), randomBytes(40)),
);

Map<String, Object?> asJson(VaultFile f) =>
    jsonDecode(utf8.decode(f.encode())) as Map<String, Object?>;

List<int> fromJson(Map<String, Object?> j) => utf8.encode(jsonEncode(j));

void main() {
  test('encode → decode сохраняет все поля', () {
    final f = sample();
    final back = VaultFile.decode(f.encode());
    expect(back.header.vaultId, f.header.vaultId);
    expect(back.header.revision, 7);
    expect(back.header.kdf.salt, f.header.kdf.salt);
    expect(back.header.wrappedKey.ciphertext, f.header.wrappedKey.ciphertext);
    expect(back.payload.ciphertext, f.payload.ciphertext);
    expect(back.header.aadBytes(), f.header.aadBytes());
  });

  test('AAD не содержит payload и зависит от revision', () {
    final h = sample().header;
    expect(utf8.decode(h.aadBytes()), isNot(contains('payload')));
    expect(h.withRevision(8).aadBytes(), isNot(h.aadBytes()));
  });

  test('AAD не зависит от порядка ключей во входном файле', () {
    final f = sample();
    final reordered = Map.fromEntries(asJson(f).entries.toList().reversed);
    expect(
      VaultFile.decode(fromJson(reordered)).header.aadBytes(),
      f.header.aadBytes(),
    );
  });

  test('отклоняет не-JSON и обрезанный файл', () {
    expect(() => VaultFile.decode(utf8.encode('hello')), throwsFormatException);
    final bytes = sample().encode();
    expect(
      () => VaultFile.decode(bytes.sublist(0, bytes.length ~/ 2)),
      throwsFormatException,
    );
  });

  void rejects(String why, void Function(Map<String, Object?> j) mutate) {
    test('отклоняет: $why', () {
      final j = asJson(sample());
      mutate(j);
      expect(() => VaultFile.decode(fromJson(j)), throwsFormatException);
    });
  }

  Map<String, Object?> sub(Map<String, Object?> j, String key) =>
      j[key]! as Map<String, Object?>;

  rejects('чужой magic', (j) => j['magic'] = 'XYZ');
  rejects('formatVersion 2', (j) => j['formatVersion'] = 2);
  rejects('лишнее поле', (j) => j['extra'] = 1);
  rejects('нет payload', (j) => j.remove('payload'));
  rejects('отрицательная revision', (j) => j['revision'] = -1);
  rejects(
    'vaultId 15 байт',
    (j) => j['vaultId'] = base64.encode(randomBytes(15)),
  );
  rejects(
    'nonce 11 байт',
    (j) => sub(j, 'payload')['nonce'] = base64.encode(randomBytes(11)),
  );
  rejects(
    'memoryKiB 4 GiB (DoS)',
    (j) => sub(j, 'kdf')['memoryKiB'] = 4 * 1024 * 1024,
  );
  rejects('неизвестный alg', (j) => sub(j, 'kdf')['alg'] = 'scrypt');
  rejects('битый base64', (j) => j['vaultId'] = '!!!');
}
