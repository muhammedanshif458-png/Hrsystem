import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub Login Page Redesign Verification', () {
    testWidgets('1. Removed unnecessary elements: HRMS, language EN, Remember me, Forgot password',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode) async {},
        ),
      ));
      await tester.pumpAndSettle();

      // Removed elements must not exist
      expect(find.text('HRMS'), findsNothing);
      expect(find.text('EN'), findsNothing);
      expect(find.byIcon(Icons.language_outlined), findsNothing);
      expect(find.text('Remember me'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Forgot Password'), findsNothing);
    });

    testWidgets('2. Back button exists immediately to the left of StaffHub logo and navigates back',
        (tester) async {
      bool backPressed = false;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onBack: () => backPressed = true,
          onSignIn: (email, password, workMode) async {},
        ),
      ));
      await tester.pumpAndSettle();

      // Find back button
      final backBtn = find.byKey(const ValueKey('login_back_button'));
      expect(backBtn, findsOneWidget);

      // Verify it is in the same Row as StaffHub logo
      final staffHubText = find.text('StaffHub');
      expect(staffHubText, findsOneWidget);

      final rowFinder = find.ancestor(of: backBtn, matching: find.byType(Row)).first;
      expect(find.descendant(of: rowFinder, matching: staffHubText), findsOneWidget);

      // Tap back button
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(backPressed, isTrue);
    });

    testWidgets('3. Preserved core elements: Branding, Heading, Department/Work Mode, Inputs, Login, Hey There panel',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? submittedEmail;
      String? submittedPassword;
      String? submittedWorkMode;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode) async {
            submittedEmail = email;
            submittedPassword = password;
            submittedWorkMode = workMode;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Branding & Heading
      expect(find.text('StaffHub'), findsOneWidget);
      expect(find.text('Login'), findsNWidgets(2)); // Heading & Button
      expect(find.text("Welcome, let's get started with your workspace"), findsOneWidget);

      // Department & Work Mode
      expect(find.text('Engineering & Tech (DIV-01)'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Remote'), findsOneWidget);

      // Form inputs
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Enter email'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Enter password'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Right-side Hey There panel
      expect(find.text('Hey There!'), findsOneWidget);
      expect(find.textContaining('Create your account now and step'), findsOneWidget);

      // Test password visibility toggle
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Select Remote work mode
      await tester.tap(find.text('Remote'));
      await tester.pumpAndSettle();

      // Fill in credentials and submit
      await tester.enterText(find.widgetWithText(TextField, 'Enter email'), 'staff@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Enter password'), 'Password123');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(submittedEmail, equals('staff@example.com'));
      expect(submittedPassword, equals('Password123'));
      expect(submittedWorkMode, equals('WORK_FROM_HOME'));
    });
  });
}
