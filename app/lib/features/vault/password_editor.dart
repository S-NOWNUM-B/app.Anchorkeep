// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/security/password_generator.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/features/session/entries_controller.dart';
import 'package:anchorkeep/shared/status_label.dart';
import 'package:anchorkeep/shared/vault_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Полноэкранная форма из Password flows. Оболочка приложения остаётся на месте.
class PasswordEditor extends ConsumerStatefulWidget {
  const PasswordEditor({
    required this.onCancel,
    required this.onSaved,
    this.entry,
    super.key,
  });

  final Entry? entry;
  final VoidCallback onCancel;
  final ValueChanged<Entry> onSaved;

  @override
  ConsumerState<PasswordEditor> createState() => _PasswordEditorState();
}

class _PasswordEditorState extends ConsumerState<PasswordEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _login = TextEditingController(
    text: widget.entry?.fields['login'] ?? '',
  );
  late final _password = TextEditingController(
    text: widget.entry?.fields['password'] ?? '',
  );
  late final _url = TextEditingController(
    text: widget.entry?.fields['url'] ?? '',
  );
  late final _note = TextEditingController(
    text: widget.entry?.fields['note'] ?? '',
  );
  bool _hidden = true;
  bool _saving = false;
  bool _validationError = false;
  String? _saveError;

  @override
  void dispose() {
    for (final controller in [_title, _login, _password, _url, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final String? value = mobile
        ? await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: VaultColors.of(context).surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => const SafeArea(child: PasswordGeneratorPanel()),
          )
        : await showDialog<String>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const PasswordGeneratorPanel(),
              ),
            ),
          );
    if (value != null && mounted) {
      setState(() {
        _password.text = value;
        _validationError = false;
      });
      _form.currentState?.validate();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      setState(() => _validationError = true);
      return;
    }
    setState(() {
      _saving = true;
      _validationError = false;
      _saveError = null;
    });
    final fields = {
      'login': _login.text.trim(),
      'password': _password.text,
      'url': _url.text.trim(),
      'note': _note.text.trim(),
    };
    try {
      final entries = ref.read(entriesProvider.notifier);
      final saved = widget.entry == null
          ? await entries.add(EntryType.password, _title.text.trim(), fields)
          : await entries.update(
              widget.entry!.id,
              title: _title.text.trim(),
              fields: fields,
            );
      if (mounted) widget.onSaved(saved);
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = tr(
            context,
            'Не удалось сохранить пароль. Попробуйте ещё раз.',
            'Could not save the password. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = VaultColors.of(context);
      final desktop = constraints.maxWidth >= 940;
      final gutter = VaultLayout.gutter(constraints.maxWidth);
      final editing = widget.entry != null;
      if (constraints.maxWidth < 600) {
        return _mobileEditor(context, gutter: gutter, editing: editing);
      }
      final form = Form(
        key: _form,
        onChanged: () {
          if (_validationError && (_form.currentState?.validate() ?? false)) {
            setState(() => _validationError = false);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (desktop)
              Text(
                tr(context, 'ДАННЫЕ УЧЁТНОЙ ЗАПИСИ', 'ACCOUNT DETAILS'),
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            if (desktop) const SizedBox(height: 14),
            _field(
              context,
              label: tr(context, 'Название', 'Title'),
              child: TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: tr(context, 'Введите название', 'Enter a title'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? tr(
                        context,
                        'Укажите название записи.',
                        'Enter a title for this entry.',
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _pair(
              desktop,
              _field(
                context,
                label: tr(context, 'Логин', 'Login'),
                child: TextFormField(
                  controller: _login,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: tr(context, 'Введите логин', 'Enter a login'),
                  ),
                ),
              ),
              _field(
                context,
                label: tr(context, 'Пароль', 'Password'),
                child: TextFormField(
                  controller: _password,
                  obscureText: _hidden,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: tr(context, 'Введите пароль', 'Enter a password'),
                    suffixIcon: IconButton(
                      tooltip: tr(
                        context,
                        _hidden ? 'Показать пароль' : 'Скрыть пароль',
                        _hidden ? 'Show password' : 'Hide password',
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return tr(
                        context,
                        'Введите пароль.',
                        'Enter a password.',
                      );
                    }
                    if (value.length < 8) {
                      return tr(
                        context,
                        'Используйте не менее 8 символов.',
                        'Use at least 8 characters.',
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _generate,
                icon: const Icon(LucideIcons.wandSparkles, size: 16),
                label: Text(
                  tr(
                    context,
                    'Сгенерировать надёжный пароль',
                    'Generate a strong password',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _pair(
              desktop,
              _field(
                context,
                label: 'URL',
                child: TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com',
                  ),
                ),
              ),
              _field(
                context,
                label: tr(context, 'Заметка', 'Note'),
                child: TextFormField(
                  controller: _note,
                  maxLines: desktop ? 1 : 3,
                  decoration: InputDecoration(
                    hintText: tr(
                      context,
                      'Дополнительная информация',
                      'Additional information',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.lockKeyhole, color: colors.gold, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Запись шифруется локально и не отправляется на сервер.',
                        'This entry is encrypted locally and never sent to a server.',
                      ),
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            if (_validationError || _saveError != null) ...[
              const SizedBox(height: 14),
              StatusLabel(
                message:
                    _saveError ??
                    tr(
                      context,
                      'Поля отмечены красным. Запись пока не сохранена.',
                      'Fix the highlighted fields before saving.',
                    ),
              ),
            ],
            if (!desktop) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: Text(
                    tr(
                      context,
                      editing ? 'Сохранить изменения' : 'Сохранить пароль',
                      editing ? 'Save changes' : 'Save password',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

      return SingleChildScrollView(
        padding: EdgeInsets.all(gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!desktop)
                  IconButton(
                    tooltip: tr(context, 'Назад', 'Back'),
                    onPressed: widget.onCancel,
                    icon: const Icon(LucideIcons.arrowLeft, size: 19),
                  ),
                Text(
                  tr(
                    context,
                    editing ? 'Редактировать пароль' : 'Создать пароль',
                    editing ? 'Edit password' : 'Create password',
                  ),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: VaultLayout.heading(constraints.maxWidth),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tr(
                    context,
                    editing
                        ? 'Обновите запись, сохранив её без синхронизации и облака.'
                        : 'Добавьте данные, которые будут храниться только на вашем устройстве.',
                    editing
                        ? 'Update this local entry.'
                        : 'Add details that stay on this device.',
                  ),
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
                const SizedBox(height: 22),
                if (desktop)
                  Column(
                    children: [
                      SizedBox(
                        height: 560,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  border: Border.all(color: colors.line),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: SingleChildScrollView(child: form),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 3,
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: colors.soft,
                                  border: Border.all(color: colors.line),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const VaultIllustration(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving ? null : widget.onCancel,
                                    child: Text(
                                      tr(context, 'Отмена', 'Cancel'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _save,
                                    icon: const Icon(
                                      LucideIcons.check,
                                      size: 16,
                                    ),
                                    label: Text(
                                      tr(
                                        context,
                                        editing
                                            ? 'Сохранить изменения'
                                            : 'Сохранить пароль',
                                        editing
                                            ? 'Save changes'
                                            : 'Save password',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          const Expanded(flex: 3, child: SizedBox.shrink()),
                        ],
                      ),
                    ],
                  )
                else
                  form,
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _mobileEditor(
    BuildContext context, {
    required double gutter,
    required bool editing,
  }) {
    final colors = VaultColors.of(context);
    final titleInvalid = _validationError && _title.text.trim().isEmpty;
    final passwordInvalid = _validationError && _password.text.length < 8;
    final form = Form(
      key: _form,
      onChanged: () {
        if (_validationError && (_form.currentState?.validate() ?? false)) {
          setState(() => _validationError = false);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _mobileField(
            context,
            label: tr(context, 'Название', 'Title'),
            invalid: titleInvalid,
            child: TextFormField(
              controller: _title,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: colors.ink, fontSize: 14),
              decoration: _mobileInputDecoration(
                context,
                hint: tr(context, 'Введите название', 'Enter a title'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? tr(
                      context,
                      'Укажите название записи.',
                      'Enter a title for this entry.',
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 13),
          _mobileField(
            context,
            label: tr(context, 'Логин', 'Login'),
            child: TextFormField(
              controller: _login,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: colors.ink, fontSize: 14),
              decoration: _mobileInputDecoration(
                context,
                hint: tr(context, 'Введите логин', 'Enter a login'),
              ),
            ),
          ),
          const SizedBox(height: 13),
          _mobileField(
            context,
            label: tr(context, 'Пароль', 'Password'),
            invalid: passwordInvalid,
            child: TextFormField(
              controller: _password,
              obscureText: _hidden,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: colors.ink, fontSize: 14),
              decoration:
                  _mobileInputDecoration(
                    context,
                    hint: tr(context, 'Введите пароль', 'Enter a password'),
                  ).copyWith(
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    suffixIcon: IconButton(
                      tooltip: tr(
                        context,
                        _hidden ? 'Показать пароль' : 'Скрыть пароль',
                        _hidden ? 'Show password' : 'Hide password',
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 16,
                      ),
                    ),
                  ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return tr(context, 'Введите пароль.', 'Enter a password.');
                }
                if (value.length < 8) {
                  return tr(
                    context,
                    'Рекомендуем более длинный пароль.',
                    'Use a longer password.',
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _generate,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(LucideIcons.wandSparkles, size: 14),
              label: Text(
                tr(
                  context,
                  _validationError
                      ? 'Создать надёжный пароль'
                      : 'Сгенерировать надёжный пароль',
                  _validationError
                      ? 'Create a strong password'
                      : 'Generate a strong password',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _mobileField(
            context,
            label: 'URL',
            child: TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: colors.ink, fontSize: 14),
              decoration: _mobileInputDecoration(
                context,
                hint: 'https://example.com',
              ),
            ),
          ),
          const SizedBox(height: 13),
          _mobileField(
            context,
            label: tr(context, 'Заметка', 'Note'),
            child: TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 2,
              style: TextStyle(color: colors.ink, fontSize: 14),
              decoration: _mobileInputDecoration(
                context,
                hint: tr(
                  context,
                  'Дополнительная информация',
                  'Additional information',
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          tooltip: tr(context, 'Назад', 'Back'),
                          padding: EdgeInsets.zero,
                          onPressed: widget.onCancel,
                          icon: Icon(
                            LucideIcons.arrowLeft,
                            color: colors.muted,
                            size: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tr(
                            context,
                            editing ? 'Редактирование' : 'Новый пароль',
                            editing ? 'Editing' : 'New password',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Text(
                    tr(
                      context,
                      editing ? 'Изменить запись' : 'Добавить пароль',
                      editing ? 'Edit entry' : 'Add password',
                    ),
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _validationError
                        ? tr(
                            context,
                            'Проверьте выделенные поля.',
                            'Check the highlighted fields.',
                          )
                        : tr(
                            context,
                            editing
                                ? 'Изменения сохранятся только в сейфе.'
                                : 'Все данные будут зашифрованы локально.',
                            editing
                                ? 'Changes stay in your vault only.'
                                : 'All data is encrypted locally.',
                          ),
                    style: TextStyle(
                      color: _validationError ? colors.danger : colors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 17),
                  form,
                  if (_validationError || _saveError != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.circleAlert,
                            color: colors.danger,
                            size: 17,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _saveError ??
                                  tr(
                                    context,
                                    'Запись не сохранена. Исправьте ошибки в форме.',
                                    'Entry not saved. Fix the errors in the form.',
                                  ),
                              style: TextStyle(color: colors.ink, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(
                        tr(
                          context,
                          editing ? 'Сохранить изменения' : 'Сохранить пароль',
                          editing ? 'Save changes' : 'Save password',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      context,
                      'В списке пароль всегда скрыт.',
                      'Passwords are always hidden in the list.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileField(
    BuildContext context, {
    required String label,
    required Widget child,
    bool invalid = false,
  }) {
    final colors = VaultColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: invalid ? colors.danger : colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _mobileInputDecoration(
    BuildContext context, {
    required String hint,
  }) {
    final colors = VaultColors.of(context);
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(color: colors.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final colors = VaultColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  Widget _pair(bool sideBySide, Widget first, Widget second) => sideBySide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        )
      : Column(children: [first, const SizedBox(height: 16), second]);
}

class PasswordGeneratorPanel extends StatefulWidget {
  const PasswordGeneratorPanel({super.key});

  @override
  State<PasswordGeneratorPanel> createState() => _PasswordGeneratorPanelState();
}

class _PasswordGeneratorPanelState extends State<PasswordGeneratorPanel> {
  int _length = 16;
  bool _upper = true;
  bool _digits = true;
  bool _symbols = true;
  late String _value = _makePassword();

  String _makePassword() => generatePassword(
    PasswordOptions(
      length: _length,
      upper: _upper,
      digits: _digits,
      symbols: _symbols,
    ),
  );

  void _refresh() => setState(() => _value = _makePassword());

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return _mobileGenerator(context);
    }
    final colors = VaultColors.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Генератор пароля', 'Password generator'),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Закрыть', 'Close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 18),
              ),
            ],
          ),
          Text(
            tr(
              context,
              'Выберите длину и символы. Затем вставьте пароль в новую запись.',
              'Choose a length and characters, then use the password in your entry.',
            ),
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 22),
          Text(
            tr(context, 'СГЕНЕРИРОВАННЫЙ ПАРОЛЬ', 'GENERATED PASSWORD'),
            style: TextStyle(
              color: colors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _value,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Обновить', 'Regenerate'),
                  onPressed: _refresh,
                  icon: Icon(
                    LucideIcons.refreshCw,
                    color: colors.gold,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            children: [
              Text(
                tr(context, 'Длина пароля', 'Password length'),
                style: TextStyle(color: colors.ink, fontSize: 12),
              ),
              Text(
                tr(context, '$_length символов', '$_length characters'),
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _length.toDouble(),
            min: 8,
            max: 64,
            divisions: 56,
            activeColor: colors.gold,
            label: '$_length',
            onChanged: (value) => setState(() {
              _length = value.round();
              _value = _makePassword();
            }),
          ),
          _choice(
            context,
            tr(context, 'Заглавные буквы (A–Z)', 'Uppercase letters (A–Z)'),
            _upper,
            (value) => setState(() {
              _upper = value;
              _value = _makePassword();
            }),
          ),
          _choice(
            context,
            tr(context, 'Цифры (0–9)', 'Numbers (0–9)'),
            _digits,
            (value) => setState(() {
              _digits = value;
              _value = _makePassword();
            }),
          ),
          _choice(
            context,
            tr(
              context,
              'Специальные символы (!@#)',
              'Special characters (!@#)',
            ),
            _symbols,
            (value) => setState(() {
              _symbols = value;
              _value = _makePassword();
            }),
          ),
          const SizedBox(height: 18),
          if (MediaQuery.sizeOf(context).width < 600)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _value),
                icon: const Icon(LucideIcons.check, size: 16),
                label: Text(tr(context, 'Использовать пароль', 'Use password')),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(tr(context, 'Обновить', 'Regenerate')),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _value),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: Text(
                      tr(context, 'Использовать пароль', 'Use password'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _mobileGenerator(BuildContext context) {
    final colors = VaultColors.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Генератор пароля', 'Password generator'),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Закрыть', 'Close'),
                onPressed: () => Navigator.pop(context),
                icon: Icon(LucideIcons.x, color: colors.muted, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            tr(context, 'Сгенерированный пароль', 'Generated password'),
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 7),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 11, right: 3),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _value,
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Обновить', 'Regenerate'),
                  onPressed: _refresh,
                  icon: Icon(
                    LucideIcons.refreshCw,
                    color: colors.gold,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Длина пароля', 'Password length'),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                tr(context, '$_length символов', '$_length characters'),
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _length.toDouble(),
            min: 8,
            max: 64,
            divisions: 56,
            activeColor: colors.gold,
            onChanged: (value) => setState(() {
              _length = value.round();
              _value = _makePassword();
            }),
          ),
          _mobileChoice(
            context,
            tr(context, 'Заглавные буквы A–Z', 'Uppercase A–Z'),
            _upper,
            (value) => setState(() {
              _upper = value;
              _value = _makePassword();
            }),
          ),
          _mobileChoice(
            context,
            tr(context, 'Цифры 0–9', 'Numbers 0–9'),
            _digits,
            (value) => setState(() {
              _digits = value;
              _value = _makePassword();
            }),
          ),
          _mobileChoice(
            context,
            tr(context, 'Спецсимволы !@#', 'Special characters !@#'),
            _symbols,
            (value) => setState(() {
              _symbols = value;
              _value = _makePassword();
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _value),
              icon: const Icon(LucideIcons.check, size: 16),
              label: Text(tr(context, 'Использовать пароль', 'Use password')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileChoice(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colors = VaultColors.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: colors.ink, fontSize: 12),
              ),
            ),
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: value ? colors.goldSoft : Colors.transparent,
                border: Border.all(color: colors.gold),
                borderRadius: BorderRadius.circular(4),
              ),
              child: value
                  ? Icon(LucideIcons.check, color: colors.gold, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colors = VaultColors.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: colors.ink, fontSize: 12),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
              activeColor: colors.gold,
            ),
          ],
        ),
      ),
    );
  }
}
