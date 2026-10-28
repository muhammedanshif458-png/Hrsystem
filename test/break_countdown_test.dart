import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_hr_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Break Durations and Configuration', () {
    test('Configured break types and durations match specification', () {
      expect(AttendanceBreakSchedule.types,
          ['tea_break_1', 'lunch', 'tea_break_2']);
      expect(AttendanceBreakSchedule.durationsMinutes, [15, 30, 15]);

      expect(AttendanceBreakSchedule.durationMinutesFor('tea_break_1'), 15);
      expect(AttendanceBreakSchedule.durationMinutesFor('lunch'), 30);
      expect(AttendanceBreakSchedule.durationMinutesFor('tea_break_2'), 15);

      // Legacy aliases
      expect(AttendanceBreakSchedule.durationMinutesFor('morning'), 15);
      expect(AttendanceBreakSchedule.durationMinutesFor('afternoon'), 15);

      expect(AttendanceBreak.allowanceSecondsFor('tea_break_1'), 15 * 60);
      expect(AttendanceBreak.allowanceSecondsFor('lunch'), 30 * 60);
      expect(AttendanceBreak.allowanceSecondsFor('tea_break_2'), 15 * 60);
    });
  });

  group('Countdown Calculation and Formatting', () {
    test('Countdown calculates max(0, allowedDuration - elapsed) every second',
        () {
      final start = DateTime(2026, 10, 27, 10, 0, 0);
      final brk = AttendanceBreak(
        id: 'b1',
        attendanceId: 'att1',
        breakType: 'tea_break_1',
        startTime: start,
      );

      // At start (0 seconds elapsed) -> 15:00
      expect(brk.remainingSecondsAt(start), 900);
      expect(brk.remainingTimeFormatted(start), '15:00');
      expect(brk.remainingTimeText(start), 'Remaining time: 15:00');

      // 1 second elapsed -> 14:59
      final oneSecLater = start.add(const Duration(seconds: 1));
      expect(brk.remainingSecondsAt(oneSecLater), 899);
      expect(brk.remainingTimeFormatted(oneSecLater), '14:59');
      expect(brk.remainingTimeText(oneSecLater), 'Remaining time: 14:59');

      // 60 seconds elapsed -> 14:00
      final oneMinLater = start.add(const Duration(seconds: 60));
      expect(brk.remainingSecondsAt(oneMinLater), 840);
      expect(brk.remainingTimeFormatted(oneMinLater), '14:00');
      expect(brk.remainingTimeText(oneMinLater), 'Remaining time: 14:00');

      // Lunch break 30 minutes (1800s) -> 1 second elapsed -> 29:59
      final lunchBreak = AttendanceBreak(
        id: 'b2',
        attendanceId: 'att1',
        breakType: 'lunch',
        startTime: start,
      );
      expect(lunchBreak.remainingSecondsAt(start), 1800);
      expect(lunchBreak.remainingTimeFormatted(start), '30:00');
      expect(lunchBreak.remainingTimeText(start), 'Remaining time: 30:00');

      expect(lunchBreak.remainingSecondsAt(oneSecLater), 1799);
      expect(lunchBreak.remainingTimeFormatted(oneSecLater), '29:59');
      expect(lunchBreak.remainingTimeText(oneSecLater),
          'Remaining time: 29:59');
    });

    test('Countdown clamps to 00:00 when remaining time reaches zero', () {
      final start = DateTime(2026, 10, 27, 10, 0, 0);
      final brk = AttendanceBreak(
        id: 'b1',
        attendanceId: 'att1',
        breakType: 'tea_break_1',
        startTime: start,
      );

      // Exactly at expiry (15 mins = 900s)
      final atExpiry = start.add(const Duration(minutes: 15));
      expect(brk.remainingSecondsAt(atExpiry), 0);
      expect(brk.remainingTimeFormatted(atExpiry), '00:00');
      expect(brk.remainingTimeText(atExpiry), 'Remaining time: 00:00');

      // Overdue (20 mins elapsed) -> still 00:00
      final overdue = start.add(const Duration(minutes: 20));
      expect(brk.remainingSecondsAt(overdue), 0);
      expect(brk.remainingTimeFormatted(overdue), '00:00');
      expect(brk.remainingTimeText(overdue), 'Remaining time: 00:00');
    });

    test('Breaks longer than 59 minutes format with HH:MM:SS', () {
      expect(AttendanceBreak.formatRemainingDuration(3600), '01:00:00');
      expect(AttendanceBreak.formatRemainingDuration(3665), '01:01:05');
      expect(AttendanceBreak.formatRemainingDuration(7200), '02:00:00');
    });

    test('Completed break has 0 remaining seconds', () {
      final start = DateTime(2026, 10, 27, 10, 0, 0);
      final completed = AttendanceBreak(
        id: 'b1',
        attendanceId: 'att1',
        breakType: 'tea_break_1',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        durationSeconds: 600,
      );
      expect(completed.remainingSecondsAt(start.add(const Duration(minutes: 5))), 0);
    });
  });

  group('UI & Timer Behavior for Tech and Telecalling', () {
    for (final department in [Department.tech, Department.telecalling]) {
      testWidgets('$department displays countdown and updates every second',
          (WidgetTester tester) async {
        final repository = MockHRRepository();
        final now = DateTime.now();
        final start = now.subtract(const Duration(seconds: 1)); // 1 second elapsed

        repository.attendanceList.value = [
          Attendance(
            id: 'att_test',
            staffId: 'staff_1',
            date: now.toIso8601String().substring(0, 10),
            checkInTime: '10:00 AM',
            checkInAt: now.subtract(const Duration(hours: 1)),
            breaks: [
              AttendanceBreak(
                id: 'b_active',
                attendanceId: 'att_test',
                breakType: 'tea_break_1',
                startTime: start,
              ),
            ],
          ),
        ];

        final staff = Staff(
          id: 'staff_1',
          name: 'Employee One',
          email: 'emp@test.com',
          department: department,
          role: Role.staff,
          status: Status.active,
        );

        await tester.pumpWidget(MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: 0,
            department: department,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ));
        await tester.pump();

        // Verify initial remaining time countdown is displayed
        final initialFinder = find.textContaining('Remaining time:');
        expect(initialFinder, findsOneWidget);
        expect(find.text('End Break'), findsOneWidget);
        final initialText = tester.widget<Text>(initialFinder).data!;
        expect(initialText.startsWith('Remaining time: 14:'), isTrue);

        // Simulate 2 seconds of elapsed time
        repository.attendanceList.value = [
          Attendance(
            id: 'att_test',
            staffId: 'staff_1',
            date: now.toIso8601String().substring(0, 10),
            checkInTime: '10:00 AM',
            checkInAt: now.subtract(const Duration(hours: 1)),
            breaks: [
              AttendanceBreak(
                id: 'b_active',
                attendanceId: 'att_test',
                breakType: 'tea_break_1',
                startTime: start.subtract(const Duration(seconds: 2)),
              ),
            ],
          ),
        ];
        await tester.pump(const Duration(seconds: 1));
        final updatedFinder = find.textContaining('Remaining time:');
        expect(updatedFinder, findsOneWidget);
        final updatedText = tester.widget<Text>(updatedFinder).data!;
        expect(updatedText.startsWith('Remaining time: 14:'), isTrue);
        expect(updatedText, isNot(equals(initialText)));
      });

      testWidgets(
          '$department shows Remaining time: 00:00 at zero without auto-ending',
          (WidgetTester tester) async {
        final repository = MockHRRepository();
        final now = DateTime.now();
        // 16 minutes elapsed on a 15-minute break
        final start = now.subtract(const Duration(minutes: 16));

        repository.attendanceList.value = [
          Attendance(
            id: 'att_test_zero',
            staffId: 'staff_1',
            date: now.toIso8601String().substring(0, 10),
            checkInTime: '10:00 AM',
            checkInAt: now.subtract(const Duration(hours: 1)),
            breaks: [
              AttendanceBreak(
                id: 'b_overdue',
                attendanceId: 'att_test_zero',
                breakType: 'tea_break_1',
                startTime: start,
              ),
            ],
          ),
        ];

        final staff = Staff(
          id: 'staff_1',
          name: 'Employee One',
          email: 'emp@test.com',
          department: department,
          role: Role.staff,
          status: Status.active,
        );

        await tester.pumpWidget(MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: 0,
            department: department,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ));
        await tester.pump();

        expect(find.text('Remaining time: 00:00'), findsOneWidget);
        expect(find.text('End Break'), findsOneWidget);

        // Advance timer further: does NOT auto end break
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Remaining time: 00:00'), findsOneWidget);
        expect(find.text('End Break'), findsOneWidget);
      });

      testWidgets(
          '$department ending break stops countdown and restores Working UI',
          (WidgetTester tester) async {
        final repository = MockHRRepository();
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 5));

        repository.attendanceList.value = [
          Attendance(
            id: 'att_end_test',
            staffId: 'staff_1',
            date: now.toIso8601String().substring(0, 10),
            checkInTime: '10:00 AM',
            checkInAt: now.subtract(const Duration(hours: 1)),
            breaks: [
              AttendanceBreak(
                id: 'b_active',
                attendanceId: 'att_end_test',
                breakType: 'tea_break_1',
                startTime: start,
              ),
            ],
          ),
        ];

        final staff = Staff(
          id: 'staff_1',
          name: 'Employee One',
          email: 'emp@test.com',
          department: department,
          role: Role.staff,
          status: Status.active,
        );

        await tester.pumpWidget(MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: 0,
            department: department,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ));
        await tester.pump();

        expect(find.text('Remaining time: 10:00'), findsOneWidget);
        expect(find.text('End Break'), findsOneWidget);

        // Tap End Break
        await tester.tap(find.text('End Break'));
        await tester.pumpAndSettle();

        // Active countdown is cleared, Upcoming Break and Start Break restored
        expect(find.textContaining('Remaining time:'), findsNothing);
        expect(find.text('Upcoming Break'), findsOneWidget);
        expect(find.text('Start Break'), findsOneWidget);
      });

      testWidgets(
          '$department recalculates on app resume without timer drift',
          (WidgetTester tester) async {
        final repository = MockHRRepository();
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 5)); // 10 min remaining

        repository.attendanceList.value = [
          Attendance(
            id: 'att_resume_test',
            staffId: 'staff_1',
            date: now.toIso8601String().substring(0, 10),
            checkInTime: '10:00 AM',
            checkInAt: now.subtract(const Duration(hours: 1)),
            breaks: [
              AttendanceBreak(
                id: 'b_active',
                attendanceId: 'att_resume_test',
                breakType: 'tea_break_1',
                startTime: start,
              ),
            ],
          ),
        ];

        final staff = Staff(
          id: 'staff_1',
          name: 'Employee One',
          email: 'emp@test.com',
          department: department,
          role: Role.staff,
          status: Status.active,
        );

        await tester.pumpWidget(MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: 0,
            department: department,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ));
        await tester.pump();

        expect(find.text('Remaining time: 10:00'), findsOneWidget);

        // Simulate app pause & resume
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        // Recalculates accurately
        expect(find.text('Remaining time: 10:00'), findsOneWidget);
      });
    }
  });

  group('Backend Active Break Restoration', () {
    testWidgets('Restoring active break from backend shows countdown immediately',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      final now = DateTime.now();
      // Lunch break started 10 minutes ago -> 20 minutes remaining (30 - 10)
      final start = now.subtract(const Duration(minutes: 10));

      repository.attendanceList.value = [
        Attendance(
          id: 'att_restore',
          staffId: 'staff_restore',
          date: now.toIso8601String().substring(0, 10),
          checkInTime: '10:00 AM',
          checkInAt: now.subtract(const Duration(hours: 2)),
          breaks: [
            AttendanceBreak(
              id: 'b_lunch',
              attendanceId: 'att_restore',
              breakType: 'lunch',
              startTime: start,
            ),
          ],
        ),
      ];

      final staff = Staff(
        id: 'staff_restore',
        name: 'Restored User',
        email: 'user@test.com',
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
      await tester.pump();

      expect(find.text('Remaining time: 20:00'), findsOneWidget);
      expect(find.text('End Break'), findsOneWidget);
      expect(find.textContaining('Lunch Break · Started'), findsOneWidget);
    });
  });
}
