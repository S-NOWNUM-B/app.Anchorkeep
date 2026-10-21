import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:flutter_test/flutter_test.dart';

KdfParams fastParams() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

void main() {
  test('один пароль и соль → один KEK', () async {
    final p = fastParams();
    final a = await (await deriveKek('пароль', p)).extractBytes();
    final b = await (await deriveKek('пароль', p)).extractBytes();
    expect(a, b);
    expect(a.length, 32);
  });

  test('другой пароль или соль → другой KEK', () async {
    final p = fastParams();
    final base = await (await deriveKek('пароль', p)).extractBytes();
    final otherPw = await (await deriveKek('пароль!', p)).extractBytes();
    final otherSalt = await (await deriveKek(
      'пароль',
      fastParams(),
    )).extractBytes();
    expect(otherPw, isNot(base));
    expect(otherSalt, isNot(base));
  });

  test('defaults: 64 MiB, 3 итерации, 1 поток, соль 16 байт', () {
    final d = KdfParams.defaults();
    expect([d.memoryKiB, d.iterations, d.parallelism], [65536, 3, 1]);
    expect(d.salt.length, 16);
  });
}
