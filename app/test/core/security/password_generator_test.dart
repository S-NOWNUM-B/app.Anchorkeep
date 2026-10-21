import 'dart:math';

import 'package:anchorkeep/core/security/password_generator.dart';
import 'package:flutter_test/flutter_test.dart';

bool has(String s, String set) => s.split('').any(set.contains);

void main() {
  test('длина настраивается', () {
    for (final n in [4, 12, 20, 128]) {
      expect(generatePassword(PasswordOptions(length: n)), hasLength(n));
    }
  });

  test('по умолчанию есть символы всех четырёх наборов', () {
    for (var i = 0; i < 200; i++) {
      final p = generatePassword(const PasswordOptions(length: 4));
      expect(has(p, lowerChars), isTrue);
      expect(has(p, upperChars), isTrue);
      expect(has(p, digitChars), isTrue);
      expect(has(p, symbolChars), isTrue);
    }
  });

  test('используются только включённые наборы', () {
    final p = generatePassword(
      const PasswordOptions(
        length: 64,
        lower: false,
        upper: false,
        symbols: false,
      ),
    );
    expect(p.split('').every(digitChars.contains), isTrue);

    final q = generatePassword(
      const PasswordOptions(length: 64, digits: false, symbols: false),
    );
    expect(
      q.split('').every((c) => (lowerChars + upperChars).contains(c)),
      isTrue,
    );
  });

  test('два пароля подряд различаются', () {
    expect(
      generatePassword(const PasswordOptions(length: 32)),
      isNot(generatePassword(const PasswordOptions(length: 32))),
    );
  });

  test('с одинаковым Random результат повторяется', () {
    const o = PasswordOptions(length: 24);
    expect(
      generatePassword(o, random: Random(7)),
      generatePassword(o, random: Random(7)),
    );
  });

  test('ни одного набора → ArgumentError', () {
    expect(
      () => generatePassword(
        const PasswordOptions(
          length: 10,
          lower: false,
          upper: false,
          digits: false,
          symbols: false,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('длина меньше числа наборов или вне 1..128 → ArgumentError', () {
    expect(
      () => generatePassword(const PasswordOptions(length: 3)),
      throwsArgumentError,
    );
    expect(
      () => generatePassword(const PasswordOptions(length: 0)),
      throwsArgumentError,
    );
    expect(
      () => generatePassword(const PasswordOptions(length: 129)),
      throwsArgumentError,
    );
    expect(
      generatePassword(
        const PasswordOptions(
          length: 1,
          upper: false,
          digits: false,
          symbols: false,
        ),
      ),
      hasLength(1),
    );
  });
}
