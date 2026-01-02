import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penny_pop_app/app/penny_pop_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Widget tests don't run through `main()`, so Supabase isn't initialized.
    // Use dummy values; no network calls are made unless you perform auth/db ops.
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('Login screen uses a dark Google button in dark mode',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    await tester.pumpWidget(const PennyPopApp());
    // App starts at /splash and enforces a minimum display duration.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Penny Pop'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    final background = button.style?.backgroundColor?.resolve(<WidgetState>{});
    final foreground = button.style?.foregroundColor?.resolve(<WidgetState>{});

    expect(background, const Color(0xFF131314));
    expect(foreground, Colors.white);
  });
}
