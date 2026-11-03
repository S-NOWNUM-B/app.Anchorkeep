// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Иллюстрация локальных настроек для правой колонки Windows V3.
class SettingsIllustration extends StatefulWidget {
  const SettingsIllustration({super.key});

  @override
  State<SettingsIllustration> createState() => _SettingsIllustrationState();
}

class _SettingsIllustrationState extends State<SettingsIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 208,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [colors.goldSoft, colors.soft],
              radius: 1.2,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final dy = reduceMotion
                  ? 0.0
                  : math.sin(_motion.value * math.pi) * 4;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 172,
                    height: 172,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.gold.withValues(alpha: .23),
                      ),
                    ),
                  ),
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.gold.withValues(alpha: .16),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -dy),
                    child: Container(
                      width: 112,
                      height: 122,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(
                          color: colors.gold.withValues(alpha: .48),
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: colors.gold.withValues(alpha: .13),
                            blurRadius: 17,
                            offset: const Offset(3, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.settings2,
                            color: colors.gold,
                            size: 28,
                          ),
                          const SizedBox(height: 13),
                          for (final alignedRight in [true, false, true]) ...[
                            Row(
                              children: [
                                Container(
                                  width: 31,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: colors.line,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 19,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: alignedRight
                                        ? colors.gold
                                        : colors.goldSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Align(
                                    alignment: alignedRight
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    top: 42,
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 17,
                      color: colors.gold,
                    ),
                  ),
                  Positioned(
                    left: 35,
                    bottom: 42,
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 20,
                      color: colors.gold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          tr(context, 'Всё остаётся локально', 'Everything stays local'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Пароли, заметки и мастер-пароль не передаются в Solana Devnet.',
            'Passwords, notes, and your master password never go to Solana Devnet.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.shieldCheck, color: colors.gold, size: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'Данные под вашим контролем',
                    'Your data stays under your control',
                  ),
                  style: TextStyle(color: colors.ink, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
