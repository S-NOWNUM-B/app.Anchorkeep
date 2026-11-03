// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/shared/status_label.dart';
import 'package:anchorkeep/core/vault/atomic_write.dart';
import 'package:anchorkeep/core/vault/change_password.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _current.clear();
    _next.clear();
    _confirm.clear();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await changeMasterPassword(session, _current.text, _next.text, (
        bytes,
      ) async {
        final path = await ref.read(vaultPathProvider.future);
        await writeFileAtomic(path, bytes);
      });
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final message = tr(
          context,
          'Мастер-пароль изменён. Создайте новую копию и зарегистрируйте версию заново.',
          'Master password changed. Create a new backup and register the version again.',
        );
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            'Не удалось изменить пароль. Проверьте текущий пароль.',
            'Could not change password. Check the current password.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(mobile ? 20 : 26),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.goldSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        LucideIcons.keyRound,
                        color: colors.gold,
                        size: 23,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: tr(context, 'Закрыть', 'Close'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.soft,
                        foregroundColor: colors.muted,
                        minimumSize: const Size(36, 36),
                        maximumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  tr(
                    context,
                    'Сменить мастер-пароль',
                    'Change master password',
                  ),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    context,
                    'Новый пароль будет защищать ваш сейф на этом устройстве.',
                    'Your new password will protect this vault on this device.',
                  ),
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                _passwordField(
                  controller: _current,
                  label: tr(context, 'Текущий пароль', 'Current password'),
                  hint: tr(
                    context,
                    'Введите текущий пароль',
                    'Enter current password',
                  ),
                  visible: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  validator: (value) => value == null || value.isEmpty
                      ? tr(
                          context,
                          'Введите текущий пароль.',
                          'Enter current password.',
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _next,
                  label: tr(context, 'Новый пароль', 'New password'),
                  hint: tr(
                    context,
                    'Минимум 12 символов',
                    'At least 12 characters',
                  ),
                  visible: _showNext,
                  onToggle: () => setState(() => _showNext = !_showNext),
                  validator: (value) => (value?.length ?? 0) < 12
                      ? tr(
                          context,
                          'Минимум 12 символов.',
                          'At least 12 characters.',
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _confirm,
                  label: tr(
                    context,
                    'Подтвердите новый пароль',
                    'Confirm new password',
                  ),
                  hint: tr(
                    context,
                    'Повторите новый пароль',
                    'Repeat new password',
                  ),
                  visible: _showConfirm,
                  onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  validator: (value) => value != _next.text
                      ? tr(
                          context,
                          'Пароли не совпадают.',
                          'Passwords do not match.',
                        )
                      : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 19),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.goldSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.triangleAlert,
                        color: colors.warning,
                        size: 17,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr(
                            context,
                            'Запомните новый пароль. После смены создайте свежий бэкап и заверьте новую версию.',
                            'Remember the new password. Then create a fresh backup and anchor the new version.',
                          ),
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  StatusLabel(message: _error),
                ],
                const SizedBox(height: 22),
                if (mobile) ...[
                  _saveButton(),
                  const SizedBox(height: 9),
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(tr(context, 'Отмена', 'Cancel')),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(tr(context, 'Отмена', 'Cancel')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _saveButton()),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = VaultColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: !_busy,
          obscureText: !visible,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 17),
            suffixIcon: IconButton(
              tooltip: visible
                  ? tr(context, 'Скрыть пароль', 'Hide password')
                  : tr(context, 'Показать пароль', 'Show password'),
              onPressed: _busy ? null : onToggle,
              icon: Icon(
                visible ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 17,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _saveButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: _busy ? null : _save,
      icon: _busy
          ? SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : const Icon(LucideIcons.check, size: 17),
      label: Text(tr(context, 'Сохранить пароль', 'Save password')),
    ),
  );
}
