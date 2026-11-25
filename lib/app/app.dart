import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/vault/vault_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const VaultScreen())],
  );
  ref.onDispose(router.dispose);
  return router;
});

class MirrorDnaApp extends ConsumerWidget {
  const MirrorDnaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MirrorDNA',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff121214),
      ),
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
