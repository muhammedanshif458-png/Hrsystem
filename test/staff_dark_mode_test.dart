import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:hr_core/storage/token_storage.dart';
import 'mock_hr_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub – Dark Mode Theme & Token Verification', () {
    test('1. staffHubThemeData creates correct Dark Mode ThemeData', () {
      final darkTheme = staffHubThemeData(ThemeMode.dark);

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xff0d1117));
      expect(darkTheme.cardColor, const Color(0xff1c2736));
      expect(darkTheme.dialogTheme.backgroundColor, const Color(0xff1c2736));
      expect(darkTheme.colorScheme.surface, const Color(0xff1c2736));
      expect(darkTheme.colorScheme.onSurface, const Color(0xfff1f5f9));
      expect(darkTheme.colorScheme.surfaceContainerHighest, const Color(0xff202d3d));
      expect(darkTheme.colorScheme.outline, const Color(0xff344256));
      expect(darkTheme.dividerColor, const Color(0xff344256));
    });

    test('2. staffHubThemeData creates correct Light Mode ThemeData', () {
      final lightTheme = staffHubThemeData(ThemeMode.light);

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xfff5f7fb));
      expect(lightTheme.cardColor, Colors.white);
      expect(lightTheme.colorScheme.surface, Colors.white);
      expect(lightTheme.colorScheme.onSurface, const Color(0xff1b2638));
      expect(lightTheme.colorScheme.outline, const Color(0xffe8edf4));
      expect(lightTheme.dividerColor, const Color(0xffe8edf4));
    });

    test('3. staffHubThemeMode global updates and persists correctly', () async {
      staffHubThemeMode = ThemeMode.light;
      expect(staffHubThemeMode, equals(ThemeMode.light));

      staffHubThemeMode = ThemeMode.dark;
      expect(staffHubThemeMode, equals(ThemeMode.dark));

      // Verify theme persistence through TokenStorage
      await TokenStorage.saveThemeMode('dark');
      expect(await TokenStorage.getThemeMode(), equals('dark'));

      await TokenStorage.saveThemeMode('light');
      expect(await TokenStorage.getThemeMode(), equals('light'));
    });

    testWidgets('4. StaffHub Settings page renders in Dark Mode without crashing',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      staffHubThemeMode = ThemeMode.dark;

      final repo = MockHRRepository();
      const staff = Staff(
        id: 'EMP1066',
        name: 'Rahul K',
        email: 'rahul@example.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );
      repo.currentUser.value = staff;

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          theme: staffHubThemeData(ThemeMode.light),
          darkTheme: staffHubThemeData(ThemeMode.dark),
          home: StaffHubShell(
            repository: repo,
            pageIndex: 3, // Settings tab
            department: Department.tech,
            staff: staff,
            workMode: 'Office',
            workLocation: 'Bangalore HQ',
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Settings header and cards exist
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Appearance'), findsWidgets);
      expect(find.text('Dark'), findsWidgets);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.text('Support & Helpdesk'), findsWidgets);
      expect(find.text('About StaffHub'), findsWidgets);
      expect(find.text('Security & Audit Guard'), findsWidgets);

      // Verify "Log Out of Session" is NOT in Settings (per previous requirement)
      expect(find.text('Log Out of Session'), findsNothing);
      expect(find.text('Account Actions'), findsNothing);
    });

    testWidgets('5. StaffHub Profile page renders in Dark Mode with dark theme styles',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      staffHubThemeMode = ThemeMode.dark;

      final repo = MockHRRepository();
      const staff = Staff(
        id: 'EMP1066',
        name: 'Rahul K',
        email: 'rahul123@gmail.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );
      repo.currentUser.value = staff;

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          theme: staffHubThemeData(ThemeMode.light),
          darkTheme: staffHubThemeData(ThemeMode.dark),
          home: StaffHubShell(
            repository: repo,
            pageIndex: 3, // Settings
            department: Department.tech,
            staff: staff,
            workMode: 'Office',
            workLocation: 'Bangalore HQ',
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Manage Complete Profile" to open Profile
      final manageProfileBtn = find.text('Manage Complete Profile');
      expect(manageProfileBtn, findsOneWidget);
      await tester.tap(manageProfileBtn);
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Personal Information'), findsWidgets);
      expect(find.text('mock@example.com'), findsWidgets);
    });
  });
}
