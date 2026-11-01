import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/features/authentication/presentation/login_screen.dart';
import 'package:joint_expenses/features/authentication/presentation/sign_up_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders email, password and actions', (tester) async {
      await pumpApp(tester, const LoginScreen(), household: null, userId: null);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create one'), findsOneWidget);
    });

    testWidgets('shows validation errors and does not submit an empty form', (tester) async {
      await pumpApp(tester, const LoginScreen(), household: null, userId: null);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('rejects malformed email', (tester) async {
      await pumpApp(tester, const LoginScreen(), household: null, userId: null);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'nope');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Password is required'), findsNothing);
    });

    testWidgets('toggles password visibility', (tester) async {
      await pumpApp(tester, const LoginScreen(), household: null, userId: null);

      final field = find.widgetWithText(TextFormField, 'Password');
      expect(tester.widget<TextField>(find.descendant(of: field, matching: find.byType(TextField))).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.descendant(of: field, matching: find.byType(TextField))).obscureText, isFalse);
    });
  });

  group('SignUpScreen', () {
    testWidgets('validates name, email, password length and confirmation', (tester) async {
      await pumpApp(tester, const SignUpScreen(), household: null, userId: null);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@b.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
