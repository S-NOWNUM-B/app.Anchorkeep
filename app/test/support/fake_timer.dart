import 'dart:async';

/// Таймер, который срабатывает вручную через [fire]: тесты не ждут время.
class FakeTimer implements Timer {
  FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    fired = true;
    _callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}
