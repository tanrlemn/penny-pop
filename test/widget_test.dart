import 'package:flutter_test/flutter_test.dart';

import 'package:penny_pop_app/app/penny_pop_app.dart';

void main() {
  testWidgets('Bottom tabs navigate between placeholder screens', (WidgetTester tester) async {
    await tester.pumpWidget(const PennyPopApp());
    await tester.pumpAndSettle();

    expect(find.text('Home Screen'), findsOneWidget);

    await tester.tap(find.text('Pods'));
    await tester.pumpAndSettle();
    expect(find.text('Pods Screen'), findsOneWidget);

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Coach Screen'), findsOneWidget);

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity Screen'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings Screen'), findsOneWidget);
  });
}
