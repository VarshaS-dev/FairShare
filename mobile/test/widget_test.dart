// Smoke test for the auth UI. We pump the sign-in screen in isolation (inside a
// ProviderScope + MaterialApp) so it renders without needing a live Firebase
// connection — building the screen doesn't touch Firebase, only tapping does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fairshare/features/auth/presentation/sign_in_screen.dart';

void main() {
  testWidgets('Sign-in screen renders its fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
