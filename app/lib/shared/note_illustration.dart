// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Лёгкая иллюстрация листов из макета Notes, собранная из Flutter-виджетов.
class NoteIllustration extends StatefulWidget {
  const NoteIllustration({this.compact = false, super.key});

  final bool compact;

  @override
  State<NoteIllustration> createState() => _NoteIllustrationState();
}

class _NoteIllustrationState extends State<NoteIllustration>
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
        SizedBox(
          width: widget.compact ? 132 : 182,
          height: widget.compact ? 112 : 158,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final dy = reduceMotion
                  ? 0.0
                  : math.sin(_motion.value * math.pi) * 4;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(-17, 8),
                    child: Transform.rotate(
                      angle: -.13,
                      child: _paper(colors, false),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(12, -dy),
                    child: Transform.rotate(
                      angle: .10,
                      child: _paper(colors, true),
                    ),
                  ),
                  Positioned(left: 8, top: 28, child: _dot(colors.gold, 5)),
                  Positioned(
                    right: 10,
                    bottom: 29,
                    child: _dot(colors.gold, 6),
                  ),
                ],
              );
            },
          ),
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 14),
          Text(
            tr(context, 'Ваш текст. Ваши правила.', 'Your text. Your rules.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr(
              context,
              'Никаких аккаунтов, облака или сервера. Приватные записи остаются внутри.',
              'No accounts, cloud or server. Private notes stay here.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 11, height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _paper(VaultColors colors, bool front) => Container(
    width: widget.compact ? 82 : 110,
    height: widget.compact ? 94 : 128,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border.all(
        color: colors.gold.withValues(alpha: front ? .6 : .24),
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(11),
      boxShadow: [
        BoxShadow(
          color: colors.gold.withValues(alpha: .12),
          blurRadius: 12,
          offset: const Offset(3, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.plus, color: colors.gold, size: 15),
        const SizedBox(height: 10),
        for (final width in [.9, .7, .85]) ...[
          FractionallySizedBox(
            widthFactor: width,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: .34),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );

  Widget _dot(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .7),
      shape: BoxShape.circle,
    ),
  );
}
