import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/main.dart';

void main() {
  testWidgets('TransitApp loads Melbourne Transit title and departures test',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TransitApp());

    // Verify that the header title 'Melbourne Transit' is present.
    expect(find.text('Melbourne Transit'), findsOneWidget);

    // Verify that live departures section is present.
    expect(find.textContaining('Live Departures'), findsOneWidget);
  });
}
