import 'package:flutter/material.dart';
import 'package:penny_pop_app/app/penny_pop_app.dart';
import 'package:penny_pop_app/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = Env.supabaseUrl;
  final supabaseKey = Env.supabaseKey;
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw Exception(
      'Missing Supabase config. Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
      'via --dart-define.',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(const PennyPopApp());
}
