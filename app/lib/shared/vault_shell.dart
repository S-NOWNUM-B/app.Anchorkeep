// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/security/auto_lock_scope.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/shared/access_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

enum VaultSection { passwords, notes, backup, settings }

class VaultShell extends ConsumerWidget {
  const VaultShell({required this.section, required this.child, super.key});

  final VaultSection section;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final timeout = Duration(minutes: ref.watch(autoLockMinutesProvider));
    final colors = VaultColors.of(context);
    final desktop = MediaQuery.sizeOf(context).width >= 820;

    return AutoLockScope(
      timeout: timeout,
      onLock: () => ref.read(vaultSessionProvider.notifier).lock(),
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          child: desktop
              ? Row(
                  children: [
                    SizedBox(width: 220, child: _Sidebar(section: section)),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 61,
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border(
                                bottom: BorderSide(color: colors.line),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Spacer(),
                                LanguageButton(),
                                SizedBox(width: 8),
                                ThemeButton(),
                              ],
                            ),
                          ),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    if (section != VaultSection.passwords &&
                        !((section == VaultSection.notes ||
                                section == VaultSection.backup ||
                                section == VaultSection.settings) &&
                            MediaQuery.sizeOf(context).width < 600))
                      Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: colors.canvas,
                          border: Border(
                            bottom: BorderSide(color: colors.line),
                          ),
                        ),
                        child: Row(
                          children: [
                            VaultBrand(
                              compact: true,
                              showName: MediaQuery.sizeOf(context).width >= 380,
                            ),
                            const Spacer(),
                            const LanguageButton(),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: tr(context, 'Заблокировать', 'Lock'),
                              onPressed: () => ref
                                  .read(vaultSessionProvider.notifier)
                                  .lock(),
                              icon: const Icon(
                                LucideIcons.lockKeyhole,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(child: child),
                    _BottomNav(section: section),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.section});

  final VaultSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = VaultColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 9, bottom: 34),
            child: VaultBrand(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9, bottom: 12),
            child: Text(
              tr(context, 'РАЗДЕЛЫ', 'WORKSPACE'),
              style: TextStyle(
                color: colors.muted,
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final value in VaultSection.values)
            _NavItem(value: value, selected: value == section),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 15, color: colors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(context, 'Только на устройстве', 'On this device only'),
                    style: TextStyle(color: colors.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
              icon: const Icon(LucideIcons.lockKeyhole, size: 17),
              label: Text(tr(context, 'Заблокировать', 'Lock vault')),
              style: ButtonStyle(
                alignment: Alignment.centerLeft,
                foregroundColor: WidgetStatePropertyAll(colors.ink),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.goldSoft
                      : colors.soft,
                ),
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color:
                        states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.gold
                        : colors.line,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.value, required this.selected});

  final VaultSection value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final meta = _navMeta(context, value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? colors.goldSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => context.go(meta.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  meta.icon,
                  size: 18,
                  color: selected ? colors.gold : colors.muted,
                ),
                const SizedBox(width: 12),
                Text(
                  meta.label,
                  style: TextStyle(
                    color: selected ? colors.ink : colors.muted,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.section});

  final VaultSection section;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          for (final value in VaultSection.values)
            Expanded(
              child: Builder(
                builder: (context) {
                  final meta = _navMeta(context, value);
                  final selected = value == section;
                  return InkWell(
                    onTap: () => context.go(meta.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.goldSoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            meta.icon,
                            size: 18,
                            color: selected ? colors.gold : colors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? colors.gold : colors.muted,
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

({String path, String label, IconData icon}) _navMeta(
  BuildContext context,
  VaultSection section,
) => switch (section) {
  VaultSection.passwords => (
    path: '/passwords',
    label: tr(context, 'Пароли', 'Passwords'),
    icon: LucideIcons.keyRound,
  ),
  VaultSection.notes => (
    path: '/notes',
    label: tr(context, 'Заметки', 'Notes'),
    icon: LucideIcons.notebookPen,
  ),
  VaultSection.backup => (
    path: '/backup',
    label: tr(context, 'Бэкап', 'Backup'),
    icon: LucideIcons.rotateCcw,
  ),
  VaultSection.settings => (
    path: '/settings',
    label: tr(context, 'Настройки', 'Settings'),
    icon: LucideIcons.settings2,
  ),
};
