import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_hr_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub Sidebar Logout Option Tests', () {
    testWidgets(
        '1. Sidebar renders Logout option directly below user profile card with correct icon, label, and style',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff_abu_1',
        name: 'abu',
        email: 'abu@company.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );

      var logoutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: 0,
            department: Department.tech,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (_) {},
            onLogout: () {
              logoutCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the profile card showing "abu" and "Tech" exists
      expect(find.text('abu'), findsAtLeastNWidgets(1));
      expect(find.text(Department.tech), findsAtLeastNWidgets(1));

      // Verify the sidebar Logout button is present
      final logoutFinder = find.byKey(const ValueKey('sidebar_logout_button'));
      expect(logoutFinder, findsOneWidget);

      // Verify Logout text and icon
      expect(
        find.descendant(of: logoutFinder, matching: find.text('Logout')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: logoutFinder, matching: find.byIcon(Icons.logout_rounded)),
        findsOneWidget,
      );

      // Verify Plus Jakarta Sans typography
      final textWidget = tester.widget<Text>(
        find.descendant(of: logoutFinder, matching: find.text('Logout')),
      );
      expect(textWidget.style?.fontFamily, 'Plus Jakarta Sans');
      expect(textWidget.style?.fontWeight, FontWeight.w600);

      // Verify tapping Logout triggers the onLogout callback
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();
      expect(logoutCalled, isTrue);
    });

    testWidgets(
        '2. Existing Settings -> Manage Complete Profile -> Logout continues to trigger same onLogout callback',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff_abu_1',
        name: 'abu',
        email: 'abu@company.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );

      var logoutCount = 0;
      int currentPage = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: StaffHubShell(
                repository: repository,
                pageIndex: currentPage,
                department: Department.tech,
                staff: staff,
                workMode: 'Office',
                workLocation: null,
                onNavigate: (index) {
                  setState(() => currentPage = index);
                },
                onLogout: () {
                  logoutCount++;
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Settings (pageIndex: 3)
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Tap Manage Complete Profile
      final manageProfileFinder = find.text('Manage Complete Profile');
      expect(manageProfileFinder, findsOneWidget);
      await tester.tap(manageProfileFinder);
      await tester.pumpAndSettle();

      // Find the Log Out button inside Profile page
      final profileLogoutFinder = find.widgetWithText(OutlinedButton, 'Log Out');
      expect(profileLogoutFinder, findsOneWidget);

      // Ensure visible in scroll view and tap the Profile page Log Out button
      await tester.ensureVisible(profileLogoutFinder);
      await tester.pumpAndSettle();
      await tester.tap(profileLogoutFinder);
      await tester.pumpAndSettle();

      expect(logoutCount, 1);

      // Also tap the Sidebar Logout button to verify both trigger the exact same handler
      final sidebarLogoutFinder =
          find.byKey(const ValueKey('sidebar_logout_button'));
      expect(sidebarLogoutFinder, findsOneWidget);
      await tester.tap(sidebarLogoutFinder);
      await tester.pumpAndSettle();

      expect(logoutCount, 2);
    });

    testWidgets(
        '3. End-to-end logout: session token cleared and user returned to login/department selection',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff_abu_1',
        name: 'abu',
        email: 'abu@company.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );
      repository.currentUser.value = staff;

      bool isLoggedIn = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            if (!isLoggedIn) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: Text('Login Screen / Department Selection')),
                ),
              );
            }
            return MaterialApp(
              home: StaffHubShell(
                repository: repository,
                pageIndex: 0,
                department: Department.tech,
                staff: staff,
                workMode: 'Office',
                workLocation: null,
                onNavigate: (_) {},
                onLogout: () {
                  setState(() {
                    isLoggedIn = false;
                    repository.signOut();
                  });
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sidebar_logout_button')), findsOneWidget);
      expect(repository.currentUser.value, isNotNull);

      // Tap Sidebar Logout
      await tester.tap(find.byKey(const ValueKey('sidebar_logout_button')));
      await tester.pumpAndSettle();

      // Verify repository signed out and redirected
      expect(repository.currentUser.value, isNull);
      expect(find.text('Login Screen / Department Selection'), findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar_logout_button')), findsNothing);
    });
  });
}
