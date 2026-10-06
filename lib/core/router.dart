import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_create_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/recovery_screen.dart';
import '../features/detail/detail_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/finished/finished_screen.dart';
import '../features/home/home_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/settings/delete_account_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/submit/submit_screen.dart';
import '../widgets/common.dart';

final router = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const _RouteNotFoundScreen(),
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/explore', builder: (context, state) => const ExploreScreen()),
        GoRoute(path: '/finished', builder: (context, state) => const FinishedScreen()),
        GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: '/submit', builder: (context, state) => const SubmitScreen()),
        GoRoute(path: '/opportunity/:id', builder: (context, state) => DetailScreen(id: state.pathParameters['id']!)),
      ],
    ),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/auth/recovery', builder: (context, state) => const RecoveryScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
    GoRoute(path: '/account/delete', builder: (context, state) => const DeleteAccountScreen()),
    GoRoute(path: '/legal/:kind', builder: (context, state) => LegalScreen(kind: state.pathParameters['kind']!)),
    GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
    GoRoute(path: '/admin/new', builder: (context, state) => const AdminCreateScreen()),
    GoRoute(path: '/admin/edit/:id', builder: (context, state) => AdminCreateScreen(opportunityId: state.pathParameters['id']!)),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(String location) {
    if (location.startsWith('/explore') || location.startsWith('/finished')) return 1;
    if (location.startsWith('/submit')) return 2;
    if (location.startsWith('/saved')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        return;
      case 1:
        context.go('/explore');
        return;
      case 2:
        context.go('/submit');
        return;
      case 3:
        context.go('/saved');
        return;
      case 4:
        context.go('/profile');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _selectedIndex(location);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 920;
    final extraWide = width >= 1240;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              minWidth: 78,
              minExtendedWidth: 196,
              extended: extraWide,
              selectedIndex: selected,
              onDestinationSelected: (index) => _go(context, index),
              leading: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: OportuLogo(compact: !extraWide)),
              labelType: extraWide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Inicio')),
                NavigationRailDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: Text('Explorar')),
                NavigationRailDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: Text('Publicar')),
                NavigationRailDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: Text('Guardadas')),
                NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Perfil')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1320), child: child),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => _go(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Guardadas'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const OportuLogo()),
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Esta página no existe',
        body: 'El enlace puede estar incompleto o la página puede haber cambiado.',
        action: FilledButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Volver a inicio'),
        ),
      ),
    );
  }
}
