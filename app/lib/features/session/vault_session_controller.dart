// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:anchorkeep/core/vault/atomic_write.dart';
import 'package:anchorkeep/core/security/clipboard_guard.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Путь можно заменить в тестах, не поднимая платформенный плагин.
final vaultPathProvider = FutureProvider<String>((ref) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return p.join(directory.path, 'vault.akv');
});

final hasVaultProvider = FutureProvider<bool>((ref) async {
  final path = await ref.watch(vaultPathProvider.future);
  return File(path).exists();
});

final vaultClipboard = ClipboardGuard(const SystemClipboard());

class VaultSessionController extends Notifier<VaultSession?> {
  VaultSession? _current;

  @override
  VaultSession? build() {
    ref.onDispose(() {
      _current?.close();
      unawaited(vaultClipboard.clear().catchError((Object _) {}));
    });
    return null;
  }

  Future<void> create(String password) async {
    final path = await ref.read(vaultPathProvider.future);
    if (await File(path).exists()) {
      throw StateError('vault already exists');
    }
    final session = await createVault(password);
    try {
      await writeFileAtomic(path, await saveVault(session));
      state = session;
      _current = session;
      ref.invalidate(hasVaultProvider);
    } catch (_) {
      session.close();
      rethrow;
    }
  }

  Future<void> unlock(String password) async {
    final path = await ref.read(vaultPathProvider.future);
    final session = await unlockVault(await File(path).readAsBytes(), password);
    _current?.close();
    state = session;
    _current = session;
  }

  void lock() {
    final session = _current;
    state = null;
    _current = null;
    session?.close();
    unawaited(vaultClipboard.clear().catchError((Object _) {}));
  }

  void useRestoredSession(VaultSession session) {
    _current?.close();
    unawaited(vaultClipboard.clear().catchError((Object _) {}));
    state = session;
    _current = session;
    ref.invalidate(hasVaultProvider);
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionController, VaultSession?>(
      VaultSessionController.new,
    );

final autoLockMinutesProvider = Provider<int>((ref) {
  final session = ref.watch(vaultSessionProvider);
  final settings = session?.payload['settings'];
  final value = settings is Map ? settings['autoLockMinutes'] : null;
  return value is int && value > 0 ? value : 5;
});
