import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/screens/activity_screen.dart';
import 'package:penny_pop_app/screens/coach_screen.dart';
import 'package:penny_pop_app/screens/home_screen.dart';
import 'package:penny_pop_app/screens/login_screen.dart';
import 'package:penny_pop_app/screens/pods_screen.dart';
import 'package:penny_pop_app/screens/settings_screen.dart';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/pods',
                builder: (context, state) => const PodsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/coach',
                builder: (context, state) => const CoachScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
