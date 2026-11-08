import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockie_store/screen/new_password_screen.dart';

void main() {
  testWidgets('the 8-character error disappears as soon as the 8th character is typed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NewPasswordScreen(email: 'a@example.com', resetToken: 't')));
    final password = find.byType(TextFormField).first;
    final confirmation = find.byType(TextFormField).last;
    const error = 'Password must contain at least 8 characters.';

    await tester.enterText(password, '1234567');
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(find.text(error), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    // No need to tap the button again.
    await tester.enterText(password, '12345678');
    await tester.pump();
    expect(find.text(error), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // "At least 8 characters long"

    await tester.enterText(confirmation, '12345678');
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2)); // and "Both passwords match"
  });
}
