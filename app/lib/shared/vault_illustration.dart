// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Векторная иллюстрация по мотивам Windows V3: золотая дужка,
/// тёмный корпус и парящие карточки. Никаких внешних изображений.
class VaultIllustration extends StatefulWidget {
  const VaultIllustration({super.key});

  @override
  State<VaultIllustration> createState() => _VaultIllustrationState();
}

class _VaultIllustrationState extends State<VaultIllustration>
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
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.05, -.25),
          radius: 1.05,
          colors: [colors.goldSoft.withValues(alpha: .65), colors.soft],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 310,
            height: 285,
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) {
                final wave = reduceMotion
                    ? 0.0
                    : math.sin(_motion.value * math.pi);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final diameter in [262.0, 218.0, 174.0])
                      Container(
                        width: diameter,
                        height: diameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.gold.withValues(alpha: .12),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 17,
                      child: Container(
                        width: 164,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .13),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -wave * 5),
                      child: const _LockArt(),
                    ),
                    Positioned(
                      left: 4,
                      top: 85 - wave * 5,
                      child: Transform.rotate(
                        angle: -.16,
                        child: _FloatingCard(
                          colors: colors,
                          icon: LucideIcons.keyRound,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 3,
                      bottom: 71 + wave * 5,
                      child: Transform.rotate(
                        angle: .13,
                        child: _FloatingCard(
                          colors: colors,
                          icon: LucideIcons.shieldCheck,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            tr(context, 'Доступ только вам.', 'Access for you alone.'),
            style: TextStyle(
              color: colors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr(
              context,
              'Шифрование работает без подключения к сети.',
              'Encryption works without an internet connection.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LockArt extends StatelessWidget {
  const _LockArt();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    height: 216,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 7,
          child: Container(
            width: 102,
            height: 147,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE8A6),
                  Color(0xFFD4A74D),
                  Color(0xFF8D662D),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(58),
                bottom: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .19),
                  blurRadius: 10,
                  offset: const Offset(3, 5),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 65,
                height: 110,
                decoration: BoxDecoration(
                  color: VaultColors.of(context).soft,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(42),
                    bottom: Radius.circular(7),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 3,
          child: Container(
            width: 154,
            height: 119,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF32373A),
                  Color(0xFF181B1D),
                  Color(0xFF111315),
                ],
              ),
              border: Border.all(color: const Color(0xFF98783E), width: 2.5),
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .22),
                  blurRadius: 16,
                  offset: const Offset(5, 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 71,
                height: 71,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9D7A3F)),
                ),
                child: Center(
                  child: Container(
                    width: 47,
                    height: 47,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE4A2), Color(0xFFBE8832)],
                      ),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(24, 28),
                        painter: _KeyholePainter(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _KeyholePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF35291C);
    canvas.drawCircle(Offset(size.width / 2, 9), 5.5, ink);
    final stem = Path()
      ..moveTo(size.width / 2 - 3, 11)
      ..lineTo(size.width / 2 + 3, 11)
      ..lineTo(size.width / 2 + 5, 26)
      ..lineTo(size.width / 2 - 5, 26)
      ..close();
    canvas.drawPath(stem, ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.colors, required this.icon});

  final VaultColors colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 74,
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.line),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .08),
          blurRadius: 12,
          offset: const Offset(2, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: colors.gold, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(height: 2, color: colors.gold.withValues(alpha: .65)),
              const SizedBox(height: 5),
              Container(height: 2, color: colors.line),
            ],
          ),
        ),
      ],
    ),
  );
}
