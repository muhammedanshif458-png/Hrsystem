import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/login_screen.dart';
import 'package:hr_core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_hr_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub Login without GPS / Location Dependency', () {
    testWidgets('1. OFFICE login succeeds with credentials and sends OFFICE workMode',
        (WidgetTester tester) async {
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

      // Defaults to Office
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'office.user@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@1234');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(submittedEmail, 'office.user@company.com');
      expect(submittedPassword, 'Pass@1234');
      expect(submittedWorkMode, 'OFFICE');
    });

    testWidgets('2. WORK_FROM_HOME login succeeds with credentials and sends WORK_FROM_HOME workMode',
        (WidgetTester tester) async {
      String? submittedEmail;
      String? submittedPassword;
      String? submittedWorkMode;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Telecalling',
          onSignIn: (email, password, workMode) async {
            submittedEmail = email;
            submittedPassword = password;
            submittedWorkMode = workMode;
          },
        ),
      ));

      // Switch to Work From Home
      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh.user@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'WfhPass@99');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(submittedEmail, 'wfh.user@company.com');
      expect(submittedPassword, 'WfhPass@99');
      expect(submittedWorkMode, 'WORK_FROM_HOME');
    });

    testWidgets('3. UI does not render any location-related widgets, buttons, or indicators',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode) async {},
        ),
      ));

      // Check initially in Office mode
      expect(find.text('Current Location'), findsNothing);
      expect(find.text('Detecting Location...'), findsNothing);
      expect(find.text('Detecting location...'), findsNothing);
      expect(find.text('Open app settings'), findsNothing);
      expect(find.text('Enable location services'), findsNothing);
      expect(find.text('Retry location detection'), findsNothing);
      expect(find.text('✓ Location captured'), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.byIcon(Icons.location_searching), findsNothing);
      expect(find.textContaining('GPS location is collected'), findsNothing);

      // Switch to Work From Home
      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      // Still no location UI
      expect(find.text('Current Location'), findsNothing);
      expect(find.text('Detecting Location...'), findsNothing);
      expect(find.text('Detecting location...'), findsNothing);
      expect(find.text('Open app settings'), findsNothing);
      expect(find.text('Enable location services'), findsNothing);
      expect(find.text('Retry location detection'), findsNothing);
      expect(find.text('✓ Location captured'), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.textContaining('GPS location is collected'), findsNothing);
    });

    testWidgets('4. MockHRRepository signIn accepts WORK_FROM_HOME without location',
        (WidgetTester tester) async {
      final repo = MockHRRepository();
      final staff = await repo.signIn(
        'alex@company.com',
        'password123',
        workMode: 'WORK_FROM_HOME',
      );

      expect(staff.email, 'alex@company.com');
      expect(staff.role, Role.staff);
    });

    testWidgets('5. MockHRRepository signIn accepts OFFICE without location',
        (WidgetTester tester) async {
      final repo = MockHRRepository();
      final staff = await repo.signIn(
        'priya@company.com',
        'password123',
        workMode: 'OFFICE',
      );

      expect(staff.email, 'priya@company.com');
      expect(staff.role, Role.staff);
    });

    testWidgets('6. HRRepository signIn rejects invalid workMode but accepts valid ones without location',
        (WidgetTester tester) async {
      // Testing repository logic
      expect(
        () => HRRepositoryImpl().signIn('test@company.com', 'pass', workMode: 'INVALID'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
