// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/solana/backup_verification.dart';
import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:anchorkeep/core/solana/vault_keypair.dart';
import 'package:anchorkeep/core/solana/vault_registry.dart';
import 'package:anchorkeep/core/vault/backup.dart';
import 'package:anchorkeep/core/vault/backup_import.dart';
import 'package:anchorkeep/core/vault/backup_import_picker.dart';
import 'package:anchorkeep/core/vault/backup_picker.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/shared/backup_illustration.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:solana/solana.dart';

enum _BackupPage { overview, export, restore, anchor, verify }

enum _ExportStage { ready, saved, error }

typedef RestoreBuilder = Widget Function(VoidCallback onBack, Uint8List? bytes);

/// Рабочая область бэкапа: экранные состояния из Android/Windows макетов.
class BackupWorkspace extends ConsumerStatefulWidget {
  const BackupWorkspace({required this.restoreBuilder, super.key});

  final RestoreBuilder restoreBuilder;

  @override
  ConsumerState<BackupWorkspace> createState() => _BackupWorkspaceState();
}

class _BackupWorkspaceState extends ConsumerState<BackupWorkspace> {
  _BackupPage _page = _BackupPage.overview;
  _ExportStage _exportStage = _ExportStage.ready;
  bool _busy = false;
  String? _exportName;
  Uint8List? _restoreBytes;

  void _open(_BackupPage page) => setState(() {
    _page = page;
    if (page == _BackupPage.export) {
      _exportStage = _ExportStage.ready;
      final header = ref.read(vaultSessionProvider)?.header;
      _exportName = header == null
          ? null
          : backupFileName(header, DateTime.now());
    }
    if (page == _BackupPage.restore) _restoreBytes = null;
  });

  void _back() => setState(() => _page = _BackupPage.overview);

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await ref.read(vaultPathProvider.future);
      final bytes = await File(path).readAsBytes();
      final at = DateTime.now();
      _exportName = backupFileName(VaultFile.decode(bytes).header, at);
      final saved = await exportBackup(
        bytes,
        saveBackupWithPicker,
        now: () => at,
      );
      if (mounted && saved != null) {
        setState(() => _exportStage = _ExportStage.saved);
      }
    } catch (_) {
      if (mounted) setState(() => _exportStage = _ExportStage.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220),
    layoutBuilder: (currentChild, previousChildren) => Stack(
      alignment: Alignment.topCenter,
      children: [...previousChildren, ?currentChild],
    ),
    child: switch (_page) {
      _BackupPage.overview => KeyedSubtree(
        key: const ValueKey('backup-overview'),
        child: _overview(),
      ),
      _BackupPage.export => KeyedSubtree(
        key: const ValueKey('backup-export'),
        child: _exportView(),
      ),
      _BackupPage.restore => KeyedSubtree(
        key: const ValueKey('backup-restore'),
        child: widget.restoreBuilder(_back, _restoreBytes),
      ),
      _BackupPage.anchor => KeyedSubtree(
        key: const ValueKey('backup-anchor'),
        child: BackupChainView(
          anchor: true,
          onBack: _back,
          onVerify: () => _open(_BackupPage.verify),
        ),
      ),
      _BackupPage.verify => KeyedSubtree(
        key: const ValueKey('backup-verify'),
        child: BackupChainView(
          anchor: false,
          onBack: _back,
          onRestore: (bytes) => setState(() {
            _restoreBytes = bytes;
            _page = _BackupPage.restore;
          }),
        ),
      ),
    },
  );

  Widget _overview() {
    final session = ref.watch(vaultSessionProvider);
    final revision = session?.header.revision;
    int? anchored;
    try {
      if (session != null) anchored = lastAnchoredRevision(session.payload);
    } catch (_) {
      anchored = null;
    }
    final colors = VaultColors.of(context);
    return BackupFrame(
      title: tr(context, 'Бэкап и проверка', 'Backup and verification'),
      showDesktopBack: false,
      subtitle: tr(
        context,
        'Зашифрованные данные хранятся только на устройстве.',
        'Encrypted data stays on your device.',
      ),
      onBack: () => context.go('/passwords'),
      heroIcon: LucideIcons.fileLock2,
      heroTitle: tr(context, 'Зашифрованный файл', 'Encrypted file'),
      heroDescription: tr(
        context,
        'Переносите данные через защищённый .akbackup.',
        'Move your data with an encrypted .akbackup file.',
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackupInfoRows(
            rows: [
              (
                tr(context, 'Локальная ревизия', 'Local revision'),
                '${revision ?? '—'}',
              ),
              (
                tr(context, 'Последняя заверенная', 'Last anchored'),
                '${anchored ?? '—'}',
              ),
            ],
          ),
          const SizedBox(height: 17),
          BackupAction(
            label: tr(context, 'Экспортировать', 'Export'),
            icon: LucideIcons.download,
            onPressed: () => _open(_BackupPage.export),
          ),
          const SizedBox(height: 8),
          BackupAction(
            label: tr(context, 'Восстановить', 'Restore'),
            icon: LucideIcons.upload,
            outlined: true,
            onPressed: () => _open(_BackupPage.restore),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BackupAction(
                  label: tr(context, 'Заверить', 'Anchor'),
                  icon: LucideIcons.fingerprint,
                  muted: true,
                  onPressed: () => _open(_BackupPage.anchor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BackupAction(
                  label: tr(context, 'Проверить', 'Verify'),
                  icon: LucideIcons.shieldCheck,
                  muted: true,
                  onPressed: () => _open(_BackupPage.verify),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          BackupNotice(
            message: tr(
              context,
              'В Solana записываются только цифровой отпечаток и версия файла.',
              'Only the file fingerprint and version are recorded in Solana.',
            ),
            icon: LucideIcons.shieldCheck,
          ),
          const SizedBox(height: 11),
          Text(
            tr(
              context,
              'Заверение и проверка требуют сети. Обычная работа сейфа — нет.',
              'Anchoring and verification need a network. Everyday vault use does not.',
            ),
            style: TextStyle(color: colors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _exportView() {
    final saved = _exportStage == _ExportStage.saved;
    final error = _exportStage == _ExportStage.error;
    return BackupFrame(
      title: tr(context, 'Экспорт', 'Export'),
      subtitle: tr(
        context,
        'Зашифрованные данные хранятся только на устройстве.',
        'Encrypted data stays on your device.',
      ),
      onBack: _back,
      heroIcon: saved
          ? LucideIcons.circleCheck
          : error
          ? LucideIcons.triangleAlert
          : LucideIcons.fileLock2,
      heroTitle: tr(
        context,
        saved
            ? 'Файл сохранён'
            : error
            ? 'Не удалось сохранить'
            : 'Подготовка бэкапа',
        saved
            ? 'File ready to transfer'
            : error
            ? 'Could not save the file'
            : 'Preparing the backup',
      ),
      heroDescription: tr(
        context,
        saved
            ? 'Зашифрованный бэкап сохранён на устройстве.'
            : error
            ? 'Повторите экспорт или выберите другое место.'
            : 'Сохранение .akbackup выполняется через системное окно.',
        saved
            ? 'The encrypted backup was saved on this device.'
            : error
            ? 'Try exporting again or choose another location.'
            : 'The system dialog saves your .akbackup file.',
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BackupFileTile(
            name: _exportName ?? 'ciphervault.akbackup',
            subtitle: tr(
              context,
              'Зашифрованный файл .akbackup',
              'Encrypted .akbackup file',
            ),
          ),
          const SizedBox(height: 13),
          BackupNotice(
            message: tr(
              context,
              saved
                  ? 'Пароли и заметки остались зашифрованными.'
                  : error
                  ? 'Текущий сейф не изменился.'
                  : 'Место сохранения откроется в системном окне.',
              saved
                  ? 'Passwords and notes remain encrypted.'
                  : error
                  ? 'The current vault was not changed.'
                  : 'Choose a save location in the system dialog.',
            ),
            icon: saved
                ? LucideIcons.circleCheck
                : error
                ? LucideIcons.triangleAlert
                : LucideIcons.shieldCheck,
            tone: saved
                ? BackupNoticeTone.success
                : error
                ? BackupNoticeTone.error
                : BackupNoticeTone.neutral,
          ),
          const SizedBox(height: 13),
          BackupAction(
            label: tr(
              context,
              saved
                  ? 'Готово'
                  : error
                  ? 'Повторить'
                  : 'Выбрать место сохранения',
              saved
                  ? 'Done'
                  : error
                  ? 'Retry'
                  : 'Choose save location',
            ),
            icon: saved ? LucideIcons.check : LucideIcons.download,
            onPressed: _busy
                ? null
                : saved
                ? _back
                : _export,
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(color: VaultColors.of(context).gold),
          ],
        ],
      ),
    );
  }
}

enum _ChainStage { ready, pending, finished, error, offline, noSol }

class BackupChainView extends ConsumerStatefulWidget {
  const BackupChainView({
    required this.anchor,
    required this.onBack,
    this.onRestore,
    this.onVerify,
    super.key,
  });
  final bool anchor;
  final VoidCallback onBack;
  final ValueChanged<Uint8List>? onRestore;
  final VoidCallback? onVerify;

  @override
  ConsumerState<BackupChainView> createState() => _BackupChainViewState();
}

class _BackupChainViewState extends ConsumerState<BackupChainView> {
  _ChainStage _stage = _ChainStage.ready;
  AnchorStatus? _status;
  Uint8List? _selectedBytes;
  int? _selectedRevision;
  int? _anchoredRevision;
  String? _message;
  bool _busy = false;

  VaultRegistry _registry() => VaultRegistry(
    SolanaClient(
      rpcUrl: SolanaConfig.rpcUrl,
      websocketUrl: SolanaConfig.websocketUrl,
    ),
  );

  Future<void> _anchor() async {
    final session = ref.read(vaultSessionProvider);
    if (session == null || _busy) return;
    setState(() {
      _busy = true;
      _stage = _ChainStage.pending;
      _status = null;
      _message = null;
    });
    try {
      final path = await ref.read(vaultPathProvider.future);
      final bytes = await File(path).readAsBytes();
      final header = VaultFile.decode(bytes).header;
      final hash = (await Sha256().hash(bytes)).bytes;
      final owner = await solanaKeypair(session.payload);
      final registry = _registry();
      final record = await registry.fetchRecord(
        owner.publicKey,
        header.vaultId,
      );
      if (record != null && header.revision <= record.version) {
        if (mounted) {
          setState(() {
            _stage = _ChainStage.error;
            _message = tr(
              context,
              'Эта версия уже заверена. Измените сейф перед новым заверением.',
              'This version is already anchored. Change the vault before anchoring again.',
            );
          });
        }
        return;
      }
      final signature = record == null
          ? await registry.initializeVault(
              owner: owner,
              vaultId: header.vaultId,
              hash: hash,
              version: header.revision,
            )
          : await registry.commitVersion(
              owner: owner,
              vaultId: header.vaultId,
              hash: hash,
              version: header.revision,
            );
      if (ref.read(vaultSessionProvider) == session &&
          session.header.revision == header.revision) {
        markAnchored(session.payload, header.revision);
      }
      final current = await File(path).readAsBytes();
      final status = await verifyVaultFile(
        fileBytes: current,
        owner: owner.publicKey,
        fetch: registry.fetchRecord,
      );
      if (mounted) {
        setState(() {
          _status = status;
          _stage = _ChainStage.finished;
          _message = tr(
            context,
            status == AnchorStatus.offline
                ? 'Транзакция подтверждена, но повторная проверка пока недоступна. ID: ${signature.substring(0, 12)}…'
                : 'Транзакция Devnet подтверждена. ID: ${signature.substring(0, 12)}…',
            status == AnchorStatus.offline
                ? 'Transaction confirmed, but another check is unavailable. ID: ${signature.substring(0, 12)}…'
                : 'Devnet transaction confirmed. ID: ${signature.substring(0, 12)}…',
          );
        });
      }
    } on SocketException {
      if (mounted) setState(() => _stage = _ChainStage.offline);
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (mounted) {
        setState(() {
          _status = null;
          _stage = message.contains('insufficient')
              ? _ChainStage.noSol
              : message.contains('timeout') ||
                    message.contains('connection') ||
                    message.contains('network') ||
                    message.contains('socket')
              ? _ChainStage.offline
              : _ChainStage.error;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify({bool pick = false}) async {
    final session = ref.read(vaultSessionProvider);
    if (session == null || _busy) return;
    if (pick) {
      try {
        final bytes = await pickBackupBytes();
        if (bytes == null) return;
        final header = previewBackup(bytes);
        if (mounted) {
          setState(() {
            _selectedBytes = bytes;
            _selectedRevision = header.revision;
            _anchoredRevision = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _stage = _ChainStage.error;
            _status = null;
            _selectedBytes = null;
            _selectedRevision = null;
            _anchoredRevision = null;
            _message = tr(
              context,
              'Выбранный файл не является бэкапом CipherVault.',
              'The selected file is not a CipherVault backup.',
            );
          });
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _stage = _ChainStage.pending;
      _status = null;
      _message = null;
    });
    try {
      final bytes =
          _selectedBytes ??
          await File(await ref.read(vaultPathProvider.future)).readAsBytes();
      final header = VaultFile.decode(bytes).header;
      final owner = solanaOwner(session.payload);
      VaultRecord? record;
      final status = await verifyVaultFile(
        fileBytes: bytes,
        owner: owner,
        fetch: (publicKey, vaultId) async {
          record = await _registry().fetchRecord(publicKey, vaultId);
          return record;
        },
      );
      if (mounted) {
        setState(() {
          _selectedRevision = header.revision;
          _anchoredRevision = record?.version;
          _status = status;
          _stage = status == AnchorStatus.offline
              ? _ChainStage.offline
              : _ChainStage.finished;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _ChainStage.error;
          _message = tr(
            context,
            'Не удалось проверить файл.',
            'Could not verify the file.',
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
    final anchor = widget.anchor;
    final revision = ref.watch(vaultSessionProvider)?.header.revision;
    final stage = _stage;
    final status = _status;
    final title = anchor
        ? tr(context, 'Заверение версии', 'Anchor version')
        : tr(context, 'Проверка бэкапа', 'Verify backup');
    final heroTitle = anchor
        ? tr(
            context,
            stage == _ChainStage.pending
                ? 'Отправка в Devnet'
                : stage == _ChainStage.finished
                ? 'Версия заверена'
                : stage == _ChainStage.noSol
                ? 'Недостаточно Devnet-SOL'
                : stage == _ChainStage.offline
                ? 'Сеть недоступна'
                : stage == _ChainStage.error
                ? 'Заверение не выполнено'
                : 'Заверить версию файла',
            stage == _ChainStage.pending
                ? 'Sending to Devnet'
                : stage == _ChainStage.finished
                ? 'Version anchored'
                : stage == _ChainStage.noSol
                ? 'Not enough Devnet SOL'
                : stage == _ChainStage.offline
                ? 'Network unavailable'
                : stage == _ChainStage.error
                ? 'Anchoring failed'
                : 'Anchor this file version',
          )
        : tr(
            context,
            stage == _ChainStage.pending
                ? 'Проверка записи'
                : status == AnchorStatus.verified
                ? 'Файл подтверждён'
                : status == AnchorStatus.outdated
                ? 'Бэкап устарел'
                : status == AnchorStatus.unknown
                ? 'Версия не подтверждена'
                : status == AnchorStatus.notAnchored
                ? 'Нет записи о заверении'
                : status == AnchorStatus.offline
                ? 'Сеть недоступна'
                : stage == _ChainStage.error
                ? 'Не удалось проверить файл'
                : 'Проверить версию файла',
            stage == _ChainStage.pending
                ? 'Checking the record'
                : status == AnchorStatus.verified
                ? 'File verified'
                : status == AnchorStatus.outdated
                ? 'Backup is outdated'
                : status == AnchorStatus.unknown
                ? 'Version not verified'
                : status == AnchorStatus.notAnchored
                ? 'No anchored record'
                : status == AnchorStatus.offline
                ? 'Network unavailable'
                : stage == _ChainStage.error
                ? 'Could not verify file'
                : 'Verify this file version',
          );
    final tone = stage == _ChainStage.noSol || status == AnchorStatus.outdated
        ? BackupNoticeTone.warning
        : stage == _ChainStage.error
        ? BackupNoticeTone.error
        : stage == _ChainStage.finished &&
              (anchor || status == AnchorStatus.verified)
        ? BackupNoticeTone.success
        : BackupNoticeTone.neutral;
    return BackupFrame(
      title: title,
      subtitle: tr(
        context,
        'Solana Devnet хранит только цифровой отпечаток зашифрованного файла.',
        'Solana Devnet stores only the encrypted file fingerprint.',
      ),
      onBack: widget.onBack,
      heroIcon: stage == _ChainStage.pending
          ? LucideIcons.loaderCircle
          : stage == _ChainStage.error ||
                stage == _ChainStage.noSol ||
                status == AnchorStatus.outdated
          ? LucideIcons.triangleAlert
          : stage == _ChainStage.offline
          ? LucideIcons.wifiOff
          : anchor && stage == _ChainStage.finished ||
                status == AnchorStatus.verified
          ? LucideIcons.circleCheck
          : anchor || status == AnchorStatus.notAnchored
          ? LucideIcons.fingerprint
          : LucideIcons.shieldCheck,
      heroTitle: heroTitle,
      heroDescription: anchor
          ? tr(
              context,
              stage == _ChainStage.pending
                  ? 'Ожидаем подтверждения заверения версии.'
                  : stage == _ChainStage.finished
                  ? 'Цифровой отпечаток версии $revision зарегистрирован.'
                  : stage == _ChainStage.offline
                  ? 'Для заверения нужен интернет.'
                  : stage == _ChainStage.noSol
                  ? 'Для сетевой операции нужен баланс Devnet-SOL.'
                  : 'В Devnet отправится SHA-256 зашифрованного файла и версия.',
              stage == _ChainStage.pending
                  ? 'Waiting for the version to be anchored.'
                  : stage == _ChainStage.finished
                  ? 'The fingerprint for version $revision was registered.'
                  : stage == _ChainStage.offline
                  ? 'Anchoring requires an internet connection.'
                  : stage == _ChainStage.noSol
                  ? 'A Devnet SOL balance is needed for this transaction.'
                  : 'Only the encrypted file SHA-256 and version go to Devnet.',
            )
          : tr(
              context,
              status == AnchorStatus.verified
                  ? 'Совпадает с последней заверенной версией.'
                  : status == AnchorStatus.outdated
                  ? 'Файл старее последней заверенной версии.'
                  : status == AnchorStatus.unknown
                  ? 'Совпадение с последней записью не установлено.'
                  : status == AnchorStatus.notAnchored
                  ? 'Для сейфа ещё нет заверенной версии в Devnet.'
                  : status == AnchorStatus.offline
                  ? 'Невозможно сравнить файл с записью Devnet.'
                  : 'Сравните отпечаток зашифрованного файла с Devnet.',
              status == AnchorStatus.verified
                  ? 'Matches the latest anchored version.'
                  : status == AnchorStatus.outdated
                  ? 'The file is older than the latest anchored version.'
                  : status == AnchorStatus.unknown
                  ? 'No match with the latest record was established.'
                  : status == AnchorStatus.notAnchored
                  ? 'This vault has no anchored Devnet version yet.'
                  : status == AnchorStatus.offline
                  ? 'Could not compare the file with Devnet.'
                  : 'Compare the encrypted file fingerprint with Devnet.',
            ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!anchor && status != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _BackupStatusChip(status: status),
            ),
            const SizedBox(height: 12),
          ],
          BackupInfoRows(
            rows: anchor
                ? [
                    (
                      tr(context, 'Локальная ревизия', 'Local revision'),
                      '${revision ?? '—'}',
                    ),
                    (tr(context, 'Сеть', 'Network'), 'Solana Devnet'),
                  ]
                : [
                    (
                      tr(context, 'Выбранный файл', 'Selected file'),
                      tr(
                        context,
                        'Версия ${_selectedRevision ?? revision ?? '—'}',
                        'Version ${_selectedRevision ?? revision ?? '—'}',
                      ),
                    ),
                    (
                      tr(context, 'Последняя заверенная', 'Last anchored'),
                      _anchoredRevision == null
                          ? status == AnchorStatus.notAnchored
                                ? tr(context, 'Нет записи', 'No record')
                                : tr(context, 'Не проверена', 'Not checked')
                          : tr(
                              context,
                              'Версия $_anchoredRevision',
                              'Version $_anchoredRevision',
                            ),
                    ),
                  ],
          ),
          const SizedBox(height: 14),
          BackupNotice(
            message:
                _message ??
                (anchor
                    ? tr(
                        context,
                        stage == _ChainStage.finished
                            ? 'Блокчейн не хранит ваши секреты и не восстанавливает их.'
                            : stage == _ChainStage.noSol
                            ? 'Запросите Devnet-SOL через кран тестовой сети.'
                            : stage == _ChainStage.offline
                            ? 'Проверьте подключение к интернету и повторите.'
                            : stage == _ChainStage.error
                            ? 'Новая запись о версии не подтверждена.'
                            : 'Пароли, заметки, мастер-пароль и сам файл не отправляются.',
                        stage == _ChainStage.finished
                            ? 'The blockchain does not store or restore your secrets.'
                            : stage == _ChainStage.noSol
                            ? 'Request Devnet SOL from the testnet faucet.'
                            : stage == _ChainStage.offline
                            ? 'Check your connection and try again.'
                            : stage == _ChainStage.error
                            ? 'The new version was not confirmed.'
                            : 'Passwords, notes, master password, and the file are never sent.',
                      )
                    : tr(
                        context,
                        status == AnchorStatus.verified
                            ? 'Совпадение подтверждено. Файл можно использовать для восстановления.'
                            : status == AnchorStatus.outdated
                            ? 'Файл старее последней заверенной версии.'
                            : status == AnchorStatus.unknown
                            ? 'Отпечаток файла не совпал с записью. Проверьте источник.'
                            : status == AnchorStatus.notAnchored
                            ? 'Для этого сейфа ещё не создана запись.'
                            : status == AnchorStatus.offline
                            ? 'Нет сети — это не значит, что файл повреждён.'
                            : 'Сравнивается отпечаток зашифрованного файла, а не его содержимое.',
                        status == AnchorStatus.verified
                            ? 'The file matches and can be used for restore.'
                            : status == AnchorStatus.outdated
                            ? 'The file is older than the latest anchored version.'
                            : status == AnchorStatus.unknown
                            ? 'The file fingerprint does not match. Check its source.'
                            : status == AnchorStatus.notAnchored
                            ? 'No record exists for this vault yet.'
                            : status == AnchorStatus.offline
                            ? 'No network does not mean the file is damaged.'
                            : 'Only the encrypted file fingerprint is compared.',
                      )),
            icon: tone == BackupNoticeTone.success
                ? LucideIcons.circleCheck
                : tone == BackupNoticeTone.error ||
                      tone == BackupNoticeTone.warning
                ? LucideIcons.triangleAlert
                : LucideIcons.shieldCheck,
            tone: tone,
          ),
          if (anchor && stage == _ChainStage.finished) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.circleCheck,
                      color: colors.success,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tr(context, 'Заверение выполнено', 'Anchor complete'),
                      style: TextStyle(
                        color: colors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          BackupAction(
            label: tr(
              context,
              anchor
                  ? stage == _ChainStage.finished
                        ? 'Проверить бэкап'
                        : stage == _ChainStage.pending
                        ? 'Отправка в Devnet'
                        : stage == _ChainStage.noSol
                        ? 'Настройки Devnet'
                        : stage == _ChainStage.ready
                        ? 'Заверить версию'
                        : 'Повторить'
                  : status == AnchorStatus.verified && _selectedBytes != null
                  ? 'Продолжить восстановление'
                  : stage == _ChainStage.ready
                  ? 'Выбрать файл .akbackup'
                  : stage == _ChainStage.offline
                  ? 'Повторить проверку'
                  : 'Выбрать другой файл',
              anchor
                  ? stage == _ChainStage.finished
                        ? 'Verify backup'
                        : stage == _ChainStage.pending
                        ? 'Sending to Devnet'
                        : stage == _ChainStage.noSol
                        ? 'Devnet settings'
                        : stage == _ChainStage.ready
                        ? 'Anchor version'
                        : 'Retry'
                  : status == AnchorStatus.verified && _selectedBytes != null
                  ? 'Continue restore'
                  : stage == _ChainStage.ready
                  ? 'Choose .akbackup file'
                  : stage == _ChainStage.offline
                  ? 'Retry verification'
                  : 'Choose another file',
            ),
            icon: anchor ? LucideIcons.fingerprint : LucideIcons.shieldCheck,
            onPressed: _busy
                ? null
                : anchor
                ? stage == _ChainStage.finished
                      ? widget.onVerify ?? widget.onBack
                      : stage == _ChainStage.noSol
                      ? () => context.go('/settings')
                      : _anchor
                : status == AnchorStatus.verified && _selectedBytes != null
                ? () => widget.onRestore?.call(_selectedBytes!)
                : stage == _ChainStage.ready
                ? () => _verify(pick: true)
                : stage == _ChainStage.offline && _selectedBytes != null
                ? () => _verify()
                : () => _verify(pick: true),
          ),
          if (!anchor) ...[
            const SizedBox(height: 8),
            BackupAction(
              label: tr(
                context,
                'Проверить текущий сейф',
                'Verify current vault',
              ),
              icon: LucideIcons.shieldCheck,
              outlined: true,
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _selectedBytes = null;
                        _selectedRevision = null;
                        _anchoredRevision = null;
                      });
                      _verify();
                    },
            ),
          ],
          if (!anchor) ...[
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'Сравнивается отпечаток зашифрованного файла, а не его содержимое.',
                'Only the encrypted file fingerprint is compared, not its contents.',
              ),
              style: TextStyle(color: colors.muted, fontSize: 11, height: 1.4),
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
}

class _BackupStatusChip extends StatelessWidget {
  const _BackupStatusChip({required this.status});

  final AnchorStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final success = status == AnchorStatus.verified;
    final warning = status == AnchorStatus.outdated;
    final color = success
        ? colors.success
        : warning
        ? colors.warning
        : colors.muted;
    final label = switch (status) {
      AnchorStatus.verified => 'Verified',
      AnchorStatus.outdated => 'Outdated',
      AnchorStatus.unknown => 'Unknown',
      AnchorStatus.notAnchored => 'Not anchored',
      AnchorStatus.offline => 'Offline',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            success
                ? LucideIcons.circleCheck
                : warning
                ? LucideIcons.triangleAlert
                : LucideIcons.fingerprint,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class BackupFrame extends StatelessWidget {
  const BackupFrame({
    required this.title,
    required this.subtitle,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroDescription,
    required this.content,
    this.onBack,
    this.showDesktopBack = true,
    this.backLabel,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData heroIcon;
  final String heroTitle;
  final String heroDescription;
  final Widget content;
  final VoidCallback? onBack;
  final bool showDesktopBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final colors = VaultColors.of(context);
      final width = bounds.maxWidth;
      final mobile = width < 600;
      final desktop = width >= 900;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          VaultLayout.gutter(width),
          mobile ? 20 : VaultLayout.gutter(width),
          VaultLayout.gutter(width),
          VaultLayout.gutter(width),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mobile && onBack != null) ...[
                  Row(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Назад', 'Back'),
                        onPressed: onBack,
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
                          title,
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
                ] else ...[
                  if (onBack != null && showDesktopBack) ...[
                    TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: Text(
                        backLabel ?? tr(context, 'К бэкапу', 'Back to backup'),
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: VaultLayout.heading(width),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                ],
                Container(
                  width: double.infinity,
                  constraints: mobile
                      ? const BoxConstraints(minHeight: 116)
                      : null,
                  padding: EdgeInsets.all(mobile ? 17 : 18),
                  decoration: BoxDecoration(
                    color: colors.soft,
                    borderRadius: BorderRadius.circular(mobile ? 15 : 13),
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
                        child: Icon(heroIcon, color: colors.gold, size: 24),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heroTitle,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: mobile ? 15 : 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              heroDescription,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: mobile ? 12 : 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                if (desktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _panel(context, content)),
                      const SizedBox(width: 15),
                      Expanded(
                        flex: 2,
                        child: _panel(
                          context,
                          Column(
                            children: [
                              const BackupIllustration(),
                              const SizedBox(height: 24),
                              BackupNotice(
                                message: tr(
                                  context,
                                  'Для доступа к копии нужен только ваш мастер-пароль.',
                                  'Only your master password opens this backup.',
                                ),
                                icon: LucideIcons.shieldCheck,
                              ),
                            ],
                          ),
                          soft: true,
                        ),
                      ),
                    ],
                  )
                else
                  _panel(context, content, flat: mobile),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _panel(
    BuildContext context,
    Widget child, {
    bool soft = false,
    bool flat = false,
  }) {
    final colors = VaultColors.of(context);
    if (flat) return child;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 305),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: soft ? colors.soft : colors.surface,
        border: soft ? null : Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: child,
    );
  }
}

enum BackupNoticeTone { neutral, success, warning, error }

class BackupNotice extends StatelessWidget {
  const BackupNotice({
    required this.message,
    required this.icon,
    this.tone = BackupNoticeTone.neutral,
    super.key,
  });
  final String message;
  final IconData icon;
  final BackupNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final tint = switch (tone) {
      BackupNoticeTone.neutral => colors.gold,
      BackupNoticeTone.success => colors.success,
      BackupNoticeTone.warning => colors.warning,
      BackupNoticeTone.error => colors.danger,
    };
    final background = switch (tone) {
      BackupNoticeTone.neutral => colors.soft,
      BackupNoticeTone.success => colors.success.withValues(alpha: .11),
      BackupNoticeTone.warning => colors.goldSoft,
      BackupNoticeTone.error => colors.danger.withValues(alpha: .11),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone == BackupNoticeTone.neutral ? colors.muted : tint,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackupInfoRows extends StatelessWidget {
  const BackupInfoRows({required this.rows, super.key});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BackupFileTile extends StatelessWidget {
  const BackupFileTile({required this.name, required this.subtitle, super.key});
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              color: colors.goldSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.fileLock2, color: colors.gold, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  subtitle,
                  style: TextStyle(color: colors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BackupAction extends StatelessWidget {
  const BackupAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
    this.muted = false,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final style = muted
        ? FilledButton.styleFrom(
            backgroundColor: colors.soft,
            foregroundColor: colors.ink,
          )
        : null;
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
            )
          : FilledButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
            ),
    );
  }
}
