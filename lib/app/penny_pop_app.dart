import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PennyPopApp extends StatefulWidget {
  const PennyPopApp({super.key});

  @override
  State<PennyPopApp> createState() => _PennyPopAppState();
}

class _PennyPopAppState extends State<PennyPopApp> {
  late final SupabaseAuthNotifier _authNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authNotifier = SupabaseAuthNotifier();
    _router = createAppRouter(refreshListenable: _authNotifier);
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.deepPurple;
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Penny Pop',
      theme: ThemeData(colorScheme: lightColorScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkColorScheme, useMaterial3: true),
      themeMode: ThemeMode.system,
      routerConfig: _router,
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


