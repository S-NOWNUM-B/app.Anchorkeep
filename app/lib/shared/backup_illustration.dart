// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Иллюстрация зашифрованного файла для Windows V3.
class BackupIllustration extends StatefulWidget {
  const BackupIllustration({super.key});

  @override
  State<BackupIllustration> createState() => _BackupIllustrationState();
}

class _BackupIllustrationState extends State<BackupIllustration>
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
              radius: 1.25,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final dy = reduceMotion
                  ? 0.0
                  : math.sin(_motion.value * math.pi) * 5;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 166,
                    height: 166,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.gold.withValues(alpha: .28),
                      ),
                    ),
                  ),
                  Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.gold.withValues(alpha: .18),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -dy),
                    child: Container(
                      width: 100,
                      height: 130,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(
                          color: colors.gold.withValues(alpha: .55),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: colors.gold.withValues(alpha: .15),
                            blurRadius: 18,
                            offset: const Offset(5, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 13),
                          Icon(
                            LucideIcons.fileLock2,
                            color: colors.gold,
                            size: 38,
                          ),
                          const SizedBox(height: 10),
                          for (final width in [53.0, 39.0, 48.0]) ...[
                            Container(
                              width: width,
                              height: 3,
                              decoration: BoxDecoration(
                                color: colors.gold.withValues(alpha: .38),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 43,
                    top: 69,
                    child: Transform.rotate(
                      angle: -.23,
                      child: Container(
                        width: 37,
                        height: 26,
                        decoration: BoxDecoration(
                          color: colors.elevated,
                          border: Border.all(color: colors.line),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 43,
                    bottom: 55,
                    child: Icon(
                      LucideIcons.sparkles,
                      color: colors.gold,
                      size: 16,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          tr(
            context,
            'Ваши данные под контролем',
            'Your data under your control',
          ),
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
            'Блокчейн хранит только цифровой отпечаток зашифрованного файла и номер его версии.',
            'The blockchain stores only the encrypted file fingerprint and its version.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, fontSize: 11, height: 1.45),
        ),
      ],
    );
  }
}
