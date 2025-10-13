import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muyassir_app/main.dart';
void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    // Start the app
    await tester.pumpWidget(const MuyassirApp());
    // Allow navigation to finish (like splash and onboarding)
    await tester.pumpAndSettle();
    // Now we're expecting to land on the login screen
    // Check if "Login" button is present
    expect(find.text('Login'), findsOneWidget);
    // Check if 2 TextFormFields exist (Email + Password)
    expect(find.byType(TextFormField), findsNWidgets(2));
    // Check if ElevatedButton (Login button) is present
    expect(find.byType(ElevatedButton), findsOneWidget);
    // Optional: Check placeholder or label text for email and password fields
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
  });
}