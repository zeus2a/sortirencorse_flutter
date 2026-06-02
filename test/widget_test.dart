import 'package:flutter_test/flutter_test.dart';
import 'package:sortirencorse_pro/main.dart';

void main() {
  testWidgets('App should launch', (WidgetTester tester) async {
    await tester.pumpWidget(const SortirEnCorseApp());
    expect(find.text('SORTIR EN CORSE'), findsOneWidget);
  });
}
