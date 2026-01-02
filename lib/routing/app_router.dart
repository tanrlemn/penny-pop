import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/screens/coach_screen.dart';
import 'package:penny_pop_app/screens/home_screen.dart';
import 'package:penny_pop_app/screens/login_screen.dart';
import 'package:penny_pop_app/screens/pods_screen.dart';
import 'package:penny_pop_app/screens/splash_screen.dart';
import 'package:penny_pop_app/shell/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

GoRouter createAppRouter({required Listenable refreshListenable}) {
  final supabase = Supabase.instance.client;

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublic = path == '/splash' || path == '/login';
      final isLoggedIn = supabase.auth.currentSession != null;

      if (!isLoggedIn && !isPublic) return '/login';
      if (isLoggedIn && path == '/login') return '/';

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/coach', redirect: (context, state) => '/guide'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/pods',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const PodsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/guide',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const CoachScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
