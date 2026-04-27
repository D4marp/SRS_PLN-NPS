// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookify_rooms/main.dart';

void main() {
  testWidgets('Bookify Rooms app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BookifyRoomsApp());

    // SplashScreen uses a delayed navigation timer; advance time so it fires.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    // Verify that the app loads correctly
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
