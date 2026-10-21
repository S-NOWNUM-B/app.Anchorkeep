import 'package:anchorkeep/core/security/auto_lock_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _timeout = Duration(minutes: 5);

Future<void> pumpScope(
  WidgetTester tester,
  void Function() onLock, {
  Duration timeout = _timeout,
}) => tester.pumpWidget(
  AutoLockScope(
    timeout: timeout,
    onLock: onLock,
    child: const ColoredBox(color: Colors.white),
  ),
);

void main() {
  testWidgets('без активности блокирует по таймауту', (tester) async {
    var locks = 0;
    await pumpScope(tester, () => locks++);
    await tester.pump(_timeout - const Duration(seconds: 1));
    expect(locks, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(locks, 1);
  });

  testWidgets('касание сбрасывает таймер', (tester) async {
    var locks = 0;
    await pumpScope(tester, () => locks++);
    await tester.pump(const Duration(minutes: 4));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(minutes: 4));
    expect(locks, 0);
    await tester.pump(const Duration(minutes: 2));
    expect(locks, 1);
  });

  testWidgets('нажатие клавиши (набор текста) тоже сбрасывает таймер', (
    tester,
  ) async {
    var locks = 0;
    await pumpScope(tester, () => locks++);
    await tester.pump(const Duration(minutes: 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump(const Duration(minutes: 4));
    expect(locks, 0);
    await tester.pump(const Duration(minutes: 2));
    expect(locks, 1);
  });

  testWidgets('сворачивание приложения блокирует сразу', (tester) async {
    var locks = 0;
    await pumpScope(tester, () => locks++);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(locks, 0, reason: 'потеря фокуса на desktop — ещё не сворачивание');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(locks, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(locks, 1, reason: 'повторной блокировки нет');
  });

  testWidgets('смена timeout применяется', (tester) async {
    var locks = 0;
    await pumpScope(tester, () => locks++);
    await pumpScope(tester, () => locks++, timeout: const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(locks, 1);
  });

  testWidgets('после удаления виджета блокировки нет', (tester) async {
    var locks = 0;
    await pumpScope(tester, () => locks++);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(_timeout * 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(locks, 0);
  });
}
