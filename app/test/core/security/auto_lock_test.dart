import 'package:anchorkeep/core/security/auto_lock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_timer.dart';

void main() {
  late List<FakeTimer> timers;
  late int locks;
  late AutoLock lock;

  setUp(() {
    timers = [];
    locks = 0;
    lock = AutoLock(
      timeout: const Duration(minutes: 5),
      onLock: () => locks++,
      schedule: (d, f) {
        final t = FakeTimer(d, f);
        timers.add(t);
        return t;
      },
    );
  });

  test('после start блокирует по истечении таймаута', () {
    lock.start();
    expect(timers.single.duration, const Duration(minutes: 5));
    expect(locks, 0);
    timers.single.fire();
    expect(locks, 1);
    expect(lock.isRunning, isFalse);
  });

  test('touch сбрасывает таймер: старый отменён, новый на полный срок', () {
    lock.start();
    lock.touch();
    expect(timers, hasLength(2));
    expect(timers.first.cancelled, isTrue);
    expect(timers.last.duration, const Duration(minutes: 5));
  });

  test('lockNow блокирует сразу и один раз', () {
    lock.start();
    lock.lockNow();
    lock.lockNow();
    expect(locks, 1);
    expect(timers.single.cancelled, isTrue);
    expect(lock.isRunning, isFalse);
  });

  test('после stop ничего не происходит: ни таймер, ни touch, ни lockNow', () {
    lock.start();
    lock.stop();
    lock.touch();
    lock.lockNow();
    expect(locks, 0);
    expect(timers, hasLength(1));
    expect(timers.single.cancelled, isTrue);
  });

  test('touch и lockNow без start ничего не делают', () {
    lock.touch();
    lock.lockNow();
    expect(locks, 0);
    expect(timers, isEmpty);
  });

  test('смена timeout перезапускает таймер с новым сроком', () {
    lock.start();
    lock.timeout = const Duration(minutes: 1);
    expect(timers.first.cancelled, isTrue);
    expect(timers.last.duration, const Duration(minutes: 1));
  });

  test('смена timeout у остановленного не запускает таймер', () {
    lock.timeout = const Duration(minutes: 1);
    expect(timers, isEmpty);
  });

  group('autoLockTimeoutFrom', () {
    Duration from(Object? settings) =>
        autoLockTimeoutFrom({'settings': ?settings});

    test('по умолчанию 5 минут', () {
      expect(from(null), const Duration(minutes: 5));
      expect(from(<String, Object?>{}), const Duration(minutes: 5));
    });

    test('берёт autoLockMinutes из настроек', () {
      expect(from({'autoLockMinutes': 1}), const Duration(minutes: 1));
      expect(from({'autoLockMinutes': 30}), const Duration(minutes: 30));
    });

    test('мусор и значения вне 1–120 → значение по умолчанию', () {
      for (final bad in [0, -3, 121, 9999, '5', 2.5, null, true]) {
        expect(
          from({'autoLockMinutes': bad}),
          const Duration(minutes: 5),
          reason: '$bad',
        );
      }
      expect(from('не словарь'), const Duration(minutes: 5));
    });
  });
}
