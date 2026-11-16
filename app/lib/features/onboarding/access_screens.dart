// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/shared/access_scaffold.dart';
import 'package:anchorkeep/shared/status_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return const _MobileWelcomeScreen();
    }
    final colors = VaultColors.of(context);
    return AccessScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Emblem(icon: LucideIcons.keyRound),
          const SizedBox(height: 28),
          Text(
            tr(
              context,
              'Один пароль.\nПолный контроль.',
              'One password.\nFull control.',
            ),
            style: TextStyle(
              color: colors.ink,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.13,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              context,
              'Пароли и заметки остаются на вашем устройстве. Без регистрации, облака и синхронизации.',
              'Your passwords and notes stay on your device. No account, cloud, or sync.',
            ),
            style: TextStyle(color: colors.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/create'),
              icon: const Icon(LucideIcons.arrowRight, size: 17),
              label: Text(tr(context, 'Создать сейф', 'Create vault')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/restore'),
              icon: const Icon(LucideIcons.rotateCcw, size: 17),
              label: Text(
                tr(context, 'Восстановить из бэкапа', 'Restore from backup'),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 15, color: colors.gold),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'Ваш сейф зашифрован и доступен офлайн.',
                    'Your vault is encrypted and available offline.',
                  ),
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileWelcomeScreen extends StatelessWidget {
  const _MobileWelcomeScreen();

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final size = MediaQuery.sizeOf(context);
    const gutter = 20.0;
    final cardHeight = ((size.width - gutter * 2) * .78).clamp(230.0, 300.0);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: VaultBrand(compact: true),
                              ),
                            ),
                          ),
                          LanguageButton(subtle: true),
                          SizedBox(width: 6),
                          ThemeButton(subtle: true),
                        ],
                      ),
                      const SizedBox(height: 30),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .96, end: 1),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: ((value - .96) / .04).clamp(0.0, 1.0),
                          child: Transform.scale(scale: value, child: child),
                        ),
                        child: Container(
                          key: const ValueKey('welcome-hero'),
                          width: double.infinity,
                          height: cardHeight,
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                key: const ValueKey('welcome-shield'),
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  color: colors.goldSoft,
                                  borderRadius: BorderRadius.circular(29),
                                ),
                                child: Icon(
                                  LucideIcons.shieldCheck,
                                  size: 48,
                                  color: colors.gold,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                tr(
                                  context,
                                  'ЗАШИФРОВАНО · ЛОКАЛЬНО',
                                  'ENCRYPTED · LOCAL',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? colors.gold
                                      : colors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        tr(
                          context,
                          'Ваш сейф.\nТолько ваш.',
                          'Your vault.\nYours alone.',
                        ),
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: size.width < 340 ? 26 : 28,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        tr(
                          context,
                          'Пароли и заметки остаются на вашем устройстве — без аккаунта, сервера и облака.',
                          'Passwords and notes stay on your device — no account, server, or cloud.',
                        ),
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _benefit(
                        context,
                        LucideIcons.shieldCheck,
                        tr(
                          context,
                          'Данные не уходят в облако',
                          'Your data never goes to the cloud',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _benefit(
                        context,
                        LucideIcons.lockKeyhole,
                        tr(
                          context,
                          'Обычная работа без интернета',
                          'Works normally without internet',
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => context.go('/create'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(43),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            tr(context, 'Создать сейф', 'Create vault'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/restore'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            tr(
                              context,
                              'Восстановить из бэкапа',
                              'Restore from backup',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          tr(
                            context,
                            'Перенос между устройствами — через .akbackup',
                            'Transfer between devices with .akbackup',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.muted, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(BuildContext context, IconData icon, String text) {
    final colors = VaultColors.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.goldSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: colors.gold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.muted, fontSize: 10, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class CreateVaultScreen extends ConsumerStatefulWidget {
  const CreateVaultScreen({super.key});

  @override
  ConsumerState<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends ConsumerState<CreateVaultScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;
  bool _confirmHidden = true;
  bool _busy = false;
  bool _acknowledged = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int get _strength {
    final value = _password.text;
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 12) score++;
    if (value.length >= 16) score++;
    if (RegExp(r'[A-ZА-Я]').hasMatch(value) &&
        RegExp(r'[a-zа-я]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[0-9!@#\$%^&*()_+=?]').hasMatch(value)) score++;
    return score.clamp(1, 4);
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    if (MediaQuery.sizeOf(context).width < 600 && !_acknowledged) {
      setState(
        () => _error = tr(
          context,
          'Подтвердите, что понимаете риск потери мастер-пароля.',
          'Confirm that you understand the risk of losing your master password.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(vaultSessionProvider.notifier).create(_password.text);
      _password.clear();
      _confirm.clear();
      if (mounted) context.go('/passwords');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = tr(
            context,
            'Не удалось создать сейф. Попробуйте ещё раз.',
            'Could not create the vault. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    if (mobile) return _buildMobile(context, colors);
    return AccessScaffold(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Emblem(icon: LucideIcons.lockKeyhole),
            const SizedBox(height: 20),
            Text(
              tr(context, 'Создайте свой сейф', 'Create your vault'),
              style: TextStyle(
                color: colors.ink,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              tr(
                context,
                'Мастер-пароль станет единственным ключом к вашим данным.',
                'Your master password is the only key to your data.',
              ),
              style: TextStyle(color: colors.muted, fontSize: 13),
            ),
            const SizedBox(height: 27),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr(context, 'Мастер-пароль', 'Master password'),
                prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 18),
                suffixIcon: IconButton(
                  tooltip: tr(context, 'Показать пароль', 'Show password'),
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 18,
                  ),
                ),
              ),
              validator: (value) => (value?.length ?? 0) < 12
                  ? tr(
                      context,
                      'Используйте не менее 12 символов.',
                      'Use at least 12 characters.',
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _hidden,
              enableSuggestions: false,
              autocorrect: false,
              onFieldSubmitted: (_) => _create(),
              decoration: InputDecoration(
                labelText: tr(context, 'Повторите пароль', 'Confirm password'),
                prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 18),
              ),
              validator: (value) => value != _password.text
                  ? tr(
                      context,
                      'Пароли не совпадают.',
                      'Passwords do not match.',
                    )
                  : null,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Text(
                  tr(context, 'Надёжность пароля', 'Password strength'),
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  _strength < 3
                      ? tr(context, 'Низкая', 'Low')
                      : tr(context, 'Хорошая', 'Good'),
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: index < _strength ? colors.success : colors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 21),
            _Notice(
              icon: LucideIcons.shieldAlert,
              text: tr(
                context,
                'Если вы забудете мастер-пароль, восстановить данные будет невозможно.',
                'If you forget your master password, your data cannot be recovered.',
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.only(top: _error == null ? 0 : 12),
              child: StatusLabel(message: _error),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        tr(
                          context,
                          'Создать зашифрованный сейф',
                          'Create encrypted vault',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.go('/welcome'),
                child: Text(tr(context, 'Назад', 'Back')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context, VaultColors colors) {
    const gutter = 21.0;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(gutter, 24, gutter, 16),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: tr(context, 'Назад', 'Back'),
                              onPressed: _busy
                                  ? null
                                  : () => context.go('/welcome'),
                              style: IconButton.styleFrom(
                                backgroundColor: colors.soft,
                                foregroundColor: colors.muted,
                                minimumSize: const Size(36, 36),
                                maximumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              icon: const Icon(LucideIcons.arrowLeft, size: 17),
                            ),
                            const Spacer(),
                            Text(
                              tr(context, 'НОВЫЙ СЕЙФ', 'NEW VAULT'),
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr(context, 'Создайте сейф', 'Create vault'),
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            context,
                            'Придумайте мастер-пароль. Он защищает данные на этом устройстве.',
                            'Create a master password. It protects data on this device.',
                          ),
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _mobileLabel(
                          context,
                          'Мастер-пароль',
                          'Master password',
                        ),
                        const SizedBox(height: 6),
                        _mobilePasswordField(context, confirm: false),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            context,
                            'Рекомендуем длинную уникальную фразу.',
                            'Use a long, unique passphrase.',
                          ),
                          style: TextStyle(color: colors.muted, fontSize: 10),
                        ),
                        const SizedBox(height: 17),
                        _mobileLabel(
                          context,
                          'Подтвердите пароль',
                          'Confirm password',
                        ),
                        const SizedBox(height: 6),
                        _mobilePasswordField(context, confirm: true),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              tr(
                                context,
                                'Надёжность пароля',
                                'Password strength',
                              ),
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _strength >= 3
                                  ? tr(context, 'Высокая', 'High')
                                  : _strength == 2
                                  ? tr(context, 'Средняя', 'Medium')
                                  : tr(context, 'Низкая', 'Low'),
                              style: TextStyle(
                                color: _strength >= 3
                                    ? colors.success
                                    : colors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(
                            4,
                            (index) => Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 5,
                                margin: EdgeInsets.only(
                                  right: index == 3 ? 0 : 5,
                                ),
                                decoration: BoxDecoration(
                                  color: index < _strength
                                      ? colors.success
                                      : colors.line,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.goldSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.triangleAlert,
                                color: colors.gold,
                                size: 19,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(
                                        context,
                                        'Важно помнить',
                                        'Important to remember',
                                      ),
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      tr(
                                        context,
                                        'При потере мастер-пароля данные восстановить нельзя. Даже через блокчейн.',
                                        'If you lose your master password, your data cannot be recovered, even through the blockchain.',
                                      ),
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 10,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 17),
                        Semantics(
                          checked: _acknowledged,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _busy
                                ? null
                                : () => setState(
                                    () => _acknowledged = !_acknowledged,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 19,
                                    height: 19,
                                    decoration: BoxDecoration(
                                      color: _acknowledged
                                          ? colors.goldSoft
                                          : colors.surface,
                                      border: Border.all(color: colors.gold),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: _acknowledged
                                        ? Icon(
                                            LucideIcons.check,
                                            size: 14,
                                            color: colors.gold,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tr(
                                        context,
                                        'Я понимаю риск потери мастер-пароля',
                                        'I understand the risk of losing my master password',
                                      ),
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: EdgeInsets.only(
                            top: _error == null ? 0 : 12,
                          ),
                          child: StatusLabel(message: _error),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _create,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(43),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    tr(
                                      context,
                                      'Создать зашифрованный сейф',
                                      'Create encrypted vault',
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            tr(
                              context,
                              'Пароль не отправляется в интернет.',
                              'Your password is never sent to the internet.',
                            ),
                            style: TextStyle(color: colors.muted, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileLabel(BuildContext context, String ru, String en) {
    final colors = VaultColors.of(context);
    return Text(
      tr(context, ru, en),
      style: TextStyle(color: colors.muted, fontSize: 11),
    );
  }

  Widget _mobilePasswordField(BuildContext context, {required bool confirm}) {
    final hidden = confirm ? _confirmHidden : _hidden;
    return TextFormField(
      controller: confirm ? _confirm : _password,
      obscureText: hidden,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: confirm ? TextInputAction.done : TextInputAction.next,
      onChanged: confirm ? null : (_) => setState(() {}),
      onFieldSubmitted: confirm ? (_) => _create() : null,
      decoration: InputDecoration(
        hintText: '••••••••••••',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 16),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon: IconButton(
          tooltip: hidden
              ? tr(context, 'Показать пароль', 'Show password')
              : tr(context, 'Скрыть пароль', 'Hide password'),
          onPressed: () => setState(() {
            if (confirm) {
              _confirmHidden = !_confirmHidden;
            } else {
              _hidden = !_hidden;
            }
          }),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 17),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
      validator: confirm
          ? (value) => value != _password.text
                ? tr(context, 'Пароли не совпадают.', 'Passwords do not match.')
                : null
          : (value) => (value?.length ?? 0) < 12
                ? tr(
                    context,
                    'Используйте не менее 12 символов.',
                    'Use at least 12 characters.',
                  )
                : null,
    );
  }
}

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    if (_password.text.isEmpty) {
      if (MediaQuery.sizeOf(context).width < 600) {
        setState(
          () => _error = tr(
            context,
            'Введите мастер-пароль.',
            'Enter your master password.',
          ),
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(vaultSessionProvider.notifier).unlock(_password.text);
      _password.clear();
      if (mounted) context.go('/passwords');
    } on VaultAuthException {
      if (mounted) {
        setState(() {
          _error = MediaQuery.sizeOf(context).width < 600
              ? tr(
                  context,
                  'Проверьте пароль и попробуйте ещё раз.',
                  'Check your password and try again.',
                )
              : tr(
                  context,
                  'Не удалось разблокировать сейф. Проверьте пароль.',
                  'Could not unlock the vault. Check your password.',
                );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = tr(
            context,
            'Не удалось открыть сейф. Попробуйте ещё раз.',
            'Could not open the vault. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    if (mobile) return _buildMobile(context, colors);
    return AccessScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Emblem(icon: LucideIcons.lockKeyhole),
          const SizedBox(height: 20),
          Text(
            tr(context, 'Добро пожаловать обратно', 'Welcome back'),
            style: TextStyle(
              color: colors.ink,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr(
              context,
              'Введите мастер-пароль, чтобы открыть сейф.',
              'Enter your master password to open the vault.',
            ),
            style: TextStyle(color: colors.muted, fontSize: 13),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: _hidden,
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (_) => _unlock(),
            decoration: InputDecoration(
              labelText: tr(context, 'Мастер-пароль', 'Master password'),
              prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 18),
              suffixIcon: IconButton(
                tooltip: tr(context, 'Показать пароль', 'Show password'),
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.only(top: _error == null ? 0 : 10),
            child: StatusLabel(message: _error),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _unlock,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr(context, 'Разблокировать', 'Unlock')),
            ),
          ),
          const SizedBox(height: 10),
          _Notice(
            icon: LucideIcons.shieldCheck,
            text: tr(
              context,
              'Ваши данные остаются только на этом устройстве.',
              'Your data stays on this device.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, VaultColors colors) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: VaultBrand(compact: true),
                              ),
                            ),
                          ),
                          LanguageButton(subtle: true),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: .94, end: 1),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: ((value - .94) / .06).clamp(0.0, 1.0),
                            child: Transform.scale(scale: value, child: child),
                          ),
                          child: Container(
                            key: const ValueKey('unlock-emblem'),
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              color: colors.goldSoft,
                              borderRadius: BorderRadius.circular(29),
                            ),
                            child: Icon(
                              LucideIcons.lockKeyhole,
                              color: colors.gold,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 27),
                      Text(
                        tr(context, 'С возвращением', 'Welcome back'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          context,
                          'Введите мастер-пароль, чтобы открыть локальный сейф.',
                          'Enter your master password to open your local vault.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        tr(context, 'Мастер-пароль', 'Master password'),
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _password,
                        obscureText: _hidden,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _unlock(),
                        decoration: InputDecoration(
                          hintText: tr(
                            context,
                            'Мастер-пароль',
                            'Master password',
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.lockKeyhole,
                            size: 16,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _hidden
                                ? tr(
                                    context,
                                    'Показать пароль',
                                    'Show password',
                                  )
                                : tr(context, 'Скрыть пароль', 'Hide password'),
                            onPressed: () => setState(() => _hidden = !_hidden),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                              size: 17,
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: Container(
                          key: ValueKey(_error == null),
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colors.goldSoft,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  LucideIcons.shieldCheck,
                                  color: colors.gold,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _error == null
                                          ? tr(
                                              context,
                                              'Сейф заблокирован',
                                              'Vault locked',
                                            )
                                          : _password.text.isEmpty
                                          ? tr(
                                              context,
                                              'Введите мастер-пароль',
                                              'Enter master password',
                                            )
                                          : tr(
                                              context,
                                              'Не удалось разблокировать',
                                              'Could not unlock',
                                            ),
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _error ??
                                          tr(
                                            context,
                                            'Доступ только по вашему мастер-паролю.',
                                            'Only your master password opens the vault.',
                                          ),
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 10,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _unlock,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(43),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(tr(context, 'Разблокировать', 'Unlock')),
                        ),
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => context.go('/restore'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            tr(
                              context,
                              'Восстановить из бэкапа',
                              'Restore from backup',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr(
                          context,
                          'Доступ только по мастер-паролю.',
                          'Access requires your master password.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colors.goldSoft,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(icon, color: colors.gold, size: 25),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.goldSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.gold, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.ink, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
