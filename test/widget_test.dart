import 'package:flutter_test/flutter_test.dart';
import 'package:maison_al_teeb_pos/main.dart';

void main() {
  testWidgets('Maison Al Teeb app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaisonAlTeebApp());
    expect(find.text('MAISON AL TEEB'), findsWidgets);
  });
}
