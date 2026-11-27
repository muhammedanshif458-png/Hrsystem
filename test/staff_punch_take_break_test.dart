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

  group('StaffHub Punch Screen Take a Break Option Tests', () {
    testWidgets(
        '1. Take a Break appears on Punch screen and is disabled when not checked in',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff_1',
        name: 'Olivia Rodrigo',
        email: 'olivia@company.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: 1, // Punch screen
            department: Department.tech,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final takeBreakButtonFinder =
          find.byKey(const ValueKey('punch_take_break_button'));
      expect(takeBreakButtonFinder, findsOneWidget);
      expect(find.text('Take a Break'), findsOneWidget);

      // Verify disabled when not checked in
      final button = tester.widget<ElevatedButton>(takeBreakButtonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets(
        '2. Take a Break opens Choose a break sheet and starts selected break with same handler as Dashboard',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff_1',
        name: 'Olivia Rodrigo',
        email: 'olivia@company.com',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );

      final today = DateTimeUtils.getTodayIsoDate();
      final activeAttendance = Attendance(
        id: 'att_test_1',
        staffId: 'staff_1',
        date: today,
        checkInTime: '09:00 AM',
        checkInAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'PRESENT',
        breaks: const [],
      );
      repository.attendanceList.value = [activeAttendance];

      int currentPage = 1; // start on Punch screen

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
                onNavigate: (index) => setState(() => currentPage = index),
                onLogout: () {},
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final takeBreakButtonFinder =
          find.byKey(const ValueKey('punch_take_break_button'));
      expect(takeBreakButtonFinder, findsOneWidget);
      expect(find.text('Take a Break'), findsOneWidget);

      // Verify enabled when checked in
      final button = tester.widget<ElevatedButton>(takeBreakButtonFinder);
      expect(button.onPressed, isNotNull);

      // Tap Take a Break
      await tester.tap(takeBreakButtonFinder);
      await tester.pumpAndSettle();

      // Verify "Choose a break" bottom sheet modal appears
      expect(find.text('Choose a break'), findsOneWidget);
      expect(find.text('Tea Break 1'), findsOneWidget);
      expect(find.text('Lunch Break'), findsOneWidget);
      expect(find.text('Tea Break 2'), findsOneWidget);

      // Select Tea Break 1
      await tester.tap(find.text('Tea Break 1'));
      await tester.pumpAndSettle();

      // Verify repository updated with active break
      final updatedAttendance = repository.attendanceList.value.first;
      expect(updatedAttendance.breaks.length, 1);
      expect(updatedAttendance.breaks.first.breakType, 'tea_break_1');
      expect(updatedAttendance.breaks.first.isActive, isTrue);

      // Verify Punch screen button now shows "End Break"
      expect(find.text('End Break'), findsOneWidget);

      // Switch to Dashboard (pageIndex: 0) to verify status consistency across screens
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Break in Progress'), findsAtLeastNWidgets(1));
      expect(find.text('End Break'), findsOneWidget);

      // Return to Punch screen and End Break
      await tester.tap(find.text('Punch'));
      await tester.pumpAndSettle();

      final endBreakFinder =
          find.byKey(const ValueKey('punch_take_break_button'));
      expect(endBreakFinder, findsOneWidget);
      await tester.tap(endBreakFinder);
      await tester.pumpAndSettle();

      // Verify break is no longer active
      final finalizedAttendance = repository.attendanceList.value.first;
      expect(finalizedAttendance.breaks.first.isActive, isFalse);
      expect(finalizedAttendance.breaks.first.endTime, isNotNull);
      expect(find.text('Take a Break'), findsOneWidget);
    });
  });
}
