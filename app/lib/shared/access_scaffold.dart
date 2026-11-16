// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/preferences.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/shared/vault_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class VaultBrand extends StatelessWidget {
  const VaultBrand({super.key, this.compact = false, this.showName = true});

  final bool compact;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 40,
          height: compact ? 32 : 40,
          decoration: BoxDecoration(
            color: colors.goldSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            LucideIcons.shieldCheck,
            size: compact ? 18 : 23,
            color: colors.gold,
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 9),
          Text(
            'CipherVault',
            style: TextStyle(
              color: colors.ink,
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
            ),
          ),
        ],
      ],
    );
  }
}

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key, this.subtle = false});

  final bool subtle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final colors = VaultColors.of(context);
    return OutlinedButton(
      onPressed: () => ref.read(languageProvider.notifier).toggle(),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: subtle ? Colors.transparent : colors.line),
        backgroundColor: subtle ? colors.soft : null,
        foregroundColor: colors.muted,
        tapTargetSize: subtle ? MaterialTapTargetSize.shrinkWrap : null,
        minimumSize: Size(0, subtle ? 30 : 35),
        padding: EdgeInsets.symmetric(horizontal: subtle ? 9 : 10),
      ),
      child: Text(
        locale.languageCode == 'ru' ? 'RU / EN' : 'EN / RU',
        style: TextStyle(fontSize: subtle ? 10 : 11),
      ),
    );
  }
}

class ThemeButton extends ConsumerWidget {
  const ThemeButton({super.key, this.subtle = false});

  final bool subtle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final colors = VaultColors.of(context);
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return IconButton.outlined(
      tooltip: isDark
          ? tr(context, 'Включить светлую тему', 'Switch to light theme')
          : tr(context, 'Включить тёмную тему', 'Switch to dark theme'),
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .setMode(isDark ? ThemeMode.light : ThemeMode.dark),
      style: IconButton.styleFrom(
        backgroundColor: subtle ? colors.soft : null,
        tapTargetSize: subtle ? MaterialTapTargetSize.shrinkWrap : null,
        minimumSize: Size(subtle ? 30 : 35, subtle ? 30 : 35),
        maximumSize: Size(subtle ? 30 : 35, subtle ? 30 : 35),
        padding: EdgeInsets.zero,
        side: BorderSide(color: subtle ? Colors.transparent : colors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: AnimatedSwitcher(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Icon(
          isDark ? LucideIcons.sun : LucideIcons.moon,
          key: ValueKey(isDark),
          size: 17,
          color: colors.muted,
        ),
      ),
    );
  }
}

/// Оболочка входа: широкая иллюстрация слева на Windows и одна колонка
/// на Android, как в Windows V3 и Stage 01 Figma.
class AccessScaffold extends StatelessWidget {
  const AccessScaffold({required this.child, this.mobileHeader, super.key});

  final Widget child;
  final Widget? mobileHeader;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 950 && size.height >= 520;
    final gutter = VaultLayout.gutter(size.width);
    final form = Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 32 : gutter,
            vertical: size.height < 650 ? 12 : 20,
          ),
          child: desktop || mobileHeader == null
              ? Row(
                  children: [
                    VaultBrand(compact: true, showName: size.width >= 380),
                    const Spacer(),
                    const LanguageButton(),
                    const SizedBox(width: 8),
                    const ThemeButton(),
                  ],
                )
              : mobileHeader!,
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                desktop ? 32 : gutter,
                size.height < 650 ? 12 : 20,
                desktop ? 32 : gutter,
                32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: desktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Container(
                    margin: EdgeInsets.all(size.width < 1100 ? 16 : 24),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        const Expanded(child: VaultIllustration()),
                        Expanded(child: form),
                      ],
                    ),
                  ),
                ),
              )
            : form,
      ),
    );
  }
}
