import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_al_teeb_pos/main.dart';

void main() {
  testWidgets('POS app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.text('MAISON AL TEEB POS'), findsOneWidget);
  });
}
