import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/date_time_utils.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_hr_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub getTimeBasedGreeting Helper Unit Tests', () {
    test('1. Morning hours (12:00 AM – 11:59 AM) return Good Morning', () {
      // Midnight / Start of day
      expect(
          getTimeBasedGreeting(DateTime(2026, 11, 25, 0, 0)), 'Good Morning');
      expect(DateTimeUtils.getTimeBasedGreeting(DateTime(2026, 11, 25, 0, 0)),
          'Good Morning');

      // Early morning
      expect(
          getTimeBasedGreeting(DateTime(2026, 11, 25, 6, 30)), 'Good Morning');

      // Mid-morning
      expect(
          getTimeBasedGreeting(DateTime(2026, 11, 25, 9, 15)), 'Good Morning');

      // Last minute before noon
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 11, 59, 59)),
          'Good Morning');
    });

    test(
        '2. Afternoon hours (12:00 PM – 4:59 PM, including 3:49 PM) return Good Afternoon',
        () {
      // Exactly noon (12:00 PM)
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 12, 0, 0)),
          'Good Afternoon');
      expect(
          DateTimeUtils.getTimeBasedGreeting(DateTime(2026, 11, 25, 12, 0, 0)),
          'Good Afternoon');

      // Early afternoon
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 13, 30)),
          'Good Afternoon');

      // 3:49 PM (specifically tested afternoon hour)
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 15, 49)),
          'Good Afternoon');
      expect(DateTimeUtils.getTimeBasedGreeting(DateTime(2026, 11, 25, 15, 49)),
          'Good Afternoon');

      // Last minute before 5:00 PM (4:59:59 PM)
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 16, 59, 59)),
          'Good Afternoon');
    });

    test(
        '3. Evening / Night hours (5:00 PM – 11:59 PM) return Good Evening',
        () {
      // Exactly 5:00 PM
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 17, 0, 0)),
          'Good Evening');
      expect(
          DateTimeUtils.getTimeBasedGreeting(DateTime(2026, 11, 25, 17, 0, 0)),
          'Good Evening');

      // Evening (7:30 PM)
      expect(
          getTimeBasedGreeting(DateTime(2026, 11, 25, 19, 30)), 'Good Evening');

      // Late night (10:45 PM)
      expect(
          getTimeBasedGreeting(DateTime(2026, 11, 25, 22, 45)), 'Good Evening');

      // End of day (11:59:59 PM)
      expect(getTimeBasedGreeting(DateTime(2026, 11, 25, 23, 59, 59)),
          'Good Evening');
    });

    test('4. Default call without parameter returns a valid greeting', () {
      final greeting = getTimeBasedGreeting();
      expect(
        ['Good Morning', 'Good Afternoon', 'Good Evening'].contains(greeting),
        isTrue,
      );
    });
  });

  group('StaffHub Home Dashboard Greeting Widget Tests', () {
    testWidgets(
        '5. Home screen renders dynamic greeting with Plus Jakarta Sans, font size 26, and weight w800',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff_test_1',
        name: 'Olivia Rodrigo',
        email: 'olivia@company.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffHubShell(
          repository: repository,
          pageIndex: 0,
          department: Department.tech,
          staff: staff,
          workMode: 'Office',
          workLocation: null,
          onNavigate: (_) {},
          onLogout: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final currentGreeting = getTimeBasedGreeting();
      final expectedText = '$currentGreeting, Olivia Rodrigo 👋';

      // Verify the greeting text is displayed
      final greetingFinder = find.text(expectedText);
      expect(greetingFinder, findsOneWidget);

      // Verify typography and styling
      final textWidget = tester.widget<Text>(greetingFinder);
      expect(textWidget.style?.fontFamily, 'Plus Jakarta Sans');
      expect(textWidget.style?.fontSize, 26);
      expect(textWidget.style?.fontWeight, FontWeight.w800);

      // Verify department and work mode info sits right below
      expect(find.textContaining('Department:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Work Mode:', findRichText: true), findsOneWidget);
    });
  });
}
