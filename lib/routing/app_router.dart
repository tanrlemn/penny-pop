import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/screens/activity_screen.dart';
import 'package:penny_pop_app/screens/coach_screen.dart';
import 'package:penny_pop_app/screens/home_screen.dart';
import 'package:penny_pop_app/screens/pods_screen.dart';
import 'package:penny_pop_app/screens/settings_screen.dart';
import 'package:penny_pop_app/shell/app_shell.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
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


