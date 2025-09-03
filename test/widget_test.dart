import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelshare/app.dart';

void main() {
  testWidgets('TravelShare app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TravelShareApp());

    // Verify that our setup message appears
    expect(find.text('TravelShare - Setup Completato! 🚀'), findsOneWidget);
  });
}
