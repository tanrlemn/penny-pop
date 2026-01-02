import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/design/glass/glass_platform_accessibility.dart';
import 'package:penny_pop_app/households/household_service.dart';
import 'package:penny_pop_app/routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PennyPopApp extends StatefulWidget {
  const PennyPopApp({super.key});

  @override
  State<PennyPopApp> createState() => _PennyPopAppState();
}

class _PennyPopAppState extends State<PennyPopApp> {
  late final SupabaseAuthNotifier _authNotifier;
  late final ActiveHouseholdController _householdController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authNotifier = SupabaseAuthNotifier();
    _householdController = ActiveHouseholdController();
    _router = createAppRouter(refreshListenable: _authNotifier);
  }

  @override
  void dispose() {
    _householdController.dispose();
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PennyPopScope(
      household: _householdController,
      child: ValueListenableBuilder<bool>(
        valueListenable: GlassPlatformAccessibility.reduceTransparencyEnabled,
        builder: (context, reduceTransparencyEnabled, _) {
          return CupertinoApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Penny Pixel Pop',
            theme: const CupertinoThemeData(
              primaryColor: CupertinoColors.systemPurple,
              // Let brightness follow the system; glass tokens resolve from
              // CupertinoTheme/MediaQuery.
            ),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const <Locale>[
              Locale('en', 'US'),
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class SupabaseAuthNotifier extends ChangeNotifier {
  SupabaseAuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}


