import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Redirect по vaultSessionProvider добавляется в AK-13
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _PlaceholderScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Anchorkeep')));
  }
}
