// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class StatusLabel extends StatelessWidget {
  const StatusLabel({required this.message, this.error = true, super.key});

  final String? message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final tone = error ? colors.danger : colors.success;
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -.1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Container(
              key: ValueKey(message),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: .09),
                border: Border.all(color: tone.withValues(alpha: .3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    error ? LucideIcons.circleAlert : LucideIcons.circleCheck,
                    color: tone,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(color: tone, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
