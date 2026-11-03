// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/features/session/entries_controller.dart';
import 'package:anchorkeep/shared/note_illustration.dart';
import 'package:anchorkeep/shared/status_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class NoteEditor extends ConsumerStatefulWidget {
  const NoteEditor({
    required this.onCancel,
    required this.onSaved,
    this.entry,
    super.key,
  });

  final Entry? entry;
  final VoidCallback onCancel;
  final ValueChanged<Entry> onSaved;

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _text = TextEditingController(
    text: widget.entry?.fields['text'] ?? '',
  );
  bool _saving = false;
  bool _invalid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(_updateCount);
  }

  void _updateCount() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_updateCount);
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _saving = true;
      _invalid = false;
      _error = null;
    });
    try {
      final store = ref.read(entriesProvider.notifier);
      final fields = {'text': _text.text.trim()};
      final saved = widget.entry == null
          ? await store.add(EntryType.note, _title.text.trim(), fields)
          : await store.update(
              widget.entry!.id,
              title: _title.text.trim(),
              fields: fields,
            );
      if (mounted) widget.onSaved(saved);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            'Не удалось сохранить заметку. Попробуйте ещё раз.',
            'Could not save the note. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final colors = VaultColors.of(context);
      final desktop = bounds.maxWidth >= 850;
      final mobile = bounds.maxWidth < 600;
      final editing = widget.entry != null;
      final gutter = VaultLayout.gutter(bounds.maxWidth);
      if (mobile) {
        return _mobileEditor(
          context,
          availableHeight: bounds.maxHeight,
          gutter: gutter,
          editing: editing,
        );
      }
      final form = Form(
        key: _form,
        onChanged: () {
          if (_invalid && (_form.currentState?.validate() ?? false)) {
            setState(() => _invalid = false);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (desktop) ...[
              Text(
                tr(context, 'СОДЕРЖИМОЕ ЗАМЕТКИ', 'NOTE CONTENT'),
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 15),
            ],
            _label(context, tr(context, 'Название', 'Title')),
            const SizedBox(height: 7),
            TextFormField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'Введите название заметки',
                  'Enter note title',
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? tr(
                      context,
                      'Укажите название заметки.',
                      'Enter a note title.',
                    )
                  : null,
            ),
            const SizedBox(height: 17),
            _label(context, tr(context, 'Текст заметки', 'Note text')),
            const SizedBox(height: 7),
            TextFormField(
              controller: _text,
              minLines: mobile ? 7 : 6,
              maxLines: mobile ? 9 : 8,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'Начните писать заметку здесь.\n\nТекст будет доступен только внутри разблокированного сейфа.',
                  'Start writing here.\n\nText is available only inside the unlocked vault.',
                ),
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? tr(context, 'Введите текст заметки.', 'Enter note text.')
                  : null,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Только локально', 'Local only'),
                    style: TextStyle(color: colors.muted, fontSize: 10),
                  ),
                ),
                Text(
                  tr(
                    context,
                    '${_text.text.characters.length} символов',
                    '${_text.text.characters.length} characters',
                  ),
                  style: TextStyle(color: colors.muted, fontSize: 10),
                ),
              ],
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
                  Icon(LucideIcons.shieldCheck, size: 17, color: colors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Запись будет доступна только после разблокировки сейфа.',
                        'Available only after unlocking the vault.',
                      ),
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            if (_invalid || _error != null) ...[
              const SizedBox(height: 12),
              StatusLabel(
                message:
                    _error ??
                    tr(
                      context,
                      'Заполните название и текст заметки.',
                      'Enter a title and note text.',
                    ),
              ),
            ],
            if (mobile) ...[
              const SizedBox(height: 21),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: Text(
                    tr(
                      context,
                      editing ? 'Сохранить изменения' : 'Сохранить заметку',
                      editing ? 'Save changes' : 'Save note',
                    ),
                  ),
                ),
              ),
            ] else if (!desktop) ...[
              const SizedBox(height: 21),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : widget.onCancel,
                    child: Text(tr(context, 'Отмена', 'Cancel')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: Text(
                      tr(
                        context,
                        editing ? 'Сохранить изменения' : 'Сохранить заметку',
                        editing ? 'Save changes' : 'Save note',
                      ),
                    ),
                  ),
                ],
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
                if (mobile) ...[
                  Row(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Назад', 'Back'),
                        onPressed: widget.onCancel,
                        icon: const Icon(LucideIcons.arrowLeft, size: 19),
                      ),
                      Expanded(
                        child: Text(
                          tr(
                            context,
                            editing ? 'Редактирование' : 'Новая заметка',
                            editing ? 'Edit' : 'New note',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  tr(
                    context,
                    editing
                        ? (mobile
                              ? 'Изменить заметку'
                              : 'Редактировать заметку')
                        : 'Создать заметку',
                    editing ? 'Edit note' : 'Create note',
                  ),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: mobile ? 22 : 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tr(
                    context,
                    editing
                        ? 'Обновите содержимое локальной записи.'
                        : 'Ваши идеи сохранятся только в зашифрованном сейфе.',
                    editing
                        ? 'Update this local note.'
                        : 'Your ideas stay in the encrypted vault.',
                  ),
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                const SizedBox(height: 22),
                if (desktop)
                  Column(
                    children: [
                      SizedBox(
                        height: 540,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _card(
                                context,
                                SingleChildScrollView(child: form),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: _artPanel(context)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
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
                                            : 'Сохранить заметку',
                                        editing ? 'Save changes' : 'Save note',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                        ],
                      ),
                    ],
                  )
                else
                  _card(context, form),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _mobileEditor(
    BuildContext context, {
    required double availableHeight,
    required double gutter,
    required bool editing,
  }) {
    final colors = VaultColors.of(context);
    final titleInvalid = _invalid && _title.text.trim().isEmpty;
    final textInvalid = _invalid && _text.text.trim().isEmpty;
    final noteHeight = availableHeight.isFinite
        ? (availableHeight * .40).clamp(190.0, 260.0)
        : 220.0;
    final form = Form(
      key: _form,
      onChanged: () {
        if (_invalid && (_form.currentState?.validate() ?? false)) {
          setState(() => _invalid = false);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Название', 'Title'),
            style: TextStyle(
              color: titleInvalid ? colors.danger : colors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _title,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: colors.ink, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: tr(context, 'Введите название', 'Enter a title'),
              hintStyle: TextStyle(color: colors.muted, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? tr(
                    context,
                    'Укажите название заметки.',
                    'Enter a note title.',
                  )
                : null,
          ),
          const SizedBox(height: 15),
          Text(
            tr(context, 'Текст заметки', 'Note text'),
            style: TextStyle(
              color: textInvalid ? colors.danger : colors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: noteHeight,
            child: TextFormField(
              controller: _text,
              expands: true,
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(color: colors.ink, fontSize: 14, height: 1.45),
              decoration: InputDecoration(
                isDense: true,
                hintText: tr(
                  context,
                  'Напишите мысль, идею или важную информацию.\n\nТекст будет доступен только внутри разблокированного сейфа.',
                  'Write down a thought, idea, or important information.\n\nText is available only inside the unlocked vault.',
                ),
                hintStyle: TextStyle(
                  color: colors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? tr(context, 'Введите текст заметки.', 'Enter note text.')
                  : null,
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: availableHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 15),
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
                          editing ? 'Редактирование' : 'Новая заметка',
                          editing ? 'Editing' : 'New note',
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
                const SizedBox(height: 18),
                Text(
                  _invalid
                      ? tr(context, 'Проверьте поля', 'Check the fields')
                      : tr(
                          context,
                          editing ? 'Изменить заметку' : 'Создать заметку',
                          editing ? 'Edit note' : 'Create note',
                        ),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _invalid
                      ? tr(
                          context,
                          'Заполните название и текст, чтобы сохранить.',
                          'Enter a title and text to save.',
                        )
                      : tr(
                          context,
                          editing
                              ? 'Изменения будут зашифрованы локально.'
                              : 'Данные останутся только на этом устройстве.',
                          editing
                              ? 'Changes are encrypted locally.'
                              : 'Your data stays on this device only.',
                        ),
                  style: TextStyle(
                    color: _invalid ? colors.danger : colors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                form,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Только локально', 'Local only'),
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                    ),
                    Text(
                      tr(
                        context,
                        '${_text.text.characters.length} символов',
                        '${_text.text.characters.length} characters',
                      ),
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ],
                ),
                if (_invalid || _error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: .12),
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
                            _error ??
                                tr(
                                  context,
                                  'Заметка не сохранена. Проверьте поля.',
                                  'Note not saved. Check the fields.',
                                ),
                            style: TextStyle(color: colors.ink, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: Text(
                      tr(
                        context,
                        editing ? 'Сохранить изменения' : 'Сохранить заметку',
                        editing ? 'Save changes' : 'Save note',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    final colors = VaultColors.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      padding: mobile ? EdgeInsets.zero : const EdgeInsets.all(20),
      decoration: mobile
          ? null
          : BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(14),
            ),
      child: child,
    );
  }

  Widget _artPanel(BuildContext context) {
    final colors = VaultColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const NoteIllustration(),
          const SizedBox(height: 24),
          for (final message in [
            tr(context, 'Шифрование на устройстве', 'Encrypted on device'),
            tr(
              context,
              'Бэкап через файл-архив',
              'Backup with an archive file',
            ),
            tr(context, 'Доступ по мастер-паролю', 'Master password access'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(LucideIcons.check, color: colors.gold, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String value) => Text(
    value,
    style: TextStyle(
      color: VaultColors.of(context).muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );
}
