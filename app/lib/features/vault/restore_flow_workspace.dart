// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/solana/backup_verification.dart';
import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:anchorkeep/core/solana/vault_keypair.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:anchorkeep/core/vault/backup_import.dart';
import 'package:anchorkeep/core/vault/backup_import_picker.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/features/vault/backup_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:solana/solana.dart';

enum _RestoreStep { pick, password, confirm }

class VaultRestoreFlow extends ConsumerStatefulWidget {
  const VaultRestoreFlow({
    super.key,
    this.standalone = false,
    this.onCancel,
    this.initialBytes,
    this.fetchRecord,
    this.unlockBackup,
    this.currentHeader,
  });
  final bool standalone;
  final VoidCallback? onCancel;
  final Uint8List? initialBytes;
  final FetchVaultRecord? fetchRecord;
  final Future<VaultSession> Function(Uint8List bytes, String password)?
  unlockBackup;

  /// Заголовок сейфа на устройстве (в тестах подменяется; по умолчанию —
  /// файл на диске, читается без пароля).
  final Future<VaultHeader?> Function()? currentHeader;

  @override
  ConsumerState<VaultRestoreFlow> createState() => _VaultRestoreFlowState();
}

class _VaultRestoreFlowState extends ConsumerState<VaultRestoreFlow> {
  final _password = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;
  VaultHeader? _header;
  VaultHeader? _current;
  _RestoreStep _step = _RestoreStep.pick;
  AnchorStatus? _status;
  ImportKind? _kind;
  bool _busy = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bytes = widget.initialBytes;
    if (bytes != null) {
      try {
        _header = previewBackup(bytes);
        _bytes = bytes;
        _step = _RestoreStep.password;
      } catch (_) {
        _error = 'Invalid backup file';
      }
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == _RestoreStep.confirm) {
      setState(() {
        _step = _RestoreStep.password;
        _error = null;
      });
    } else if (_step == _RestoreStep.password) {
      setState(() {
        _step = _RestoreStep.pick;
        _error = null;
        _bytes = null;
        _fileName = null;
        _header = null;
        _password.clear();
      });
    } else if (widget.standalone) {
      context.go('/welcome');
    } else {
      widget.onCancel?.call();
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final picked = await pickBackupFile();
      if (picked == null) return;
      final header = previewBackup(picked.bytes);
      if (mounted) {
        setState(() {
          _bytes = picked.bytes;
          _fileName = picked.name;
          _header = header;
          _step = _RestoreStep.password;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            'Выбранный файл не является допустимой копией сейфа.',
            'The selected file is not a valid vault backup.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (_bytes == null || _password.text.isEmpty || _busy) {
      if (_password.text.isEmpty) {
        setState(
          () => _error = tr(
            context,
            'Введите мастер-пароль копии.',
            'Enter the backup master password.',
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
      final preview =
          await (widget.unlockBackup?.call(_bytes!, _password.text) ??
              unlockVault(_bytes!, _password.text));
      // Сессия есть только у открытого сейфа; на экране входа сравниваем
      // с файлом на диске, иначе перезапись выглядит как «создание».
      final current =
          ref.read(vaultSessionProvider)?.header ??
          await (widget.currentHeader?.call() ?? _headerOnDisk());
      AnchorStatus status;
      try {
        final owner = solanaOwner(preview.payload);
        final registry = VaultRegistry(
          SolanaClient(
            rpcUrl: SolanaConfig.rpcUrl,
            websocketUrl: SolanaConfig.websocketUrl,
          ),
        );
        status = await verifyVaultFile(
          fileBytes: _bytes!,
          owner: owner,
          fetch: widget.fetchRecord ?? registry.fetchRecord,
        );
      } finally {
        preview.close();
      }
      if (mounted) {
        setState(() {
          _status = status;
          _current = current;
          _kind = classifyImport(_header!, current);
          _step = _RestoreStep.confirm;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            'Не удалось открыть копию. Проверьте пароль и файл.',
            'Could not open the backup. Check the password and file.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<VaultHeader?> _headerOnDisk() async =>
      readCurrentVaultHeader(await ref.read(vaultPathProvider.future));

  /// Что будет с сейфом на устройстве: каждый случай говорит об этом прямо,
  /// особенно когда бэкап старее и свежие записи пропадут.
  String _replaceMessage(BuildContext context) {
    final backupVersion = _header?.revision ?? 0;
    final currentVersion = _current?.revision ?? 0;
    return switch (_kind) {
      ImportKind.newVault => tr(
        context,
        'На устройстве будет создан сейф из выбранной копии.',
        'A vault will be created from this backup.',
      ),
      ImportKind.sameVaultOlder => tr(
        context,
        'Эта копия старее сейфа на устройстве (версия $backupVersion против $currentVersion). Записи, добавленные позже, будут потеряны. Отменить нельзя.',
        'This backup is older than the vault on this device (version $backupVersion vs $currentVersion). Entries added later will be lost. This cannot be undone.',
      ),
      ImportKind.differentVault => tr(
        context,
        'Это копия другого сейфа: сейф на устройстве будет заменён целиком. Отменить нельзя.',
        'This is a backup of a different vault: the vault on this device will be replaced entirely. This cannot be undone.',
      ),
      _ => tr(
        context,
        'Текущий сейф будет заменён. Отменить это действие нельзя.',
        'The current vault will be replaced. This cannot be undone.',
      ),
    };
  }

  Future<void> _restore() async {
    if (_bytes == null || _password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await ref.read(vaultPathProvider.future);
      final session = await importBackup(_bytes!, _password.text, path);
      _password.clear();
      ref.read(vaultSessionProvider.notifier).useRestoredSession(session);
      if (mounted) context.go('/passwords');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            'Не удалось восстановить сейф. Текущие данные сохранены.',
            'Could not restore the vault. Current data was preserved.',
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
    final step = _step;
    if (MediaQuery.sizeOf(context).width < 600) {
      return _mobileRestore(context, colors);
    }
    return BackupFrame(
      title: tr(context, 'Восстановление', 'Restore'),
      subtitle: tr(
        context,
        'Зашифрованные данные хранятся только на устройстве.',
        'Encrypted data stays on your device.',
      ),
      onBack: _back,
      backLabel: widget.standalone ? tr(context, 'Назад', 'Back') : null,
      heroIcon: step == _RestoreStep.confirm
          ? LucideIcons.triangleAlert
          : step == _RestoreStep.password
          ? LucideIcons.lockKeyhole
          : LucideIcons.upload,
      heroTitle: tr(
        context,
        step == _RestoreStep.pick
            ? 'Выберите бэкап'
            : step == _RestoreStep.password
            ? 'Введите мастер-пароль'
            : _kind == ImportKind.newVault
            ? 'Восстановить сейф?'
            : 'Заменить текущий сейф?',
        step == _RestoreStep.pick
            ? 'Choose a backup'
            : step == _RestoreStep.password
            ? 'Enter master password'
            : _kind == ImportKind.newVault
            ? 'Restore the vault?'
            : 'Replace the current vault?',
      ),
      heroDescription: tr(
        context,
        step == _RestoreStep.pick
            ? 'Найдите зашифрованный файл .akbackup.'
            : step == _RestoreStep.password
            ? 'Для открытия выбранной копии нужен её пароль.'
            : 'Перед подтверждением проверьте версии.',
        step == _RestoreStep.pick
            ? 'Find an encrypted .akbackup file.'
            : step == _RestoreStep.password
            ? 'Enter the password for this backup.'
            : 'Compare versions before continuing.',
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step == _RestoreStep.pick) ...[
            BackupFileTile(
              name: tr(
                context,
                'Выбрать файл .akbackup',
                'Choose .akbackup file',
              ),
              subtitle: tr(context, 'С устройства', 'From this device'),
            ),
            const SizedBox(height: 13),
            BackupNotice(
              message: tr(
                context,
                'Системное окно откроет выбор файла.',
                'The system dialog will open to choose a file.',
              ),
              icon: LucideIcons.shieldCheck,
            ),
            const SizedBox(height: 13),
            BackupAction(
              label: tr(context, 'Выбрать файл', 'Choose file'),
              icon: LucideIcons.folderOpen,
              onPressed: _busy ? null : _pick,
            ),
          ] else if (step == _RestoreStep.password) ...[
            BackupFileTile(
              name: tr(
                context,
                'Выбранная копия .akbackup',
                'Selected .akbackup file',
              ),
              subtitle:
                  tr(context, 'Версия: ', 'Version: ') +
                  (_header?.revision.toString() ?? '—'),
            ),
            const SizedBox(height: 17),
            Text(
              tr(context, 'Мастер-пароль копии', 'Backup master password'),
              style: TextStyle(
                color: colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _password,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'Введите мастер-пароль',
                  'Enter master password',
                ),
              ),
            ),
            const SizedBox(height: 13),
            BackupNotice(
              message: tr(
                context,
                'Пароль нужен только для проверки этого файла и не отправляется в сеть.',
                'The password is used only to check this file and is never sent.',
              ),
              icon: LucideIcons.shieldCheck,
            ),
            const SizedBox(height: 13),
            BackupAction(
              label: tr(context, 'Проверить файл', 'Check file'),
              icon: LucideIcons.shieldCheck,
              onPressed: _busy ? null : _check,
            ),
          ] else ...[
            BackupFileTile(
              name: tr(
                context,
                'Выбранная копия .akbackup',
                'Selected .akbackup file',
              ),
              subtitle: tr(context, 'Зашифрованный файл', 'Encrypted file'),
            ),
            const SizedBox(height: 13),
            BackupInfoRows(
              rows: [
                (
                  tr(context, 'Текущая ревизия', 'Current revision'),
                  (_current?.revision ?? '—').toString(),
                ),
                (
                  tr(context, 'В файле', 'In file'),
                  (_header?.revision ?? '—').toString(),
                ),
              ],
            ),
            const SizedBox(height: 13),
            BackupNotice(
              message: _replaceMessage(context),
              icon: LucideIcons.triangleAlert,
              tone: BackupNoticeTone.error,
            ),
            const SizedBox(height: 9),
            BackupNotice(
              message: _statusLabel(context, _status),
              icon: _status == AnchorStatus.verified
                  ? LucideIcons.circleCheck
                  : LucideIcons.shieldCheck,
              tone: _status == AnchorStatus.verified
                  ? BackupNoticeTone.success
                  : BackupNoticeTone.neutral,
            ),
            const SizedBox(height: 13),
            BackupAction(
              label: tr(
                context,
                _kind == ImportKind.newVault
                    ? 'Восстановить сейф'
                    : 'Восстановить и заменить',
                _kind == ImportKind.newVault
                    ? 'Restore vault'
                    : 'Restore and replace',
              ),
              icon: LucideIcons.upload,
              onPressed: _busy ? null : _restore,
            ),
            const SizedBox(height: 8),
            BackupAction(
              label: tr(context, 'Отмена', 'Cancel'),
              icon: LucideIcons.x,
              outlined: true,
              onPressed: _busy ? null : _back,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            BackupNotice(
              message: _error!,
              icon: LucideIcons.triangleAlert,
              tone: BackupNoticeTone.error,
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(color: colors.gold),
          ],
        ],
      ),
    );
  }

  Widget _mobileRestore(BuildContext context, VaultColors colors) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SafeArea(
      top: widget.standalone,
      bottom: widget.standalone,
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.standalone ? 24 : 12,
                  20,
                  widget.standalone ? 16 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: tr(context, 'Назад', 'Back'),
                          onPressed: _busy ? null : _back,
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
                        Expanded(
                          child: Text(
                            tr(context, 'Восстановление', 'Restore'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 36),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 230),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .025),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_step),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mobileHero(context, colors),
                          const SizedBox(height: 15),
                          _mobileStepContent(context, colors),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 13),
                      BackupNotice(
                        message: _error!,
                        icon: LucideIcons.triangleAlert,
                        tone: BackupNoticeTone.error,
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : switch (_step) {
                                _RestoreStep.pick => _pick,
                                _RestoreStep.password => _check,
                                _RestoreStep.confirm => _restore,
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(switch (_step) {
                                _RestoreStep.pick => LucideIcons.folderOpen,
                                _RestoreStep.password =>
                                  LucideIcons.shieldCheck,
                                _RestoreStep.confirm => LucideIcons.upload,
                              }, size: 17),
                        label: Text(
                          tr(
                            context,
                            switch (_step) {
                              _RestoreStep.pick => 'Выбрать файл',
                              _RestoreStep.password => 'Проверить файл',
                              _RestoreStep.confirm =>
                                _kind == ImportKind.newVault
                                    ? 'Восстановить сейф'
                                    : 'Восстановить и заменить',
                            },
                            switch (_step) {
                              _RestoreStep.pick => 'Choose file',
                              _RestoreStep.password => 'Check file',
                              _RestoreStep.confirm =>
                                _kind == ImportKind.newVault
                                    ? 'Restore vault'
                                    : 'Restore and replace',
                            },
                          ),
                        ),
                      ),
                    ),
                    if (_step == _RestoreStep.confirm) ...[
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _back,
                          child: Text(tr(context, 'Отмена', 'Cancel')),
                        ),
                      ),
                    ],
                    if (widget.standalone) ...[
                      const SizedBox(height: 13),
                      Text(
                        tr(
                          context,
                          'Данные остаются только на устройстве.',
                          'Your data stays on this device.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileHero(BuildContext context, VaultColors colors) {
    final icon = switch (_step) {
      _RestoreStep.pick => LucideIcons.upload,
      _RestoreStep.password => LucideIcons.lockKeyhole,
      _RestoreStep.confirm => LucideIcons.triangleAlert,
    };
    final title = tr(
      context,
      switch (_step) {
        _RestoreStep.pick => 'Выберите бэкап',
        _RestoreStep.password => 'Введите мастер-пароль',
        _RestoreStep.confirm =>
          _kind == ImportKind.newVault
              ? 'Восстановить сейф?'
              : 'Заменить текущий сейф?',
      },
      switch (_step) {
        _RestoreStep.pick => 'Choose a backup',
        _RestoreStep.password => 'Enter master password',
        _RestoreStep.confirm =>
          _kind == ImportKind.newVault
              ? 'Restore the vault?'
              : 'Replace the current vault?',
      },
    );
    final description = tr(
      context,
      switch (_step) {
        _RestoreStep.pick => 'Найдите зашифрованный файл .akbackup.',
        _RestoreStep.password =>
          'Для открытия выбранной копии нужен её мастер-пароль.',
        _RestoreStep.confirm => 'Перед подтверждением проверьте версии.',
      },
      switch (_step) {
        _RestoreStep.pick => 'Find an encrypted .akbackup file.',
        _RestoreStep.password => 'Enter the master password for this backup.',
        _RestoreStep.confirm => 'Compare versions before continuing.',
      },
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.goldSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: colors.gold, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileStepContent(BuildContext context, VaultColors colors) {
    switch (_step) {
      case _RestoreStep.pick:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mobileFileTile(context, colors, selectable: true),
            const SizedBox(height: 13),
            BackupNotice(
              message: tr(
                context,
                'Системное окно откроет выбор файла. Содержимое останется на устройстве.',
                'The system picker will open. The file stays on this device.',
              ),
              icon: LucideIcons.shieldCheck,
            ),
          ],
        );
      case _RestoreStep.password:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mobileFileTile(context, colors),
            const SizedBox(height: 18),
            Text(
              tr(context, 'Мастер-пароль бэкапа', 'Backup master password'),
              style: TextStyle(color: colors.muted, fontSize: 11),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _password,
              obscureText: !_passwordVisible,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _check(),
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'Введите мастер-пароль',
                  'Enter master password',
                ),
                prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 17),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible
                      ? tr(context, 'Скрыть пароль', 'Hide password')
                      : tr(context, 'Показать пароль', 'Show password'),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            BackupNotice(
              message: tr(
                context,
                'Пароль используется только для проверки файла и не отправляется в сеть.',
                'The password is used only to check this file and is never sent online.',
              ),
              icon: LucideIcons.shieldCheck,
            ),
          ],
        );
      case _RestoreStep.confirm:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mobileFileTile(context, colors),
            const SizedBox(height: 13),
            BackupInfoRows(
              rows: [
                (
                  tr(context, 'Текущая ревизия', 'Current revision'),
                  (_current?.revision ?? '—').toString(),
                ),
                (
                  tr(context, 'В файле', 'In file'),
                  (_header?.revision ?? '—').toString(),
                ),
              ],
            ),
            const SizedBox(height: 13),
            BackupNotice(
              message: _replaceMessage(context),
              icon: LucideIcons.triangleAlert,
              tone: _kind == ImportKind.newVault
                  ? BackupNoticeTone.neutral
                  : BackupNoticeTone.error,
            ),
            const SizedBox(height: 9),
            BackupNotice(
              message: _statusLabel(context, _status),
              icon: _status == AnchorStatus.verified
                  ? LucideIcons.circleCheck
                  : LucideIcons.shieldCheck,
              tone: _status == AnchorStatus.verified
                  ? BackupNoticeTone.success
                  : BackupNoticeTone.neutral,
            ),
          ],
        );
    }
  }

  Widget _mobileFileTile(
    BuildContext context,
    VaultColors colors, {
    bool selectable = false,
  }) {
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectable && !_busy ? _pick : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                  selectable ? LucideIcons.folderOpen : LucideIcons.fileLock2,
                  color: colors.gold,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectable
                          ? tr(
                              context,
                              'Выбрать файл .akbackup',
                              'Choose .akbackup file',
                            )
                          : _fileName ??
                                tr(
                                  context,
                                  'Выбранная копия .akbackup',
                                  'Selected .akbackup file',
                                ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectable
                          ? tr(context, 'С устройства', 'From this device')
                          : tr(context, 'Версия ', 'Version ') +
                                (_header?.revision.toString() ?? '—'),
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (selectable)
                Icon(LucideIcons.chevronRight, color: colors.muted, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, AnchorStatus? status) =>
      switch (status) {
        AnchorStatus.verified => tr(
          context,
          'Версия подтверждена в Solana.',
          'Version verified in Solana.',
        ),
        AnchorStatus.outdated => tr(
          context,
          'Копия старее зарегистрированной версии.',
          'Backup is older than the registered version.',
        ),
        AnchorStatus.unknown => tr(
          context,
          'Копия не совпадает с зарегистрированной версией.',
          'Backup does not match the registered version.',
        ),
        AnchorStatus.notAnchored => tr(
          context,
          'Сейф ещё не зарегистрирован в Solana.',
          'This vault is not registered in Solana yet.',
        ),
        AnchorStatus.offline => tr(
          context,
          'Сеть недоступна. Проверка Solana пропущена.',
          'Network unavailable. Solana verification skipped.',
        ),
        null => '',
      };
}
