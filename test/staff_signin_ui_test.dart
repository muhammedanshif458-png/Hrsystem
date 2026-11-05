import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/login_screen.dart';
import 'package:hr_core/main.dart';
import 'package:hr_core/staff_department_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Removed Elements Verification', () {
    testWidgets('Forgot Password, Remember Me, Face ID, and SSO biometrics are completely removed',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      // Removed elements must not exist
      expect(find.text('Forgot Password?'), findsNothing);
      expect(find.text('Forgot Password'), findsNothing);
      expect(find.text('Remember me'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Sign in with Face ID / Touch ID'), findsNothing);
      expect(find.byIcon(Icons.face_retouching_natural), findsNothing);
      expect(find.textContaining('Enterprise SSO'), findsNothing);
      expect(find.textContaining('Biometrics'), findsNothing);
      expect(find.textContaining('🛡'), findsNothing);

      // Remaining core elements must be present
      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('StaffHub Systems Inc. • Internal Access Only'), findsOneWidget);
    });
  });

  group('2. Input Placeholders & Password Visibility Verification', () {
    testWidgets('Email and Password have correct labels, placeholders, and visibility toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      // 1. Labels
      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // 2. Placeholders / Hints
      expect(find.text('name@company.com'), findsNothing);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      // 3. Typing in fields works
      final emailFinder = find.widgetWithText(TextField, 'Enter your email');
      final passwordFinder = find.widgetWithText(TextField, 'Enter your password');

      await tester.enterText(emailFinder, 'staff.member@company.com');
      await tester.enterText(passwordFinder, 'SecretPass123');
      await tester.pumpAndSettle();

      expect(find.text('staff.member@company.com'), findsOneWidget);

      // 4. Password visibility toggle works
      TextField passwordField = tester.widget<TextField>(passwordFinder);
      expect(passwordField.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      // Tap toggle to unhide password
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      passwordField = tester.widget<TextField>(passwordFinder);
      expect(passwordField.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      // Tap toggle again to re-hide password
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      passwordField = tester.widget<TextField>(passwordFinder);
      expect(passwordField.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  group('3. Back Navigation & Department Preservation Verification', () {
    testWidgets('Navigation from Department Selection to Sign In and Back preserves selected department',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const StaffHubApp());
      await tester.pumpAndSettle();

      // Initial state: Department selection screen
      expect(find.text('Choose Your Department'), findsOneWidget);
      expect(find.text('Welcome back 👋'), findsNothing);

      // 1. Select 'Tech'
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      // Sign In screen is displayed with Tech workspace
      expect(find.text('Choose Your Department'), findsNothing);
      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('●  TECH WORKSPACE'), findsOneWidget);

      // Back button must exist at the top
      final backButton = find.byKey(const ValueKey('sign-in-back-button'));
      expect(backButton, findsOneWidget);

      // 2. Tap Back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Navigated back to Department Selection screen
      expect(find.text('Choose Your Department'), findsOneWidget);
      expect(find.text('Welcome back 👋'), findsNothing);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Home'), findsNothing);

      // Verify the previously selected department is preserved on the widget
      final deptScreen = tester.widget<StaffDepartmentScreen>(find.byType(StaffDepartmentScreen));
      expect(deptScreen.selectedDepartment, 'Tech');

      // 3. Now select 'Telecalling'
      await tester.tap(find.text('Telecalling'));
      await tester.pumpAndSettle();

      // Sign In screen is displayed with Telecalling workspace
      expect(find.text('Choose Your Department'), findsNothing);
      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('●  TELECALLING WORKSPACE'), findsOneWidget);

      // 4. Tap Back again
      await tester.tap(find.byKey(const ValueKey('sign-in-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Department'), findsOneWidget);
      final deptScreen2 = tester.widget<StaffDepartmentScreen>(find.byType(StaffDepartmentScreen));
      expect(deptScreen2.selectedDepartment, 'Telecalling');
    });

    testWidgets('Standalone StaffLoginPage onBack callback is invoked when Back button is tapped',
        (WidgetTester tester) async {
      var backCalled = false;
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode, location) async {},
          onBack: () => backCalled = true,
        ),
      ));

      expect(find.byKey(const ValueKey('sign-in-back-button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sign-in-back-button')));
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });
  });

  group('4. Functionality Preservation Verification', () {
    testWidgets('Office and Work From Home selection functions properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      // Defaults to Office
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Work From Home'), findsOneWidget);
      expect(find.text('Current Location'), findsNothing);

      // Switch to Work From Home
      await tester.tap(find.text('Work From Home'));
      await tester.pump();

      // Shows location detection card
      expect(find.text('Current Location'), findsOneWidget);

      // Switch back to Office
      await tester.tap(find.text('Office'));
      await tester.pump();

      expect(find.text('Current Location'), findsNothing);
    });

    testWidgets('Sign In button calls onSignIn with entered credentials and work mode',
        (WidgetTester tester) async {
      String? capturedEmail;
      String? capturedPassword;
      String? capturedWorkMode;
      dynamic capturedLocation;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode, location) async {
            capturedEmail = email;
            capturedPassword = password;
            capturedWorkMode = workMode;
            capturedLocation = location;
          },
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'alex@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'MyPassword99');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(capturedEmail, 'alex@company.com');
      expect(capturedPassword, 'MyPassword99');
      expect(capturedWorkMode, 'OFFICE');
      expect(capturedLocation, isNull);
    });
  });

  group('5. Responsive Layout & No Overflow Verification', () {
    final screenSizes = [
      const Size(320, 568), // iPhone SE (1st gen) - compact width & height
      const Size(360, 640), // Standard small Android
      const Size(375, 667), // iPhone 8 / SE (2nd gen)
      const Size(390, 844), // iPhone 12/13/14
      const Size(412, 915), // Pixel 7
      const Size(768, 1024), // iPad portrait
      const Size(844, 390), // Landscape mobile
    ];

    for (final size in screenSizes) {
      testWidgets('Renders cleanly without overflow on size ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          home: StaffLoginPage(
            selectedDepartment: 'Tech',
            onSignIn: (email, password, workMode, location) async {},
          ),
        ));

        await tester.pumpAndSettle();

        // No Flutter layout exception or RenderFlex overflow
        expect(tester.takeException(), isNull);

        // Core elements visible and rendered
        expect(find.byKey(const ValueKey('sign-in-back-button')), findsOneWidget);
        expect(find.text('Welcome back 👋'), findsOneWidget);
        expect(find.text('Work Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      });
    }
  });
}

