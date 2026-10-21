// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/core/security/auto_lock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Оборачивает экраны открытого сейфа: блокирует по неактивности и сразу
/// при сворачивании приложения. Размещать только там, где сейф разблокирован;
/// [onLock] должен перевести `vaultSessionProvider` в `locked` и вызвать
/// `VaultSession.close()`.
///
/// Активностью считаются касания, прокрутка и клавиши (иначе длинная
/// заметка закрылась бы прямо во время набора). Сворачивание ловим по
/// `hidden`, а не по `inactive`: на desktop `inactive` — это просто потеря
/// фокуса окном.
class AutoLockScope extends StatefulWidget {
  const AutoLockScope({
    required this.timeout,
    required this.onLock,
    required this.child,
    super.key,
  });

  final Duration timeout;
  final VoidCallback onLock;
  final Widget child;

  @override
  State<AutoLockScope> createState() => _AutoLockScopeState();
}

class _AutoLockScopeState extends State<AutoLockScope> {
  late final AutoLock _lock;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lock = AutoLock(timeout: widget.timeout, onLock: () => widget.onLock())
      ..start();
    _lifecycle = AppLifecycleListener(
      onHide: _lock.lockNow,
      onPause: _lock.lockNow,
    );
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(AutoLockScope old) {
    super.didUpdateWidget(old);
    if (old.timeout != widget.timeout) _lock.timeout = widget.timeout;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    _lock.stop();
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _lock.touch();
    return false; // событие не перехватываем
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _lock.touch(),
    onPointerMove: (_) => _lock.touch(),
    onPointerSignal: (_) => _lock.touch(),
    child: widget.child,
  );
}
