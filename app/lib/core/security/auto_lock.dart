// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

const _defaultTimeout = Duration(minutes: 5);
const _maxMinutes = 120;

/// Таймаут автоблокировки из `payload['settings']['autoLockMinutes']`.
/// Нет значения, не целое или вне 1–120 → 5 минут по умолчанию.
Duration autoLockTimeoutFrom(Map<String, Object?> payload) {
  final settings = payload['settings'];
  final minutes = settings is Map<String, Object?>
      ? settings['autoLockMinutes']
      : null;
  if (minutes is int && minutes >= 1 && minutes <= _maxMinutes) {
    return Duration(minutes: minutes);
  }
  return _defaultTimeout;
}

/// Блокировка по неактивности. Работает, пока сейф открыт: [start] после
/// разблокировки, [stop] при ручной блокировке. [touch] — любое действие
/// пользователя, оно перезапускает отсчёт; [lockNow] — немедленная
/// блокировка (приложение свернули). [onLock] вызывается не больше одного
/// раза за запуск.
class AutoLock {
  AutoLock({
    required this._timeout,
    required this.onLock,
    this.schedule = Timer.new,
  });

  final void Function() onLock;

  /// Как ставить таймер (подменяется в тестах).
  final Timer Function(Duration, void Function()) schedule;

  Duration _timeout;
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  Duration get timeout => _timeout;

  set timeout(Duration value) {
    _timeout = value;
    if (_running) _arm();
  }

  void start() {
    _running = true;
    _arm();
  }

  void touch() {
    if (_running) _arm();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void lockNow() {
    if (!_running) return;
    stop();
    onLock();
  }

  void _arm() {
    _timer?.cancel();
    _timer = schedule(_timeout, lockNow);
  }
}
