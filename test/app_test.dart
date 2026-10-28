import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocalc/neocalc_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('calculates with precedence and opens the converter', (tester) async {
    await tester.pumpWidget(const NeoCalcApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('2'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('×'));
    await tester.tap(find.text('4'));
    await tester.tap(find.widgetWithText(GestureDetector, '='));
    await tester.pumpAndSettle();
    expect(find.text('14'), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit Converter'));
    await tester.pumpAndSettle();
    expect(find.text('Unit Converter'), findsOneWidget);
  });
}