// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui';

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/features/session/entries_controller.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/features/vault/nearby_transfer_dialog.dart';
import 'package:anchorkeep/features/vault/note_editor.dart';
import 'package:anchorkeep/features/vault/password_editor.dart';
import 'package:anchorkeep/shared/access_scaffold.dart';
import 'package:anchorkeep/shared/note_illustration.dart';
import 'package:anchorkeep/shared/status_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({required this.type, super.key});
  final EntryType type;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  final _search = TextEditingController();
  String? _selected;
  bool _reveal = false;
  bool _copyNotice = false;
  bool _copiedPassword = false;
  bool _editing = false;
  Entry? _editingEntry;
  String? _readingNoteId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get isPassword => widget.type == EntryType.password;

  Future<void> _edit([Entry? entry]) async {
    setState(() {
      _editing = true;
      _editingEntry = entry;
    });
  }

  Future<void> _nearby([Entry? note]) async {
    if (Theme.of(context).platform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).width < 600) {
      await _showMobileDialog<void>(NearbyTransferDialog(note: note));
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => NearbyTransferDialog(note: note),
      );
    }
  }

  Future<void> _delete(Entry entry) async {
    final yes = isPassword
        ? await _confirmPasswordDelete(entry)
        : await _confirmNoteDelete(entry);
    if (yes != true) return;
    try {
      await ref.read(entriesProvider.notifier).delete(entry.id);
      if (mounted) {
        setState(() {
          _selected = null;
          _readingNoteId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        _message(
          tr(
            context,
            'Не удалось удалить запись.',
            'Could not delete the entry.',
          ),
        );
      }
    }
  }

  Future<bool?> _confirmPasswordDelete(Entry entry) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    if (mobile) {
      return _showMobileDialog<bool>(
        Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _PasswordDeletePrompt(title: entry.title),
          ),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: _PasswordDeletePrompt(title: entry.title),
        ),
      ),
    );
  }

  Future<bool?> _confirmNoteDelete(Entry entry) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    if (mobile) {
      return _showMobileDialog<bool>(
        Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _NoteDeletePrompt(title: entry.title),
          ),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _NoteDeletePrompt(title: entry.title),
        ),
      ),
    );
  }

  Future<T?> _showMobileDialog<T>(Widget dialog) => showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .58),
    transitionDuration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Center(child: dialog),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: .96, end: 1.0).animate(animation),
        child: child,
      ),
    ),
  );

  Future<void> _copy(String value, {bool password = false}) async {
    await vaultClipboard.copy(value);
    if (mounted) {
      setState(() {
        _copyNotice = true;
        _copiedPassword = password;
      });
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    if (_editing) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 240),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        ),
        child: isPassword
            ? PasswordEditor(
                key: ValueKey(_editingEntry?.id ?? 'new-password'),
                entry: _editingEntry,
                onCancel: _cancelEdit,
                onSaved: _savedEdit,
              )
            : NoteEditor(
                key: ValueKey(_editingEntry?.id ?? 'new-note'),
                entry: _editingEntry,
                onCancel: _cancelEdit,
                onSaved: _savedEdit,
              ),
      );
    }
    final all =
        ref.watch(entriesProvider).where((e) => e.type == widget.type).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final query = _search.text.trim().toLowerCase();
    final visible = all
        .where(
          (e) =>
              e.title.toLowerCase().contains(query) ||
              (isPassword &&
                  ((e.fields['login'] ?? '').toLowerCase().contains(query) ||
                      (e.fields['url'] ?? '').toLowerCase().contains(query))),
        )
        .toList();
    final selected = all.where((e) => e.id == _selected).firstOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final shortScreen = MediaQuery.sizeOf(context).height < 650;
    final desktop = width >= 1050;
    final gutter = VaultLayout.gutter(width);
    final heading = tr(
      context,
      isPassword ? 'Пароли' : 'Заметки',
      isPassword ? 'Passwords' : 'Notes',
    );
    if (isPassword && width < 600) {
      return _mobilePasswords(
        visible: visible,
        selected: selected,
        query: query,
      );
    }
    if (!isPassword && width < 600) {
      return _mobileNotes(
        all: all,
        visible: visible,
        selected: selected,
        query: query,
      );
    }
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(LucideIcons.plus, size: 17),
          label: Text(
            tr(
              context,
              isPassword ? 'Добавить пароль' : 'Новая заметка',
              isPassword ? 'Add password' : 'New note',
            ),
          ),
        ),
      ],
    );
    final title = Text(
      heading,
      style: TextStyle(
        color: colors.ink,
        fontSize: VaultLayout.heading(width),
        fontWeight: FontWeight.w700,
      ),
    );
    final list = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            shortScreen ? 12 : 24,
            gutter,
            shortScreen ? 9 : 17,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPassword && !desktop)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        IconButton.outlined(
                          tooltip: tr(context, 'Заблокировать', 'Lock vault'),
                          onPressed: () =>
                              ref.read(vaultSessionProvider.notifier).lock(),
                          icon: const Icon(LucideIcons.lockKeyhole, size: 17),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tr(
                              context,
                              'Сейф открыт · хранится локально',
                              'Vault unlocked · stored locally',
                            ),
                            style: TextStyle(color: colors.muted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (all.isEmpty) ...[
                      SizedBox(height: shortScreen ? 6 : 12),
                      actions,
                    ],
                  ],
                )
              else if (!desktop)
                title
              else
                Row(
                  children: [
                    Expanded(child: title),
                    actions,
                  ],
                ),
              if (!isPassword || desktop) ...[
                const SizedBox(height: 5),
                Text(
                  tr(
                    context,
                    isPassword
                        ? 'Ваши учётные записи в одном защищённом месте.'
                        : '${_noteCount(all.length)} · только на устройстве',
                    isPassword
                        ? 'Your accounts in one secure place.'
                        : '${all.length} notes · on this device only',
                  ),
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
              ],
              SizedBox(height: shortScreen ? 12 : 20),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: tr(
                    context,
                    isPassword ? 'Поиск по названию или URL' : 'Поиск заметок',
                    isPassword ? 'Search title or URL' : 'Search notes',
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr(
                            context,
                            'Очистить поиск',
                            'Clear search',
                          ),
                          onPressed: () => setState(() => _search.clear()),
                          icon: const Icon(LucideIcons.x, size: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.line),
        if (isPassword && visible.isNotEmpty && !desktop)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
            child: Row(
              children: [
                Text(
                  tr(context, 'Сохранённые', 'Saved'),
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  tr(
                    context,
                    '${visible.length} записей',
                    '${visible.length} entries',
                  ),
                  style: TextStyle(color: colors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        if (!isPassword && visible.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 15, gutter, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(context, 'МОИ ЗАМЕТКИ', 'MY NOTES'),
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  searching: query.isNotEmpty,
                  isPassword: isPassword,
                  onAdd: () => _edit(),
                  onClear: () => setState(() => _search.clear()),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(gutter < 20 ? 12 : 16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    final active = selected?.id == entry.id;
                    return Material(
                      color: active ? colors.goldSoft : colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _selected = entry.id;
                          _reveal = false;
                          _copyNotice = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: active ? colors.gold : colors.line,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                  color: colors.goldSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPassword
                                      ? LucideIcons.keyRound
                                      : LucideIcons.notebookPen,
                                  color: colors.gold,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isPassword
                                          ? _passwordSummary(entry)
                                          : _dateTime(entry.createdAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                LucideIcons.chevronRight,
                                color: colors.muted,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (isPassword && visible.isNotEmpty && !desktop) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(tr(context, 'Добавить пароль', 'Add password')),
              ),
            ),
          ),
        ],
        if (!isPassword && visible.isNotEmpty && !desktop) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(tr(context, 'Добавить заметку', 'Add note')),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.shieldCheck, color: colors.gold, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Заметки зашифрованы и доступны только в открытом сейфе.',
                        'Notes are encrypted and available only in the unlocked vault.',
                      ),
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
    if (desktop &&
        !isPassword &&
        selected != null &&
        selected.id == _readingNoteId) {
      return _fullNotePage(selected);
    }
    if (desktop) {
      return _desktopCollection(
        all: all,
        visible: visible,
        selected: selected,
        query: query,
      );
    }
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: selected == null
          ? KeyedSubtree(key: const ValueKey('list'), child: list)
          : KeyedSubtree(
              key: ValueKey(selected.id),
              child: _detail(selected, mobile: true),
            ),
    );
  }

  void _cancelEdit() => setState(() {
    _editing = false;
    _editingEntry = null;
  });

  void _savedEdit(Entry saved) => setState(() {
    _selected =
        _editingEntry == null && MediaQuery.sizeOf(context).width >= 1050
        ? null
        : saved.id;
    _editing = false;
    _editingEntry = null;
    _copyNotice = false;
    _readingNoteId = null;
  });

  Widget _mobileNotes({
    required List<Entry> all,
    required List<Entry> visible,
    required Entry? selected,
    required String query,
  }) {
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      child: selected == null
          ? KeyedSubtree(
              key: const ValueKey('mobile-note-list'),
              child: _mobileNoteList(all: all, visible: visible, query: query),
            )
          : _readingNoteId == selected.id
          ? KeyedSubtree(
              key: ValueKey('mobile-note-full-${selected.id}'),
              child: _mobileFullNotePage(selected),
            )
          : KeyedSubtree(
              key: ValueKey('mobile-note-${selected.id}'),
              child: _mobileNoteDetail(selected),
            ),
    );
  }

  Widget _mobileNoteDetail(Entry entry) {
    final colors = VaultColors.of(context);
    final gutter = VaultLayout.gutter(MediaQuery.sizeOf(context).width);
    final note = entry.fields['text'] ?? '';
    return LayoutBuilder(
      builder: (context, bounds) {
        final cardHeight = (bounds.maxHeight * .45).clamp(260.0, 420.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bounds.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _mobilePasswordIconButton(
                          icon: LucideIcons.arrowLeft,
                          tooltip: tr(context, 'Назад', 'Back'),
                          onPressed: () => setState(() {
                            _selected = null;
                            _readingNoteId = null;
                            _copyNotice = false;
                          }),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr(context, 'Заметка', 'Note'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _mobileNoteDateTime(entry.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _mobilePasswordIconButton(
                          icon: LucideIcons.pencil,
                          tooltip: tr(context, 'Редактировать', 'Edit'),
                          onPressed: () => _edit(entry),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(minHeight: cardHeight),
                      padding: const EdgeInsets.fromLTRB(15, 12, 15, 18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: colors.line),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.alignLeft,
                                color: colors.gold,
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  tr(context, 'ТЕКСТ ЗАМЕТКИ', 'NOTE TEXT'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _mobileNoteAction(
                                icon: LucideIcons.copy,
                                tooltip: tr(context, 'Копировать', 'Copy'),
                                onPressed: note.isEmpty
                                    ? null
                                    : () => _copy(note),
                              ),
                              if (Theme.of(context).platform ==
                                  TargetPlatform.android) ...[
                                const SizedBox(width: 3),
                                _mobileNoteAction(
                                  icon: LucideIcons.radio,
                                  tooltip: tr(
                                    context,
                                    'Передать по NFC',
                                    'Share via NFC',
                                  ),
                                  onPressed: () => _nearby(entry),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(height: 1, color: colors.line),
                          const SizedBox(height: 17),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 145),
                            child: SelectableText(
                              note,
                              maxLines: 8,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_copyNotice) ...[
                      const SizedBox(height: 12),
                      StatusLabel(
                        message: tr(
                          context,
                          'Текст скопирован. Буфер очистится через 30 секунд.',
                          'Text copied. Clipboard clears in 30 seconds.',
                        ),
                        error: false,
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _readingNoteId = entry.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.gold,
                          side: BorderSide(
                            color: colors.gold.withValues(alpha: .35),
                          ),
                        ),
                        icon: const Icon(LucideIcons.expand, size: 16),
                        label: Text(
                          tr(context, 'Читать полностью', 'Read full note'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 48,
                      child: TextButton.icon(
                        onPressed: () => _delete(entry),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.danger,
                          backgroundColor: colors.danger.withValues(alpha: .16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        label: Text(
                          tr(context, 'Удалить заметку', 'Delete note'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileFullNotePage(Entry entry) {
    final colors = VaultColors.of(context);
    final gutter = VaultLayout.gutter(MediaQuery.sizeOf(context).width);
    final note = entry.fields['text'] ?? '';
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _mobilePasswordIconButton(
                icon: LucideIcons.arrowLeft,
                tooltip: tr(context, 'Назад к заметке', 'Back to note'),
                onPressed: () => setState(() => _readingNoteId = null),
              ),
              Expanded(
                child: Text(
                  tr(context, 'Полный просмотр', 'Full note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _mobilePasswordIconButton(
                icon: LucideIcons.copy,
                tooltip: tr(context, 'Копировать', 'Copy'),
                onPressed: note.isEmpty ? null : () => _copy(note),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            entry.title,
            style: TextStyle(
              color: colors.ink,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _mobileNoteDateTime(entry.createdAt),
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 240),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              note,
              style: TextStyle(color: colors.ink, fontSize: 15, height: 1.65),
            ),
          ),
          if (_copyNotice) ...[
            const SizedBox(height: 12),
            StatusLabel(
              message: tr(
                context,
                'Текст скопирован. Буфер очистится через 30 секунд.',
                'Text copied. Clipboard clears in 30 seconds.',
              ),
              error: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileNoteAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final colors = VaultColors.of(context);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: colors.muted, size: 17),
      ),
    );
  }

  Widget _mobileNoteList({
    required List<Entry> all,
    required List<Entry> visible,
    required String query,
  }) {
    final colors = VaultColors.of(context);
    final gutter = VaultLayout.gutter(MediaQuery.sizeOf(context).width);
    final searching = query.isNotEmpty;
    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const VaultBrand(compact: true),
                      const Spacer(),
                      const ThemeButton(subtle: true),
                      const SizedBox(width: 8),
                      _mobilePasswordIconButton(
                        icon: LucideIcons.lockKeyhole,
                        tooltip: tr(context, 'Заблокировать', 'Lock vault'),
                        onPressed: () =>
                            ref.read(vaultSessionProvider.notifier).lock(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    tr(context, 'Заметки', 'Notes'),
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (visible.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        '${_noteCount(all.length)} · только на устройстве',
                        '${all.length} ${all.length == 1 ? 'note' : 'notes'} · on this device only',
                      ),
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ],
                  SizedBox(height: visible.isNotEmpty ? 17 : 20),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: colors.ink, fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: tr(context, 'Поиск заметок', 'Search notes'),
                        hintStyle: TextStyle(color: colors.muted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        prefixIcon: const Icon(LucideIcons.search, size: 16),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 36,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 36,
                        ),
                        suffixIcon: searching
                            ? IconButton(
                                tooltip: tr(
                                  context,
                                  'Очистить поиск',
                                  'Clear search',
                                ),
                                onPressed: () =>
                                    setState(() => _search.clear()),
                                icon: const Icon(LucideIcons.x, size: 16),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: colors.goldSoft,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Icon(
                                  searching
                                      ? LucideIcons.search
                                      : LucideIcons.fileText,
                                  color: colors.gold,
                                  size: searching ? 27 : 36,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                searching
                                    ? tr(
                                        context,
                                        'Ничего не найдено',
                                        'No results',
                                      )
                                    : tr(
                                        context,
                                        'Пока нет заметок',
                                        'No notes yet',
                                      ),
                                style: TextStyle(
                                  color: colors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 13),
                              Text(
                                searching
                                    ? tr(
                                        context,
                                        'По запросу «${_search.text.trim()}» нет совпадений. Измените запрос или очистите поиск.',
                                        'No matches for “${_search.text.trim()}”. Change or clear the search.',
                                      )
                                    : tr(
                                        context,
                                        'Сохраняйте идеи и важные мысли. Они останутся только на этом устройстве.',
                                        'Save ideas and important thoughts. They stay on this device.',
                                      ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: searching
                                    ? OutlinedButton.icon(
                                        onPressed: () =>
                                            setState(() => _search.clear()),
                                        icon: const Icon(
                                          LucideIcons.x,
                                          size: 16,
                                        ),
                                        label: Text(
                                          tr(
                                            context,
                                            'Очистить поиск',
                                            'Clear search',
                                          ),
                                        ),
                                      )
                                    : FilledButton.icon(
                                        onPressed: () => _edit(),
                                        icon: const Icon(
                                          LucideIcons.plus,
                                          size: 16,
                                        ),
                                        label: Text(
                                          tr(
                                            context,
                                            'Создать первую заметку',
                                            'Add first note',
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 20),
                    Text(
                      tr(context, 'Мои заметки', 'My notes'),
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in visible) ...[
                      Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => setState(() {
                            _selected = entry.id;
                            _copyNotice = false;
                          }),
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.line),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.soft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    LucideIcons.fileText,
                                    color: colors.gold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _mobileNoteDateTime(entry.createdAt),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  LucideIcons.chevronRight,
                                  color: colors.muted,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(
                          tr(context, 'Добавить заметку', 'Add note'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _notePrivacyBanner(
                      colors,
                      tr(
                        context,
                        'Заметки зашифрованы и доступны только в открытом сейфе.',
                        'Notes are encrypted and available only in the unlocked vault.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _mobileNoteDateTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    final russian = Localizations.localeOf(context).languageCode == 'ru';
    final date = difference == 0
        ? (russian ? 'Сегодня' : 'Today')
        : difference == 1
        ? (russian ? 'Вчера' : 'Yesterday')
        : russian
        ? '${local.day} ${const ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'][local.month - 1]}${local.year == now.year ? '' : ' ${local.year}'}'
        : MaterialLocalizations.of(context).formatMediumDate(local);
    return '$date · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _mobilePasswords({
    required List<Entry> visible,
    required Entry? selected,
    required String query,
  }) {
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      child: selected == null
          ? KeyedSubtree(
              key: const ValueKey('mobile-password-list'),
              child: _mobilePasswordList(visible: visible, query: query),
            )
          : KeyedSubtree(
              key: ValueKey('mobile-password-${selected.id}'),
              child: _mobilePasswordDetail(selected),
            ),
    );
  }

  Widget _mobilePasswordList({
    required List<Entry> visible,
    required String query,
  }) {
    final colors = VaultColors.of(context);
    final gutter = VaultLayout.gutter(MediaQuery.sizeOf(context).width);
    final searching = query.isNotEmpty;
    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const VaultBrand(compact: true),
                      const Spacer(),
                      const ThemeButton(subtle: true),
                      const SizedBox(width: 8),
                      _mobilePasswordIconButton(
                        icon: LucideIcons.lockKeyhole,
                        tooltip: tr(context, 'Заблокировать', 'Lock vault'),
                        onPressed: () =>
                            ref.read(vaultSessionProvider.notifier).lock(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    tr(context, 'Пароли', 'Passwords'),
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (visible.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tr(
                              context,
                              'Сейф открыт · хранится локально',
                              'Vault unlocked · stored locally',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: visible.isNotEmpty ? 17 : 16),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: colors.ink, fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: tr(
                          context,
                          'Поиск по названию или URL',
                          'Search title or URL',
                        ),
                        hintStyle: TextStyle(color: colors.muted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        prefixIcon: const Icon(LucideIcons.search, size: 16),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 36,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 36,
                        ),
                        suffixIcon: searching
                            ? IconButton(
                                tooltip: tr(
                                  context,
                                  'Очистить поиск',
                                  'Clear search',
                                ),
                                onPressed: () =>
                                    setState(() => _search.clear()),
                                icon: const Icon(LucideIcons.x, size: 15),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: colors.goldSoft,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Icon(
                                  searching
                                      ? LucideIcons.search
                                      : LucideIcons.fileLock2,
                                  color: colors.gold,
                                  size: searching ? 26 : 35,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                searching
                                    ? tr(
                                        context,
                                        'Ничего не найдено',
                                        'No results',
                                      )
                                    : tr(
                                        context,
                                        'Пока нет паролей',
                                        'No passwords yet',
                                      ),
                                style: TextStyle(
                                  color: colors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 13),
                              Text(
                                searching
                                    ? tr(
                                        context,
                                        'По запросу «${_search.text.trim()}» нет совпадений. Попробуйте другое название или адрес.',
                                        'No matches for “${_search.text.trim()}”. Try another name or address.',
                                      )
                                    : tr(
                                        context,
                                        'Добавьте первую запись. Пароли сохраняются только на вашем устройстве.',
                                        'Add your first entry. Passwords stay on your device only.',
                                      ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: searching
                                    ? OutlinedButton.icon(
                                        onPressed: () =>
                                            setState(() => _search.clear()),
                                        icon: const Icon(
                                          LucideIcons.x,
                                          size: 15,
                                        ),
                                        label: Text(
                                          tr(
                                            context,
                                            'Очистить поиск',
                                            'Clear search',
                                          ),
                                        ),
                                      )
                                    : FilledButton.icon(
                                        onPressed: () => _edit(),
                                        icon: const Icon(
                                          LucideIcons.plus,
                                          size: 16,
                                        ),
                                        label: Text(
                                          tr(
                                            context,
                                            'Добавить первый пароль',
                                            'Add first password',
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, 'Сохранённые', 'Saved'),
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _passwordCount(visible.length),
                            style: TextStyle(color: colors.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final entry in visible) ...[
                      Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => setState(() {
                            _selected = entry.id;
                            _reveal = false;
                            _copyNotice = false;
                          }),
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.line),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.soft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    LucideIcons.keyRound,
                                    color: colors.gold,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _passwordSummary(entry),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  LucideIcons.chevronRight,
                                  color: colors.muted,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(
                          tr(context, 'Добавить пароль', 'Add password'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _passwordCount(int count) {
    if (Localizations.localeOf(context).languageCode != 'ru') {
      return '$count ${count == 1 ? 'entry' : 'entries'}';
    }
    final ending = count % 10 == 1 && count % 100 != 11
        ? 'запись'
        : count % 10 >= 2 &&
              count % 10 <= 4 &&
              (count % 100 < 12 || count % 100 > 14)
        ? 'записи'
        : 'записей';
    return '$count $ending';
  }

  Widget _mobilePasswordIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final colors = VaultColors.of(context);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, color: colors.muted, size: 18),
      ),
    );
  }

  Widget _mobilePasswordDetail(Entry entry) {
    final colors = VaultColors.of(context);
    final gutter = VaultLayout.gutter(MediaQuery.sizeOf(context).width);
    final password = entry.fields['password'] ?? '';
    final url = entry.fields['url'] ?? '';
    final note = entry.fields['note'] ?? '';
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _mobilePasswordIconButton(
                icon: LucideIcons.arrowLeft,
                tooltip: tr(context, 'Назад', 'Back'),
                onPressed: () => setState(() {
                  _selected = null;
                  _copyNotice = false;
                }),
              ),
              Expanded(
                child: Text(
                  tr(context, 'Запись пароля', 'Password entry'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _mobilePasswordIconButton(
                icon: LucideIcons.pencil,
                tooltip: tr(context, 'Редактировать', 'Edit'),
                onPressed: () => _edit(entry),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.goldSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(LucideIcons.keyRound, color: colors.gold, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (url.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _passwordSummary(entry).split(' · ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _mobilePasswordField(
            title: tr(context, 'Логин', 'Login'),
            value: entry.fields['login'] ?? '',
            onCopy: () => _copy(entry.fields['login'] ?? ''),
          ),
          _mobilePasswordField(
            title: tr(context, 'Пароль', 'Password'),
            value: _reveal ? password : '•••• •••• ••••',
            onCopy: () => _copy(password, password: true),
          ),
          _mobilePasswordField(
            title: tr(context, 'Сайт', 'Website'),
            value: url,
            highlight: true,
            onCopy: () => _copy(url),
          ),
          if (note.isNotEmpty) ...[
            Text(
              tr(context, 'ЗАМЕТКА', 'NOTE'),
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              note,
              style: TextStyle(color: colors.ink, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 27),
          ] else
            const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _reveal = !_reveal),
                    icon: Icon(
                      _reveal ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 16,
                    ),
                    label: Text(
                      tr(
                        context,
                        _reveal ? 'Скрыть' : 'Показать',
                        _reveal ? 'Hide' : 'Show',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: password.isEmpty
                        ? null
                        : () => _copy(password, password: true),
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: Text(tr(context, 'Скопировать', 'Copy')),
                  ),
                ),
              ),
            ],
          ),
          if (_copyNotice) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.circleCheck,
                    color: colors.success,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        _copiedPassword
                            ? 'Пароль скопирован.\nБуфер очистится через 30 секунд.'
                            : 'Скопировано.\nБуфер очистится через 30 секунд.',
                        _copiedPassword
                            ? 'Password copied.\nClipboard clears in 30 seconds.'
                            : 'Copied.\nClipboard clears in 30 seconds.',
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
          ],
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              onPressed: () => _delete(entry),
              style: TextButton.styleFrom(
                foregroundColor: colors.danger,
                backgroundColor: colors.danger.withValues(alpha: .16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.trash2, size: 15),
              label: Text(tr(context, 'Удалить запись', 'Delete entry')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobilePasswordField({
    required String title,
    required String value,
    required VoidCallback onCopy,
    bool highlight = false,
  }) {
    final colors = VaultColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value.isEmpty ? '—' : value,
                    maxLines: 1,
                    style: TextStyle(
                      color: highlight ? colors.gold : colors.ink,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Копировать', 'Copy'),
                  onPressed: value.isEmpty ? null : onCopy,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(LucideIcons.copy, color: colors.muted, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _noteCount(int count) {
    final russian = Localizations.localeOf(context).languageCode == 'ru';
    if (!russian) return '$count notes';
    final ending = count % 10 == 1 && count % 100 != 11
        ? 'заметка'
        : count % 10 >= 2 &&
              count % 10 <= 4 &&
              (count % 100 < 12 || count % 100 > 14)
        ? 'заметки'
        : 'заметок';
    return '$count $ending';
  }

  Widget _desktopCollection({
    required List<Entry> all,
    required List<Entry> visible,
    required Entry? selected,
    required String query,
  }) {
    final colors = VaultColors.of(context);
    return LayoutBuilder(
      builder: (context, bounds) {
        final gutter = VaultLayout.gutter(bounds.maxWidth);
        final selectedVisible = visible
            .where((entry) => entry.id == selected?.id)
            .firstOrNull;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                context,
                                isPassword ? 'Пароли' : 'Заметки',
                                isPassword ? 'Passwords' : 'Notes',
                              ),
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: VaultLayout.heading(bounds.maxWidth),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(
                                context,
                                isPassword
                                    ? 'Ваши учётные записи в одном защищённом месте.'
                                    : '${_noteCount(all.length)} · локальное хранение без аккаунта',
                                isPassword
                                    ? 'Your accounts in one secure place.'
                                    : '${all.length} notes · stored locally without an account',
                              ),
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(
                          tr(
                            context,
                            isPassword ? 'Добавить пароль' : 'Новая заметка',
                            isPassword ? 'Add password' : 'New note',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isPassword) ...[
                    const SizedBox(height: 17),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(
                                    context,
                                    'ВАШЕ ЛИЧНОЕ ПРОСТРАНСТВО',
                                    'YOUR PRIVATE SPACE',
                                  ),
                                  style: TextStyle(
                                    color: colors.gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tr(
                                    context,
                                    'Мысли и идеи под вашим контролем',
                                    'Your thoughts stay in your control',
                                  ),
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tr(
                                    context,
                                    'Сохраняются только в зашифрованном сейфе на компьютере.',
                                    'Saved only in the encrypted vault on this computer.',
                                  ),
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const NoteIllustration(compact: true),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: tr(
                        context,
                        isPassword
                            ? 'Поиск по названию или URL'
                            : 'Поиск заметок',
                        isPassword ? 'Search title or URL' : 'Search notes',
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr(
                                context,
                                'Очистить поиск',
                                'Clear search',
                              ),
                              onPressed: () => setState(() => _search.clear()),
                              icon: const Icon(LucideIcons.x, size: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.line),
            if (visible.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 15, gutter, 9),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(
                      context,
                      isPassword ? 'МОИ ПАРОЛИ' : 'МОИ ЗАМЕТКИ',
                      isPassword ? 'MY PASSWORDS' : 'MY NOTES',
                    ),
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(
                      searching: query.isNotEmpty,
                      isPassword: isPassword,
                      onAdd: () => _edit(),
                      onClear: () => setState(() => _search.clear()),
                    )
                  : Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: selectedVisible == null ? 1 : 2,
                            child: selectedVisible == null
                                ? GridView.builder(
                                    itemCount: visible.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          mainAxisExtent: 78,
                                        ),
                                    itemBuilder: (context, index) =>
                                        _desktopTile(
                                          visible[index],
                                          selected: false,
                                        ),
                                  )
                                : ListView.separated(
                                    itemCount: visible.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 9),
                                    itemBuilder: (context, index) =>
                                        _desktopTile(
                                          visible[index],
                                          selected:
                                              visible[index].id ==
                                              selectedVisible.id,
                                        ),
                                  ),
                          ),
                          if (selectedVisible != null) ...[
                            const SizedBox(width: 14),
                            Expanded(flex: 3, child: _detail(selectedVisible)),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _desktopTile(Entry entry, {required bool selected}) {
    final colors = VaultColors.of(context);
    return Material(
      color: selected ? colors.goldSoft : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() {
          _selected = entry.id;
          _reveal = false;
          _copyNotice = false;
          _readingNoteId = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? colors.gold : colors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.goldSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isPassword ? LucideIcons.keyRound : LucideIcons.notebookPen,
                  size: 18,
                  color: colors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPassword
                          ? _passwordSummary(entry)
                          : _dateTime(entry.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(LucideIcons.chevronRight, size: 16, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullNotePage(Entry entry) {
    final colors = VaultColors.of(context);
    final gutter = VaultLayout.gutter(MediaQuery.sizeOf(context).width);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 12),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _readingNoteId = null),
                icon: const Icon(LucideIcons.arrowLeft, size: 17),
                label: Text(tr(context, 'К заметкам', 'Back to notes')),
              ),
              const Spacer(),
              Text(
                tr(context, 'Полный просмотр', 'Full note'),
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
            child: _detail(entry, fullPage: true),
          ),
        ),
      ],
    );
  }

  Widget _detail(Entry entry, {bool mobile = false, bool fullPage = false}) {
    if (isPassword) return _passwordDetail(entry, mobile: mobile);
    final colors = VaultColors.of(context);
    final note = entry.fields['text'] ?? '';
    final width = MediaQuery.sizeOf(context).width;
    final gutter = VaultLayout.gutter(width);
    final compactActions = mobile && width < 390;
    final actions = <Widget>[
      if (!mobile && !fullPage)
        IconButton(
          tooltip: tr(context, 'Открыть полностью', 'Open full note'),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _readingNoteId = entry.id),
          icon: const Icon(LucideIcons.eye, size: 18),
        ),
      IconButton(
        tooltip: tr(context, 'Копировать', 'Copy'),
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        onPressed: note.isEmpty ? null : () => _copy(note),
        icon: const Icon(LucideIcons.copy, size: 18),
      ),
      IconButton(
        tooltip: tr(context, 'Редактировать', 'Edit'),
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        onPressed: () => _edit(entry),
        icon: const Icon(LucideIcons.pencil, size: 18),
      ),
      IconButton(
        tooltip: tr(context, 'Удалить заметку', 'Delete note'),
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        onPressed: () => _delete(entry),
        icon: Icon(LucideIcons.trash2, size: 18, color: colors.danger),
      ),
      if (Platform.isAndroid)
        IconButton(
          tooltip: tr(context, 'Передать по NFC', 'Share via NFC'),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: () => _nearby(entry),
          icon: const Icon(LucideIcons.radio, size: 18),
        ),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(mobile ? gutter : 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(mobile ? 17 : 21),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (mobile) ...[
                      IconButton(
                        tooltip: tr(context, 'Назад', 'Back'),
                        onPressed: () => setState(() {
                          _selected = null;
                          _copyNotice = false;
                        }),
                        icon: const Icon(LucideIcons.arrowLeft, size: 19),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.goldSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.notebookPen,
                        color: colors.gold,
                        size: 19,
                      ),
                    ),
                    if (!mobile) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tr(context, 'Создано ', 'Created ') +
                                  _dateTime(entry.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (!compactActions) ...actions,
                  ],
                ),
                if (compactActions)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                  ),
                if (mobile) ...[
                  const SizedBox(height: 19),
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: mobile ? 21 : 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(context, 'Создано ', 'Created ') +
                        _dateTime(entry.createdAt),
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 18),
                Divider(height: 1, color: colors.line),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(LucideIcons.alignLeft, color: colors.gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'ТЕКСТ ЗАМЕТКИ', 'NOTE TEXT'),
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 150),
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: colors.canvas,
                    border: Border.all(color: colors.line),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: SelectableText(
                    note,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ),
                if (_copyNotice) ...[
                  const SizedBox(height: 12),
                  StatusLabel(
                    message: tr(
                      context,
                      'Текст скопирован. Буфер очистится через 30 секунд.',
                      'Text copied. Clipboard clears in 30 seconds.',
                    ),
                    error: false,
                  ),
                ],
                const SizedBox(height: 15),
                _notePrivacyBanner(
                  colors,
                  tr(
                    context,
                    'Зашифровано локально и доступно только вам.',
                    'Encrypted locally and available only to you.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notePrivacyBanner(VaultColors colors, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.soft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.shieldCheck, color: colors.gold, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: colors.muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  Widget _passwordDetail(Entry entry, {required bool mobile}) {
    final colors = VaultColors.of(context);
    final password = entry.fields['password'] ?? '';
    final url = entry.fields['url'] ?? '';
    final note = entry.fields['note'] ?? '';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mobile) ...[
          Row(
            children: [
              IconButton(
                tooltip: tr(context, 'Назад', 'Back'),
                onPressed: () => setState(() {
                  _selected = null;
                  _copyNotice = false;
                }),
                icon: const Icon(LucideIcons.arrowLeft, size: 19),
              ),
              Expanded(
                child: Text(
                  tr(context, 'Запись пароля', 'Password entry'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Редактировать', 'Edit'),
                onPressed: () => _edit(entry),
                icon: const Icon(LucideIcons.pencil, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.goldSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(LucideIcons.keyRound, color: colors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: mobile ? 18 : 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (url.isNotEmpty)
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (!mobile) ...[
              IconButton(
                tooltip: tr(context, 'Редактировать', 'Edit'),
                onPressed: () => _edit(entry),
                icon: const Icon(LucideIcons.pencil, size: 18),
              ),
              IconButton(
                tooltip: tr(context, 'Удалить', 'Delete'),
                onPressed: () => _delete(entry),
                icon: Icon(LucideIcons.trash2, color: colors.danger, size: 18),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        if (mobile) ...[
          _field(
            tr(context, 'Логин', 'Login'),
            entry.fields['login'] ?? '',
            copy: true,
          ),
          _field(
            tr(context, 'Пароль', 'Password'),
            _reveal ? password : '••••••••••••',
            copyValue: password,
            reveal: true,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  tr(context, 'Логин', 'Login'),
                  entry.fields['login'] ?? '',
                  copy: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  tr(context, 'Пароль', 'Password'),
                  _reveal ? password : '••••••••••••',
                  copyValue: password,
                  reveal: true,
                ),
              ),
            ],
          ),
        _field(tr(context, 'Сайт', 'Website'), url, copy: true),
        if (note.isNotEmpty) ...[
          Text(
            tr(context, 'ЗАМЕТКА', 'NOTE'),
            style: TextStyle(
              color: colors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            note,
            style: TextStyle(color: colors.ink, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
        ],
        if (mobile) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final show = OutlinedButton.icon(
                onPressed: () => setState(() => _reveal = !_reveal),
                icon: Icon(
                  _reveal ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 16,
                ),
                label: Text(
                  tr(
                    context,
                    _reveal ? 'Скрыть' : 'Показать',
                    _reveal ? 'Hide' : 'Show',
                  ),
                ),
              );
              final copy = FilledButton.icon(
                onPressed: password.isEmpty
                    ? null
                    : () => _copy(password, password: true),
                icon: const Icon(LucideIcons.copy, size: 16),
                label: Text(tr(context, 'Скопировать', 'Copy')),
              );
              if (constraints.maxWidth < 350) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: show),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: copy),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: show),
                  const SizedBox(width: 8),
                  Expanded(child: copy),
                ],
              );
            },
          ),
          const SizedBox(height: 13),
        ],
        StatusLabel(
          message: _copyNotice
              ? tr(
                  context,
                  _copiedPassword
                      ? 'Пароль скопирован. Буфер очистится через 30 секунд.'
                      : 'Скопировано. Буфер очистится через 30 секунд.',
                  _copiedPassword
                      ? 'Password copied. Clipboard clears in 30 seconds.'
                      : 'Copied. Clipboard clears in 30 seconds.',
                )
              : null,
          error: false,
        ),
        if (mobile) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.danger,
                backgroundColor: colors.danger.withValues(alpha: .08),
                side: BorderSide(color: colors.danger.withValues(alpha: .18)),
              ),
              onPressed: () => _delete(entry),
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: Text(tr(context, 'Удалить запись', 'Delete entry')),
            ),
          ),
        ],
      ],
    );
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        VaultLayout.gutter(MediaQuery.sizeOf(context).width),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: mobile
              ? details
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: details,
                ),
        ),
      ),
    );
  }

  Widget _field(
    String title,
    String value, {
    bool copy = false,
    bool reveal = false,
    String? copyValue,
  }) {
    final colors = VaultColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(color: colors.ink, fontSize: 14),
                  ),
                ),
                if (reveal)
                  IconButton(
                    onPressed: () => setState(() => _reveal = !_reveal),
                    icon: Icon(
                      _reveal ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                    ),
                  ),
                if (copy || reveal)
                  IconButton(
                    tooltip: tr(context, 'Копировать', 'Copy'),
                    onPressed: (copyValue ?? value).isEmpty
                        ? null
                        : () => _copy(copyValue ?? value, password: reveal),
                    icon: const Icon(LucideIcons.copy, size: 18),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _passwordSummary(Entry entry) {
    final url = entry.fields['url'] ?? '';
    final login = entry.fields['login'] ?? '';
    var displayUrl = url
        .trim()
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    if (displayUrl.endsWith('/')) {
      displayUrl = displayUrl.substring(0, displayUrl.length - 1);
    }
    return [displayUrl, login].where((part) => part.isNotEmpty).join(' · ');
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

class _PasswordDeletePrompt extends StatelessWidget {
  const _PasswordDeletePrompt({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.danger.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(LucideIcons.trash2, color: colors.danger, size: 24),
          ),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: tr(context, 'Удалить пароль ', 'Delete ')),
                TextSpan(
                  text: title,
                  style: TextStyle(color: colors.gold),
                ),
                TextSpan(text: tr(context, '?', ' password?')),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Запись будет удалена из локального сейфа. Это действие нельзя отменить.',
              'The entry will be removed from your local vault. This cannot be undone.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr(context, 'Отмена', 'Cancel')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.danger.withValues(alpha: .12),
                    foregroundColor: colors.danger,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: Text(tr(context, 'Удалить', 'Delete')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            tr(
              context,
              'Удалённую запись нельзя восстановить.',
              'Deleted entries cannot be recovered.',
            ),
            style: TextStyle(color: colors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _NoteDeletePrompt extends StatelessWidget {
  const _NoteDeletePrompt({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.danger.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(LucideIcons.trash2, color: colors.danger, size: 23),
          ),
          const SizedBox(height: 17),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: tr(context, 'Удалить заметку ', 'Delete note ')),
                TextSpan(
                  text: title,
                  style: TextStyle(color: colors.gold),
                ),
                const TextSpan(text: '?'),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            tr(
              context,
              'Запись будет удалена из локального сейфа. Это действие нельзя отменить.',
              'This note will be removed from the local vault. This cannot be undone.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr(context, 'Отмена', 'Cancel')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.danger.withValues(alpha: .12),
                    foregroundColor: colors.danger,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: Text(tr(context, 'Удалить', 'Delete')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            tr(
              context,
              'Удалённую заметку нельзя восстановить.',
              'Deleted notes cannot be recovered.',
            ),
            style: TextStyle(color: colors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.isPassword,
    required this.onAdd,
    required this.onClear,
  });
  final bool searching;
  final bool isPassword;
  final VoidCallback onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.goldSoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                searching
                    ? LucideIcons.searchX
                    : isPassword
                    ? LucideIcons.lockKeyhole
                    : LucideIcons.notebookPen,
                color: colors.gold,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              searching
                  ? tr(context, 'Ничего не найдено', 'No results')
                  : tr(
                      context,
                      isPassword ? 'Пока нет паролей' : 'Пока нет заметок',
                      isPassword ? 'No passwords yet' : 'No notes yet',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              searching
                  ? tr(
                      context,
                      isPassword ? 'Попробуйте другой запрос.' : 'По запросу совпадений нет. Измените запрос или очистите поиск.',
                      isPassword
                          ? 'Try another search.'
                          : 'No matching notes. Change or clear your search.',
                    )
                  : tr(
                      context,
                      isPassword ? 'Добавьте первую запись в защищённый сейф.' : 'Сохраняйте идеи и важные мысли. Они останутся только на этом устройстве.',
                      isPassword ? 'Add your first entry to the secure vault.' : 'Save ideas and important thoughts. They stay on this device.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (searching)
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 16),
                label: Text(tr(context, 'Очистить поиск', 'Clear search')),
              )
            else
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(
                  tr(
                    context,
                    isPassword
                        ? 'Добавить первый пароль'
                        : 'Добавить первую заметку',
                    isPassword ? 'Add first password' : 'Add first note',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
