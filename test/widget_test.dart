// This is a basic Flutter widget test for the Duva Mobile App.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duva_mobile/main.dart';

void main() {
  testWidgets('App navigation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame using the NEW class name.
    await tester.pumpWidget(const DuvaMobileApp());

    // Verify that our app starts and the 'Pool' tab text is present.
    // (findsWidgets is used because 'Pool' appears in the App Bar AND the Bottom Nav)
    expect(find.text('Pool'), findsWidgets); 
    
    // Check that the body text of the first screen is displayed
    expect(find.text('🧭 Explore Pool Content Here'), findsOneWidget);

    // Tap the 'Matches' icon in the bottom navigation bar and trigger a frame.
    await tester.tap(find.byIcon(Icons.chat_bubble));
    await tester.pumpAndSettle(); // pumpAndSettle waits for animations to finish

    // Verify that the screen changed to the Matches tab.
    expect(find.text('💬 Your Matches Here'), findsOneWidget);
  });
}