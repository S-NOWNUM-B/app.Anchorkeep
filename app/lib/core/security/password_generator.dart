// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

const lowerChars = 'abcdefghijklmnopqrstuvwxyz';
const upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const digitChars = '0123456789';
const symbolChars = r'!@#$%^&*()-_=+[]{};:,.?';

const _maxLength = 128;

/// Настройки генератора: длина и включённые наборы символов.
class PasswordOptions {
  const PasswordOptions({
    this.length = 20,
    this.lower = true,
    this.upper = true,
    this.digits = true,
    this.symbols = true,
  });

  final int length;
  final bool lower;
  final bool upper;
  final bool digits;
  final bool symbols;

  List<String> get _sets => [
    if (lower) lowerChars,
    if (upper) upperChars,
    if (digits) digitChars,
    if (symbols) symbolChars,
  ];
}

/// Случайный пароль. Из каждого включённого набора берётся минимум один
/// символ (этого требуют многие сайты), остальное — из объединения наборов,
/// затем всё перемешивается. [random] можно подменить в тестах;
/// по умолчанию — `Random.secure()`.
String generatePassword(PasswordOptions o, {Random? random}) {
  final sets = o._sets;
  if (sets.isEmpty) throw ArgumentError('Включите хотя бы один набор символов');
  if (o.length < sets.length || o.length > _maxLength) {
    throw ArgumentError.value(
      o.length,
      'length',
      'должна быть от ${sets.length} до $_maxLength',
    );
  }
  final rng = random ?? Random.secure();
  final all = sets.join();
  final chars = [
    for (final s in sets) s[rng.nextInt(s.length)],
    for (var i = sets.length; i < o.length; i++) all[rng.nextInt(all.length)],
  ]..shuffle(rng);
  return chars.join();
}
