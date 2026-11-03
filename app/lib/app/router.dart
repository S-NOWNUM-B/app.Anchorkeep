import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/features/onboarding/access_screens.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/features/vault/entry_screens.dart';
import 'package:anchorkeep/features/vault/backup_screen.dart';
import 'package:anchorkeep/features/vault/settings_screen.dart';
import 'package:anchorkeep/shared/vault_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(vaultSessionProvider, (_, _) => refresh.value++);
  ref.listen(hasVaultProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final hasVault = ref.read(hasVaultProvider);
      final session = ref.read(vaultSessionProvider);
      final path = state.uri.path;
      if (hasVault.isLoading) return path == '/' ? null : '/';
      final exists = hasVault.asData?.value ?? false;
      if (path == '/') return exists ? '/unlock' : '/welcome';
      if (session != null) {
        if (path == '/welcome' || path == '/create' || path == '/unlock') {
          return '/passwords';
        }
        return null;
      }
      if (path == '/restore') return null;
      if (!exists) {
        return path == '/welcome' || path == '/create' ? null : '/welcome';
      }
      return path == '/unlock' ? null : '/unlock';
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => _page(state, const _LoadingScreen()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, state) => _page(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/create',
        pageBuilder: (_, state) => _page(state, const CreateVaultScreen()),
      ),
      GoRoute(
        path: '/unlock',
        pageBuilder: (_, state) => _page(state, const UnlockScreen()),
      ),
      GoRoute(
        path: '/restore',
        pageBuilder: (_, state) => _page(state, const RestoreScreen()),
      ),
      GoRoute(
        path: '/passwords',
        pageBuilder: (_, state) => _page(
          state,
          const VaultShell(
            section: VaultSection.passwords,
            child: EntryScreen(type: EntryType.password),
          ),
        ),
      ),
      GoRoute(
        path: '/notes',
        pageBuilder: (_, state) => _page(
          state,
          const VaultShell(
            section: VaultSection.notes,
            child: EntryScreen(type: EntryType.note),
          ),
        ),
      ),
      GoRoute(
        path: '/backup',
        pageBuilder: (_, state) => _page(
          state,
          const VaultShell(section: VaultSection.backup, child: BackupScreen()),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _page(
          state,
          const VaultShell(
            section: VaultSection.settings,
            child: SettingsScreen(),
          ),
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 190),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.of(context).disableAnimations) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
