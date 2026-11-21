import 'dart:typed_data';

import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/solana/vault_keypair.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/core/vault/vault_file.dart';
import 'package:anchorkeep/features/vault/restore_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

KdfParams _fast() => KdfParams(
  memoryKiB: 1024,
  iterations: 1,
  parallelism: 1,
  salt: randomBytes(16),
);

Future<VaultSession> _session() async {
  final s = await createVault('pw', kdf: _fast());
  await ensureSolanaSection(s.payload);
  return s;
}

/// Один сейф: бэкап версии 2 (байты) и «файл на устройстве» версии 5
/// (заголовок); плюс заголовок чужого сейфа.
Future<({Uint8List backup, VaultHeader disk, VaultHeader other})>
_vaults() async {
  final s = await _session();
  await saveVault(s);
  final older = await saveVault(s);
  for (var i = 0; i < 2; i++) {
    await saveVault(s);
  }
  final newer = await saveVault(s);
  final o = await _session();
  final other = await saveVault(o);
  VaultHeader h(Uint8List b) => VaultFile.decode(b).header;
  return (backup: older, disk: h(newer), other: h(other));
}

/// Бэкап версии 2 открыт на шаге пароля; [disk] — что лежит на устройстве
/// (`null` — сейфа нет). Сессия приложения закрыта, как на экране входа.
Future<void> _toConfirmStep(
  WidgetTester tester, {
  required Uint8List backup,
  required VaultHeader? disk,
  required double width,
}) async {
  // Argon2 и подготовка данных идут в настоящем времени, а не в фейковом.
  final session = (await tester.runAsync(_session))!;
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: VaultRestoreFlow(
            initialBytes: backup,
            unlockBackup: (b, password) async => session,
            fetchRecord: (owner, vaultId) async => null,
            currentHeader: () async => disk,
          ),
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), 'pw');
  await tester.tap(find.text('Check file'));
  // На десктопе есть бесконечная декоративная анимация, поэтому не
  // pumpAndSettle, а фиксированное число кадров.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// Язык в тестах английский: `tr` выбирает текст по локали MaterialApp.
void main() {
  for (final width in [400.0, 1100.0]) {
    group('восстановление при закрытом сейфе (ширина ${width.toInt()})', () {
      testWidgets(
        'бэкап старее сейфа на диске → предупреждение о потере записей',
        (tester) async {
          final h = (await tester.runAsync(_vaults))!;
          await _toConfirmStep(
            tester,
            backup: h.backup,
            disk: h.disk,
            width: width,
          );
          expect(find.textContaining('older than the vault'), findsOneWidget);
          expect(find.textContaining('will be created'), findsNothing);
          // в строке «Текущая ревизия» версия сейфа на диске (5), а не «—»
          expect(find.text('5'), findsOneWidget);
        },
      );

      testWidgets('на диске другой сейф → предупреждение о полной замене', (
        tester,
      ) async {
        final h = (await tester.runAsync(_vaults))!;
        await _toConfirmStep(
          tester,
          backup: h.backup,
          disk: h.other,
          width: width,
        );
        expect(find.textContaining('different vault'), findsOneWidget);
        expect(find.textContaining('will be created'), findsNothing);
      });

      testWidgets('сейфа на диске нет → создаётся новый', (tester) async {
        final h = (await tester.runAsync(_vaults))!;
        await _toConfirmStep(
          tester,
          backup: h.backup,
          disk: null,
          width: width,
        );
        expect(find.textContaining('will be created'), findsOneWidget);
      });
    });
  }
}
