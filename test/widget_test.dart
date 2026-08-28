import 'package:flutter_test/flutter_test.dart';
import 'package:tianride/main.dart';

void main() {
  testWidgets('TianRide app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DarmaRideApp());

    expect(find.byType(DarmaRideApp), findsOneWidget);
  });
}
