import 'package:flutter_test/flutter_test.dart';
import 'package:captrio/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CaptrioApp());
    expect(find.byType(CaptrioApp), findsOneWidget);
  });
}