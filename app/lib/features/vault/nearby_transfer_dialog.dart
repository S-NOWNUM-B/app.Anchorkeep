// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/app/l10n.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/features/session/entries_controller.dart';
import 'package:anchorkeep/features/vault/nearby_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class NearbyTransferDialog extends ConsumerStatefulWidget {
  const NearbyTransferDialog({super.key, this.note, this.sheet = false});
  final Entry? note;
  final bool sheet;

  @override
  ConsumerState<NearbyTransferDialog> createState() =>
      _NearbyTransferDialogState();
}

class _NearbyTransferDialogState extends ConsumerState<NearbyTransferDialog>
    with SingleTickerProviderStateMixin {
  late final NearbyTransferController transfer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    transfer = NearbyTransferController(
      saveNote: (title, text) async {
        await ref.read(entriesProvider.notifier).add(EntryType.note, title, {
          'text': text,
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.note == null) {
        transfer.startReceiving();
      } else {
        transfer.startSending(widget.note!);
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    transfer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VaultColors.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 460,
        maxHeight: MediaQuery.sizeOf(context).height - 48,
      ),
      child: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: transfer,
          builder: (context, _) => Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 380 ? 18 : 26,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: colors.goldSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        LucideIcons.radio,
                        color: colors.gold,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          widget.note == null
                              ? 'Принять заметку'
                              : 'Передать заметку',
                          widget.note == null ? 'Receive note' : 'Share note',
                        ),
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: .96,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _body(context),
                ),
                const SizedBox(height: 19),
                if (transfer.stage == NearbyStage.approval)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: transfer.approve,
                      child: Text(
                        tr(
                          context,
                          'Подтвердить соединение',
                          'Confirm connection',
                        ),
                      ),
                    ),
                  ),
                if (transfer.stage == NearbyStage.received)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: transfer.acceptNote,
                      child: Text(
                        tr(context, 'Сохранить в сейф', 'Save to vault'),
                      ),
                    ),
                  ),
                if (transfer.stage == NearbyStage.success ||
                    transfer.stage == NearbyStage.error)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr(context, 'Готово', 'Done')),
                    ),
                  ),
                if (transfer.stage == NearbyStage.error &&
                    (transfer.error == 'NFC unavailable' ||
                        transfer.error == 'permission denied'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: transfer.openSettings,
                        child: Text(
                          tr(context, 'Открыть настройки', 'Open settings'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.sheet ? SafeArea(child: content) : Dialog(child: content);
  }

  Widget _body(BuildContext context) {
    final colors = VaultColors.of(context);
    final stage = transfer.stage;
    final String title;
    final String description;
    final IconData icon;
    switch (stage) {
      case NearbyStage.idle:
        title = tr(context, 'Подготовка…', 'Preparing…');
        description = tr(
          context,
          'Проверяем NFC и разрешения.',
          'Checking NFC and permissions.',
        );
        icon = LucideIcons.loaderCircle;
      case NearbyStage.waitingForTap:
        title = tr(
          context,
          'Поднесите телефоны друг к другу',
          'Hold the phones together',
        );
        description = tr(
          context,
          'Откройте CipherVault на обоих устройствах. NFC определит устройство, а заметка пойдёт по локальному каналу.',
          'Open CipherVault on both devices. NFC selects the device; the note travels over a local connection.',
        );
        icon = LucideIcons.smartphoneNfc;
      case NearbyStage.finding:
        title = tr(context, 'Ищем устройство…', 'Finding device…');
        description = tr(
          context,
          'NFC-соединение найдено. Устанавливаем локальный канал.',
          'NFC pairing found. Establishing local connection.',
        );
        icon = LucideIcons.radio;
      case NearbyStage.approval:
        title = tr(
          context,
          'Проверьте код на обоих телефонах',
          'Check the code on both phones',
        );
        description = tr(
          context,
          'Коды должны совпадать: ${transfer.authCode ?? '—'}',
          'Both codes must match: ${transfer.authCode ?? '—'}',
        );
        icon = LucideIcons.shieldCheck;
      case NearbyStage.connecting:
        title = tr(context, 'Соединяем устройства…', 'Connecting devices…');
        description = tr(
          context,
          'Не закрывайте приложение.',
          'Keep the app open.',
        );
        icon = LucideIcons.radio;
      case NearbyStage.transferring:
        title = tr(context, 'Передаём заметку…', 'Transferring note…');
        description = tr(
          context,
          'Ожидаем подтверждение на втором устройстве.',
          'Waiting for confirmation on the other device.',
        );
        icon = LucideIcons.arrowLeftRight;
      case NearbyStage.received:
        title = tr(context, 'Заметка получена', 'Note received');
        description = tr(
          context,
          '«${transfer.receivedTitle ?? ''}». Сохраните её в зашифрованный сейф.',
          '“${transfer.receivedTitle ?? ''}”. Save it into your encrypted vault.',
        );
        icon = LucideIcons.notebookPen;
      case NearbyStage.success:
        title = tr(context, 'Готово', 'Done');
        description = tr(
          context,
          transfer.sending
              ? 'Заметка сохранена на втором устройстве.'
              : 'Заметка сохранена в сейфе.',
          transfer.sending
              ? 'The note was saved on the other device.'
              : 'The note was saved in your vault.',
        );
        icon = LucideIcons.circleCheck;
      case NearbyStage.error:
        title = tr(context, 'Передача не удалась', 'Transfer failed');
        description = _errorText(context, transfer.error);
        icon = LucideIcons.circleAlert;
    }
    final active =
        stage == NearbyStage.waitingForTap ||
        stage == NearbyStage.finding ||
        stage == NearbyStage.connecting ||
        stage == NearbyStage.transferring;
    final progress =
        stage == NearbyStage.finding ||
        stage == NearbyStage.connecting ||
        stage == NearbyStage.transferring;
    return Container(
      key: ValueKey(stage),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: stage == NearbyStage.error
            ? colors.danger.withValues(alpha: .08)
            : colors.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stage == NearbyStage.error
              ? colors.danger.withValues(alpha: .3)
              : colors.line.withValues(alpha: .5),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final amount =
                    MediaQuery.of(context).disableAnimations || !active
                    ? 0.0
                    : _pulse.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (active)
                      Container(
                        width: 54 + amount * 20,
                        height: 54 + amount * 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.gold.withValues(
                              alpha: .36 - amount * .28,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: stage == NearbyStage.error
                            ? colors.danger.withValues(alpha: .12)
                            : colors.goldSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 30,
                        color: stage == NearbyStage.error
                            ? colors.danger
                            : colors.gold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.45),
          ),
          if (progress) ...[
            const SizedBox(height: 17),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: colors.line,
                color: colors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _errorText(BuildContext context, String? error) => switch (error) {
    'note too large' => tr(
      context,
      'Заметка слишком большая для передачи рядом (максимум 32 КБ).',
      'The note is too large for nearby transfer (32 KB max).',
    ),
    'permission denied' => tr(
      context,
      'Разрешите Bluetooth, Wi-Fi и геолокацию в настройках Android.',
      'Allow Bluetooth, Wi-Fi and location in Android settings.',
    ),
    'NFC unavailable' => tr(
      context,
      'Включите NFC на обоих устройствах.',
      'Enable NFC on both devices.',
    ),
    _ => tr(
      context,
      'Проверьте NFC, Bluetooth и разрешения, затем попробуйте ещё раз.',
      'Check NFC, Bluetooth and permissions, then try again.',
    ),
  };
}
