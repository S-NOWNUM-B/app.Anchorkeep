import 'package:anchorkeep/core/security/clipboard_guard.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_timer.dart';

/// Буфер обмена в памяти. [readable] = false имитирует запрет чтения
/// (Android 10+ в фоне).
class FakeClipboard implements ClipboardPort {
  String? text;
  bool readable = true;

  @override
  Future<void> write(String t) async => text = t;

  @override
  Future<String?> read() async => readable ? text : null;
}

void main() {
  late FakeClipboard clip;
  late List<FakeTimer> timers;
  late ClipboardGuard guard;

  setUp(() {
    clip = FakeClipboard();
    timers = [];
    guard = ClipboardGuard(
      clip,
      schedule: (d, f) {
        final t = FakeTimer(d, f);
        timers.add(t);
        return t;
      },
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('copy кладёт текст и ставит таймер на 30 секунд', () async {
    await guard.copy('hunter2');
    expect(clip.text, 'hunter2');
    expect(timers.single.duration, const Duration(seconds: 30));
  });

  test('по таймеру буфер очищается, если там всё ещё наш пароль', () async {
    await guard.copy('hunter2');
    timers.single.fire();
    await settle();
    expect(clip.text, '');
  });

  test('если пользователь скопировал другое — не трогаем', () async {
    await guard.copy('hunter2');
    clip.text = 'чужой текст';
    timers.single.fire();
    await settle();
    expect(clip.text, 'чужой текст');
  });

  test('если буфер нельзя прочитать — очищаем на всякий случай', () async {
    await guard.copy('hunter2');
    clip.readable = false;
    timers.single.fire();
    await settle();
    expect(clip.text, '');
  });

  test('повторный copy отменяет прежний таймер', () async {
    await guard.copy('first');
    await guard.copy('second');
    expect(timers.first.cancelled, isTrue);
    expect(timers, hasLength(2));
    expect(clip.text, 'second');
  });

  test('clear() очищает сразу и отменяет таймер', () async {
    await guard.copy('hunter2');
    await guard.clear();
    expect(clip.text, '');
    expect(timers.single.cancelled, isTrue);
  });

  test('clear() без предыдущего copy ничего не делает', () async {
    clip.text = 'не наше';
    await guard.clear();
    expect(clip.text, 'не наше');
  });

  test('после очистки второй clear() ничего не делает', () async {
    await guard.copy('hunter2');
    await guard.clear();
    clip.text = 'новое';
    await guard.clear();
    expect(clip.text, 'новое');
  });
}
