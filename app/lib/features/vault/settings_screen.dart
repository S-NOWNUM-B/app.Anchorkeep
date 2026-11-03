// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui';

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/preferences.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/solana/solana_config.dart';
import 'package:anchorkeep/core/solana/vault_keypair.dart';
import 'package:anchorkeep/core/vault/atomic_write.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/features/vault/change_password_dialog.dart';
import 'package:anchorkeep/shared/settings_illustration.dart';
import 'package:anchorkeep/shared/status_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:solana/solana.dart';

enum _SettingsPage { overview, appearance, autoLock, lock, devnet }

enum _DevnetStage { account, balance, pending, success, offline, limit, error }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsPage _page = _SettingsPage.overview;
  _DevnetStage _devnetStage = _DevnetStage.account;
  bool _saving = false;
  bool _chainBusy = false;
  String? _error;
  String? _balance;

  void _open(_SettingsPage page) => setState(() {
    _page = page;
    _error = null;
  });

  void _back() => setState(() {
    _page = _SettingsPage.overview;
    _error = null;
  });

  Future<void> _showChangePasswordDialog() => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .58),
    transitionDuration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: const Center(child: ChangePasswordDialog()),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: .96, end: 1.0).animate(animation),
        child: child,
      ),
    ),
  );

  SolanaClient _client() => SolanaClient(
    rpcUrl: SolanaConfig.rpcUrl,
    websocketUrl: SolanaConfig.websocketUrl,
  );

  _DevnetStage _networkError(Object error) {
    if (error is SocketException ||
        error.toString().toLowerCase().contains('socket') ||
        error.toString().toLowerCase().contains('connection')) {
      return _DevnetStage.offline;
    }
    final message = error.toString().toLowerCase();
    if (message.contains('429') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return _DevnetStage.limit;
    }
    return _DevnetStage.error;
  }

  Future<void> _loadBalance() async {
    final session = ref.read(vaultSessionProvider);
    if (session == null || _chainBusy) return;
    setState(() => _chainBusy = true);
    try {
      final owner = solanaOwner(session.payload);
      final value = await _client().rpcClient.getBalance(
        owner.toBase58(),
        commitment: Commitment.confirmed,
      );
      if (mounted) {
        setState(() {
          _balance = '${(value.value / lamportsPerSol).toStringAsFixed(2)} SOL';
          _devnetStage = _DevnetStage.balance;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _devnetStage = _networkError(error));
    } finally {
      if (mounted) setState(() => _chainBusy = false);
    }
  }

  Future<void> _airdrop() async {
    final session = ref.read(vaultSessionProvider);
    if (session == null || _chainBusy) return;
    setState(() {
      _chainBusy = true;
      _devnetStage = _DevnetStage.pending;
    });
    try {
      final owner = solanaOwner(session.payload);
      final client = _client();
      await client.requestAirdrop(
        address: owner,
        lamports: lamportsPerSol ~/ 10,
        commitment: Commitment.confirmed,
      );
      final value = await client.rpcClient.getBalance(
        owner.toBase58(),
        commitment: Commitment.confirmed,
      );
      if (mounted) {
        setState(() {
          _balance = '${(value.value / lamportsPerSol).toStringAsFixed(2)} SOL';
          _devnetStage = _DevnetStage.success;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _devnetStage = _networkError(error));
    } finally {
      if (mounted) setState(() => _chainBusy = false);
    }
  }

  Future<void> _autoLock(int minutes) async {
    final session = ref.read(vaultSessionProvider);
    if (session == null || _saving) return;
    final current = session.payload['settings'];
    final old = current is Map<String, Object?>
        ? Map<String, Object?>.from(current)
        : <String, Object?>{};
    final header = session.header;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      session.payload['settings'] = {...old, 'autoLockMinutes': minutes};
      final path = await ref.read(vaultPathProvider.future);
      await writeFileAtomic(path, await saveVault(session));
      ref.invalidate(autoLockMinutesProvider);
      if (mounted) setState(() {});
    } catch (_) {
      session.payload['settings'] = old;
      session.header = header;
      if (mounted) {
        setState(
          () => _error = tr(
            context,
            'Не удалось сохранить настройку. Повторите попытку.',
            'Could not save this setting. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    child: KeyedSubtree(
      key: ValueKey(_page),
      child: switch (_page) {
        _SettingsPage.overview => _overview(),
        _SettingsPage.appearance => _appearance(),
        _SettingsPage.autoLock => _autoLockView(),
        _SettingsPage.lock => _lockView(),
        _SettingsPage.devnet => _devnetView(),
      },
    ),
  );

  Widget _overview() {
    final theme = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider).languageCode;
    final minutes = ref.watch(autoLockMinutesProvider);
    return _SettingsFrame(
      desktopPanelHeight: 650,
      title: tr(context, 'Настройки', 'Settings'),
      subtitle: tr(
        context,
        'Контроль доступа, оформления и сетевых операций в одном месте.',
        'Access, appearance, and network controls in one place.',
      ),
      heroIcon: LucideIcons.settings2,
      heroTitle: tr(
        context,
        'Ваш сейф, ваши настройки.',
        'Your vault, your settings.',
      ),
      heroDescription: tr(
        context,
        'Все настройки сохраняются только на этом устройстве.',
        'All settings stay on this device.',
      ),
      onBack: () => context.go('/passwords'),
      showDesktopBack: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(tr(context, 'ПРИЛОЖЕНИЕ', 'APPLICATION')),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final themeRow = _entry(
                icon: LucideIcons.palette,
                title: tr(context, 'Тема', 'Theme'),
                detail: switch (theme) {
                  ThemeMode.light => tr(context, 'Светлая', 'Light'),
                  ThemeMode.dark => tr(context, 'Тёмная', 'Dark'),
                  ThemeMode.system => tr(context, 'Системная', 'System'),
                },
                onTap: () => _open(_SettingsPage.appearance),
              );
              final languageRow = _entry(
                icon: LucideIcons.languages,
                title: tr(context, 'Язык', 'Language'),
                detail: language == 'ru'
                    ? 'Русский · English'
                    : 'English · Русский',
                onTap: () => _open(_SettingsPage.appearance),
              );
              if (constraints.maxWidth >= 480) {
                return Row(
                  children: [
                    Expanded(child: themeRow),
                    const SizedBox(width: 10),
                    Expanded(child: languageRow),
                  ],
                );
              }
              return Column(
                children: [themeRow, const SizedBox(height: 9), languageRow],
              );
            },
          ),
          const SizedBox(height: 20),
          _sectionLabel(tr(context, 'БЕЗОПАСНОСТЬ', 'SECURITY')),
          const SizedBox(height: 9),
          _entry(
            icon: LucideIcons.timer,
            title: tr(context, 'Автоблокировка', 'Auto lock'),
            detail: tr(
              context,
              'Через $minutes минут',
              'After $minutes minutes',
            ),
            onTap: () => _open(_SettingsPage.autoLock),
          ),
          const SizedBox(height: 9),
          _entry(
            icon: LucideIcons.lockKeyhole,
            title: tr(context, 'Заблокировать', 'Lock vault'),
            detail: tr(context, 'Сейчас', 'Now'),
            onTap: () => _open(_SettingsPage.lock),
          ),
          const SizedBox(height: 9),
          _entry(
            icon: LucideIcons.keyRound,
            title: tr(context, 'Мастер-пароль', 'Master password'),
            detail: tr(context, 'Изменить', 'Change'),
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 20),
          _sectionLabel(tr(context, 'СЕТЬ', 'NETWORK')),
          const SizedBox(height: 9),
          _entry(
            icon: LucideIcons.wallet,
            title: 'Solana Devnet',
            detail: tr(context, 'Проверить баланс', 'Check balance'),
            onTap: () => _open(_SettingsPage.devnet),
          ),
        ],
      ),
    );
  }

  Widget _appearance() {
    final theme = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider).languageCode;
    return _SettingsFrame(
      desktopPanelHeight: 500,
      title: tr(context, 'Настройки', 'Settings'),
      subtitle: tr(
        context,
        'Контроль доступа, оформления и сетевых операций в одном месте.',
        'Access, appearance, and network controls in one place.',
      ),
      heroIcon: LucideIcons.sunMoon,
      heroTitle: tr(context, 'Оформление и язык', 'Appearance and language'),
      heroDescription: tr(
        context,
        'Выберите удобный режим для работы с сейфом.',
        'Choose a comfortable look for your vault.',
      ),
      onBack: _back,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(tr(context, 'Тема интерфейса', 'Interface theme')),
          const SizedBox(height: 13),
          _choice(
            icon: LucideIcons.sun,
            title: tr(context, 'Светлая', 'Light'),
            description: tr(
              context,
              'Кремовый фон и мягкие поверхности',
              'Cream background and soft surfaces',
            ),
            selected: theme == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
          ),
          const SizedBox(height: 9),
          _choice(
            icon: LucideIcons.moon,
            title: tr(context, 'Тёмная', 'Dark'),
            description: tr(
              context,
              'Графит и золотые акценты',
              'Graphite with gold accents',
            ),
            selected: theme == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
          ),
          const SizedBox(height: 9),
          _choice(
            icon: LucideIcons.monitor,
            title: tr(context, 'Системная', 'System'),
            description: tr(
              context,
              'Повторять тему устройства',
              'Follow your device theme',
            ),
            selected: theme == ThemeMode.system,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.system),
          ),
          const SizedBox(height: 22),
          _heading(tr(context, 'Язык интерфейса', 'Interface language')),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, bounds) {
              final ru = _choice(
                icon: LucideIcons.languages,
                title: 'Русский',
                selected: language == 'ru',
                onTap: () => ref
                    .read(languageProvider.notifier)
                    .setLanguage(const Locale('ru')),
              );
              final en = _choice(
                icon: LucideIcons.languages,
                title: 'English',
                selected: language == 'en',
                onTap: () => ref
                    .read(languageProvider.notifier)
                    .setLanguage(const Locale('en')),
              );
              if (bounds.maxWidth >= 480) {
                final colors = VaultColors.of(context);
                Widget segment(String label, String code) {
                  final selected = language == code;
                  return Expanded(
                    child: SizedBox(
                      height: 42,
                      child: selected
                          ? FilledButton(
                              onPressed: () => ref
                                  .read(languageProvider.notifier)
                                  .setLanguage(Locale(code)),
                              child: Text(label),
                            )
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(languageProvider.notifier)
                                  .setLanguage(Locale(code)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: colors.surface,
                              ),
                              child: Text(label),
                            ),
                    ),
                  );
                }

                return Row(
                  children: [
                    segment('Русский', 'ru'),
                    const SizedBox(width: 9),
                    segment('English', 'en'),
                  ],
                );
              }
              return Column(children: [ru, const SizedBox(height: 9), en]);
            },
          ),
        ],
      ),
    );
  }

  Widget _autoLockView() {
    final minutes = ref.watch(autoLockMinutesProvider);
    return _SettingsFrame(
      desktopPanelHeight: 530,
      title: tr(context, 'Настройки', 'Settings'),
      subtitle: tr(
        context,
        'Контроль доступа, оформления и сетевых операций в одном месте.',
        'Access, appearance, and network controls in one place.',
      ),
      heroIcon: LucideIcons.timer,
      heroTitle: tr(context, 'Автоблокировка', 'Auto lock'),
      heroDescription: tr(
        context,
        'Сейф закроется после выбранного времени бездействия.',
        'The vault locks after the selected period of inactivity.',
      ),
      onBack: _back,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            tr(
              context,
              'Через какое время блокировать сейф?',
              'When should the vault lock?',
            ),
          ),
          const SizedBox(height: 13),
          for (final (value, ru, en, detailRu, detailEn) in [
            (1, '1 минута', '1 minute', 'Быстро', 'Quick'),
            (5, '5 минут', '5 minutes', 'Рекомендуется', 'Recommended'),
            (15, '15 минут', '15 minutes', 'Больше времени', 'More time'),
            (30, '30 минут', '30 minutes', 'Длительная работа', 'Long session'),
          ]) ...[
            _choice(
              icon: LucideIcons.clock3,
              title: tr(context, ru, en),
              description: tr(context, detailRu, detailEn),
              selected: minutes == value,
              onTap: _saving ? null : () => _autoLock(value),
            ),
            const SizedBox(height: 9),
          ],
          if (_saving) const LinearProgressIndicator(),
          _notice(
            tr(
              context,
              'По умолчанию сейф блокируется через 5 минут бездействия.',
              'By default, the vault locks after 5 minutes of inactivity.',
            ),
            LucideIcons.info,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            StatusLabel(message: _error),
          ],
        ],
      ),
    );
  }

  Widget _lockView() => _SettingsFrame(
    desktopPanelHeight: 430,
    title: tr(context, 'Настройки', 'Settings'),
    subtitle: tr(
      context,
      'Контроль доступа, оформления и сетевых операций в одном месте.',
      'Access, appearance, and network controls in one place.',
    ),
    heroIcon: LucideIcons.lockKeyhole,
    heroTitle: tr(context, 'Заблокировать', 'Lock vault'),
    heroDescription: tr(
      context,
      'Доступ к данным снова откроется после ввода мастер-пароля.',
      'Enter your master password to open the vault again.',
    ),
    onBack: _back,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _notice(
          tr(
            context,
            'Несохранённые изменения могут быть потеряны.',
            'Unsaved changes may be lost.',
          ),
          LucideIcons.triangleAlert,
          warning: true,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
          icon: const Icon(LucideIcons.lockKeyhole, size: 17),
          label: Text(tr(context, 'Заблокировать сейчас', 'Lock now')),
        ),
        const SizedBox(height: 9),
        OutlinedButton(
          onPressed: _back,
          child: Text(tr(context, 'Отмена', 'Cancel')),
        ),
      ],
    ),
  );

  Widget _devnetView() {
    final session = ref.watch(vaultSessionProvider);
    String owner = '—';
    try {
      if (session != null) owner = solanaOwner(session.payload).toBase58();
    } catch (_) {}
    final configured = owner != '—';
    final stage = _devnetStage;
    final (icon, titleRu, titleEn, descRu, descEn) = switch (stage) {
      _DevnetStage.pending => (
        LucideIcons.loaderCircle,
        'Запрашиваем Devnet-SOL',
        'Requesting Devnet SOL',
        'Ожидаем ответ тестовой сети.',
        'Waiting for the test network.',
      ),
      _DevnetStage.success => (
        LucideIcons.circleCheck,
        'Devnet-SOL получены',
        'Devnet SOL received',
        'Тестовый баланс обновлён.',
        'Test balance updated.',
      ),
      _DevnetStage.offline => (
        LucideIcons.wifiOff,
        'Нет соединения',
        'No connection',
        'Проверьте интернет и повторите попытку.',
        'Check your connection and try again.',
      ),
      _DevnetStage.limit => (
        LucideIcons.clock3,
        'Лимит Devnet',
        'Devnet limit',
        'Запросите тестовые SOL позже.',
        'Request test SOL later.',
      ),
      _DevnetStage.error => (
        LucideIcons.triangleAlert,
        'Не удалось выполнить запрос',
        'Request failed',
        'Попробуйте обновить сведения ещё раз.',
        'Try refreshing the details again.',
      ),
      _ => (
        LucideIcons.wallet,
        'Solana Devnet',
        'Solana Devnet',
        'Сеть для проверки отпечатка и версий сейфа.',
        'Network for checking the vault fingerprint and versions.',
      ),
    };
    return _SettingsFrame(
      desktopPanelHeight: 550,
      title: tr(context, 'Настройки', 'Settings'),
      subtitle: tr(
        context,
        'Контроль доступа, оформления и сетевых операций в одном месте.',
        'Access, appearance, and network controls in one place.',
      ),
      heroIcon: icon,
      heroTitle: tr(context, titleRu, titleEn),
      heroDescription: tr(context, descRu, descEn),
      onBack: _back,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(tr(context, 'Сетевые сведения', 'Network details')),
          const SizedBox(height: 13),
          _detailsCard([
            (tr(context, 'Сеть', 'Network'), 'Devnet'),
            (
              tr(context, 'Адрес', 'Address'),
              configured
                  ? _shortAddress(owner)
                  : tr(context, 'Не настроен', 'Not configured'),
            ),
            (tr(context, 'Баланс', 'Balance'), _balance ?? '—'),
          ]),
          const SizedBox(height: 14),
          if (stage == _DevnetStage.pending) ...[
            LinearProgressIndicator(color: VaultColors.of(context).gold),
            const SizedBox(height: 14),
          ],
          _notice(
            tr(
              context,
              switch (stage) {
                _DevnetStage.pending =>
                  'Запрос тестовых SOL может занять некоторое время.',
                _DevnetStage.success =>
                  'Тестовые SOL зачислены на Devnet-адрес.',
                _DevnetStage.offline =>
                  'Операции с Solana требуют подключения к интернету.',
                _DevnetStage.limit =>
                  'Devnet ограничивает частоту запросов тестовых SOL.',
                _DevnetStage.error =>
                  'Сведения не обновились. Данные сейфа не затронуты.',
                _ => 'Для проверки нужен доступный Devnet-адрес и баланс SOL.',
              },
              switch (stage) {
                _DevnetStage.pending =>
                  'Requesting test SOL may take a moment.',
                _DevnetStage.success =>
                  'Test SOL was added to your Devnet address.',
                _DevnetStage.offline =>
                  'Solana operations require an internet connection.',
                _DevnetStage.limit =>
                  'Devnet limits how often test SOL can be requested.',
                _DevnetStage.error =>
                  'Details were not updated. Vault data was not changed.',
                _ => 'Verification needs a Devnet address with SOL balance.',
              },
            ),
            stage == _DevnetStage.success
                ? LucideIcons.circleCheck
                : stage == _DevnetStage.offline
                ? LucideIcons.wifiOff
                : LucideIcons.info,
            success: stage == _DevnetStage.success,
            warning: stage == _DevnetStage.limit || stage == _DevnetStage.error,
          ),
          const SizedBox(height: 15),
          if (stage == _DevnetStage.success)
            FilledButton(
              onPressed: _back,
              child: Text(tr(context, 'Готово', 'Done')),
            )
          else if (stage == _DevnetStage.balance) ...[
            FilledButton.icon(
              onPressed: _chainBusy ? null : _airdrop,
              icon: const Icon(LucideIcons.sparkles, size: 17),
              label: Text(
                tr(context, 'Запросить Devnet-SOL', 'Request Devnet SOL'),
              ),
            ),
            const SizedBox(height: 9),
            OutlinedButton(
              onPressed: _chainBusy ? null : _loadBalance,
              child: Text(tr(context, 'Обновить баланс', 'Refresh balance')),
            ),
          ] else if (stage != _DevnetStage.pending)
            FilledButton.icon(
              onPressed: _chainBusy || !configured ? null : _loadBalance,
              icon: const Icon(LucideIcons.refreshCw, size: 17),
              label: Text(tr(context, 'Обновить сведения', 'Refresh details')),
            ),
          const SizedBox(height: 17),
          Text(
            tr(
              context,
              'В Devnet хранится только SHA-256 хеш зашифрованного файла и номер версии.',
              'Devnet stores only the encrypted file SHA-256 hash and its version.',
            ),
            style: TextStyle(
              color: VaultColors.of(context).muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _shortAddress(String address) => address.length <= 12
      ? address
      : '${address.substring(0, 4)}...${address.substring(address.length - 3)}';

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: VaultColors.of(context).muted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );

  Widget _heading(String text) => Text(
    text,
    style: TextStyle(
      color: VaultColors.of(context).ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _entry({
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) {
    final colors = VaultColors.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 65),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(LucideIcons.chevronRight, color: colors.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice({
    required IconData icon,
    required String title,
    String? description,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final colors = VaultColors.of(context);
    return Material(
      color: selected ? colors.goldSoft : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? colors.gold.withValues(alpha: .55)
                  : colors.line,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                color: selected ? colors.gold : colors.muted,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    final colors = VaultColors.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.goldSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: colors.gold, size: 18),
    );
  }

  Widget _notice(
    String message,
    IconData icon, {
    bool warning = false,
    bool success = false,
  }) {
    final colors = VaultColors.of(context);
    final accent = success
        ? colors.success
        : warning
        ? colors.warning
        : colors.gold;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warning ? colors.goldSoft : colors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.ink, fontSize: 11, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(List<(String, String)> rows) {
    final colors = VaultColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    rows[index].$1,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[index].$2,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < rows.length - 1) Divider(height: 1, color: colors.line),
          ],
        ],
      ),
    );
  }
}

class _SettingsFrame extends StatelessWidget {
  const _SettingsFrame({
    required this.title,
    required this.subtitle,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroDescription,
    required this.content,
    required this.onBack,
    required this.desktopPanelHeight,
    this.showDesktopBack = true,
  });

  final String title;
  final String subtitle;
  final IconData heroIcon;
  final String heroTitle;
  final String heroDescription;
  final Widget content;
  final VoidCallback onBack;
  final bool showDesktopBack;
  final double desktopPanelHeight;

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
                if (mobile)
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
                  )
                else ...[
                  if (showDesktopBack)
                    TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: Text(
                        tr(context, 'К настройкам', 'Back to settings'),
                      ),
                    ),
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
                ],
                SizedBox(height: mobile ? 24 : 18),
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
                  SizedBox(
                    height: desktopPanelHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _panel(
                            context,
                            SingleChildScrollView(child: content),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 2,
                          child: _panel(
                            context,
                            const Center(child: SettingsIllustration()),
                            soft: true,
                          ),
                        ),
                      ],
                    ),
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
    if (flat) return child;
    final colors = VaultColors.of(context);
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
