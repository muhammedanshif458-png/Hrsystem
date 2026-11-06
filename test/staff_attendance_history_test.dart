import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'mock_hr_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestShell({
    required MockHRRepository repository,
    String department = Department.tech,
    String workMode = 'Office',
  }) {
    final staff = Staff(
      id: 'staff_att_01',
      name: 'Aarav Dev',
      email: 'aarav@lysoftware.com',
      department: department,
      role: Role.staff,
      status: Status.active,
    );
    return MaterialApp(
      home: StaffHubShell(
        repository: repository,
        pageIndex: 1, // Punch Page
        department: department,
        staff: staff,
        workMode: workMode,
        workLocation: null,
        onNavigate: (_) {},
        onLogout: () {},
      ),
    );
  }

  group('StaffHub Punch Page – Attendance History & Clear History', () {
    testWidgets(
        '1. Attendance History items display date, check-in, status, and session indicator',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      repository.attendanceList.value = [
        Attendance(
          id: 'att_completed_1',
          staffId: 'staff_att_01',
          date: '2026-11-05',
          checkInTime: '10:00 AM',
          checkOutTime: '06:00 PM',
          status: 'PRESENT',
          workMode: 'Office',
          department: 'Tech',
          sessionStatus: 'COMPLETED',
          workedDuration: '7h 15m',
          breakDuration: '45m',
          totalBreakMinutes: 45,
          breaks: [
            AttendanceBreak(
              id: 'b1',
              attendanceId: 'att_completed_1',
              breakType: 'lunch',
              startTime: DateTime(2026, 11, 5, 13, 0),
              endTime: DateTime(2026, 11, 5, 13, 45),
              durationMinutes: 45,
              durationSeconds: 45 * 60,
              remarks: 'Lunch with team',
            ),
          ],
        ),
      ];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Attendance History'), findsOneWidget);
      expect(find.textContaining('Nov 2026'), findsWidgets);
      expect(find.text('In: 10:00 AM'), findsOneWidget);
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });

    testWidgets(
        '2. Tapping a completed record opens attendance detail with complete summary, punch, and break details',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      final record = Attendance(
        id: 'att_completed_2',
        staffId: 'staff_att_01',
        date: '2026-11-04',
        checkInTime: '10:15 AM',
        checkOutTime: '06:30 PM',
        status: 'LATE',
        isLate: true,
        minutesLate: 15,
        workMode: 'Office',
        department: 'Tech',
        sessionStatus: 'COMPLETED',
        scheduledCheckIn: '10:00',
        scheduledCheckOut: '18:00',
        workedDuration: '7h 15m',
        breakDuration: '60 min',
        totalBreakMinutes: 60,
        breaks: [
          AttendanceBreak(
            id: 'b1',
            attendanceId: 'att_completed_2',
            breakType: 'tea_break_1',
            startTime: DateTime(2026, 11, 4, 11, 30),
            endTime: DateTime(2026, 11, 4, 11, 45),
            durationMinutes: 15,
            durationSeconds: 15 * 60,
          ),
          AttendanceBreak(
            id: 'b2',
            attendanceId: 'att_completed_2',
            breakType: 'lunch',
            startTime: DateTime(2026, 11, 4, 13, 30),
            endTime: DateTime(2026, 11, 4, 14, 15),
            durationMinutes: 45,
            durationSeconds: 45 * 60,
          ),
        ],
      );
      repository.attendanceList.value = [record];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      final itemFinder = find.text('In: 10:15 AM');
      await tester.ensureVisible(itemFinder);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      // Detail bottom sheet should open
      expect(find.text('Attendance Details'), findsOneWidget);
      expect(find.text('Attendance Summary'), findsOneWidget);
      expect(find.text('Punch Details'), findsOneWidget);
      expect(find.text('Break Details'), findsOneWidget);

      // Summary checks
      expect(find.text('Tech'), findsWidgets);
      expect(find.text('Office'), findsWidgets);
      expect(find.text('Late'), findsWidgets);
      expect(find.text('7h 15m'), findsOneWidget);

      // Punch checks
      expect(find.text('10:15 AM'), findsWidgets);
      expect(find.text('06:30 PM'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('06:00 PM'), findsOneWidget);
      expect(find.text('15 mins late'), findsOneWidget);

      // Break checks
      expect(find.text('2 breaks'), findsOneWidget);
      expect(find.text('Break 1 – ☕ Tea Break 1'), findsOneWidget);
      expect(find.text('Break 2 – 🍽 Lunch Break'), findsOneWidget);
      expect(find.textContaining('· 15 min'), findsOneWidget);
      expect(find.textContaining('· 45 min'), findsOneWidget);
    });

    testWidgets(
        '3. Ongoing attendance shows In Progress and Pending checkout without fake checkout time',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      final now = DateTime.now();
      final ongoingRecord = Attendance(
        id: 'att_ongoing_1',
        staffId: 'staff_att_01',
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        checkInTime: '09:05 AM',
        checkInAt: DateTime(now.year, now.month, now.day, 9, 5),
        checkOutTime: null, // Strictly null
        checkOutAt: null, // Strictly null
        status: 'PRESENT',
        workMode: 'WORK_FROM_HOME',
        department: 'Tech',
        sessionStatus: 'IN_PROGRESS',
        scheduledCheckIn: '10:00 AM',
        scheduledCheckOut: '06:00 PM',
        breaks: [
          AttendanceBreak(
            id: 'b_active',
            attendanceId: 'att_ongoing_1',
            breakType: 'tea_break_1',
            startTime: DateTime(now.year, now.month, now.day, 11, 0),
            endTime: null, // Active ongoing break
            durationSeconds: 0,
          ),
        ],
      );
      repository.attendanceList.value = [ongoingRecord];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      // Check In Progress pill on history item
      expect(find.text('In Progress'), findsWidgets);

      // Tap to open details
      final itemFinder = find.text('In: 09:05 AM');
      await tester.ensureVisible(itemFinder);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      // Header indicates In Progress
      expect(find.text('Attendance Details'), findsOneWidget);
      expect(
          find.text('Shift currently in progress. Checkout is pending.'),
          findsOneWidget);

      // Check checkout display is strictly 'Pending'
      expect(find.text('Pending'), findsWidgets);

      // Active break is clearly marked as active
      expect(find.text('Active (Ongoing)'), findsOneWidget);
      expect(find.text('Break 1 – ☕ Tea Break 1'), findsOneWidget);
    });

    testWidgets(
        '4. Clear History displays confirmation dialog and explains official records remain available to HR',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      repository.attendanceList.value = [
        Attendance(
          id: 'att_to_clear',
          staffId: 'staff_att_01',
          date: '2026-11-01',
          checkInTime: '10:00 AM',
          checkOutTime: '06:00 PM',
          status: 'PRESENT',
          workMode: 'Office',
          department: 'Tech',
        ),
      ];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      final clearBtn =
          find.byKey(const ValueKey('clear-attendance-history-button'));
      expect(clearBtn, findsOneWidget);
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog verification
      expect(find.text('Clear Attendance History'), findsOneWidget);
      expect(find.textContaining('Clear your attendance history from this view?'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Official attendance records remain available to HR and will not be deleted.'),
          findsOneWidget);

      // Tap Cancel -> records still exist
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.attendanceList.value.length, 1);
      expect(find.text('In: 10:00 AM'), findsOneWidget);
    });

    testWidgets(
        '5. Confirming Clear History clears personal history view and shows empty state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      repository.attendanceList.value = [
        Attendance(
          id: 'att_to_clear_2',
          staffId: 'staff_att_01',
          date: '2026-11-01',
          checkInTime: '10:00 AM',
          checkOutTime: '06:00 PM',
          status: 'PRESENT',
          workMode: 'Office',
          department: 'Tech',
        ),
      ];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      final clearBtn =
          find.byKey(const ValueKey('clear-attendance-history-button'));
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Tap Clear History in dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Clear History'));
      await tester.pumpAndSettle();

      // Verify list is cleared
      expect(repository.attendanceList.value.isEmpty, isTrue);
      expect(find.text('No attendance records yet'), findsOneWidget);
      expect(find.text('Your punch and attendance records will appear here.'),
          findsOneWidget);
    });

    testWidgets(
        '6. Clear History does not wipe active ongoing session or break data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      final now = DateTime.now();
      final activeShift = Attendance(
        id: 'att_active_must_keep',
        staffId: 'staff_att_01',
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        checkInTime: '09:30 AM',
        checkInAt: DateTime(now.year, now.month, now.day, 9, 30),
        checkOutTime: null,
        checkOutAt: null,
        status: 'PRESENT',
        workMode: 'Office',
        department: 'Tech',
        sessionStatus: 'IN_PROGRESS',
        breaks: [
          AttendanceBreak(
            id: 'b_active_stay',
            attendanceId: 'att_active_must_keep',
            breakType: 'tea_break_1',
            startTime: DateTime(now.year, now.month, now.day, 11, 0),
            endTime: null,
            durationSeconds: 0,
          ),
        ],
      );

      final oldCompleted = Attendance(
        id: 'att_old_completed',
        staffId: 'staff_att_01',
        date: '2026-10-30',
        checkInTime: '10:00 AM',
        checkOutTime: '06:00 PM',
        status: 'PRESENT',
        workMode: 'Office',
        department: 'Tech',
        sessionStatus: 'COMPLETED',
      );

      repository.attendanceList.value = [activeShift, oldCompleted];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      final clearBtn =
          find.byKey(const ValueKey('clear-attendance-history-button'));
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Clear History'));
      await tester.pumpAndSettle();

      // Active ongoing shift is retained!
      expect(
          repository.attendanceList.value
              .any((a) => a.id == 'att_active_must_keep'),
          isTrue);
      // Old completed shift is removed
      expect(
          repository.attendanceList.value
              .any((a) => a.id == 'att_old_completed'),
          isFalse);
    });

    testWidgets(
        '7. Telecalling staff functions identically with department-aware schedule',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      repository.attendanceList.value = [
        Attendance(
          id: 'tele_att_1',
          staffId: 'staff_att_01',
          date: '2026-11-05',
          checkInTime: '09:00 AM',
          checkOutTime: '06:00 PM',
          status: 'PRESENT',
          workMode: 'Office',
          department: Department.telecalling,
          sessionStatus: 'COMPLETED',
        ),
      ];

      await tester.pumpWidget(buildTestShell(
        repository: repository,
        department: Department.telecalling,
      ));
      await tester.pumpAndSettle();

      final itemFinder = find.text('In: 09:00 AM');
      await tester.ensureVisible(itemFinder);
      expect(itemFinder, findsOneWidget);

      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      expect(find.text('Telecalling'), findsWidgets);
      // Default scheduled check-in for Telecalling is 09:00 AM
      expect(find.text('09:00 AM'), findsWidgets);
    });

    testWidgets(
        '8. ISO timestamps (e.g. 2026-11-06T05:24:39.985Z) are formatted into local human-readable time',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const rawIsoCheckIn = '2026-11-06T05:24:39.985Z';
      final expectedLocalTime = formatShiftTime(rawIsoCheckIn);
      expect(expectedLocalTime.contains('T'), isFalse);
      expect(expectedLocalTime.contains('Z'), isFalse);
      expect(expectedLocalTime.contains('AM') || expectedLocalTime.contains('PM'), isTrue);

      final jsonPayload = {
        '_id': 'att_iso_test_1',
        'employee': 'staff_att_01',
        'date': '2026-11-06T00:00:00.000Z',
        'checkInTime': rawIsoCheckIn,
        'checkOutTime': '2026-11-06T12:30:00.000Z',
        'status': 'PRESENT',
        'sessionStatus': 'COMPLETED',
        'workMode': 'Office',
        'department': 'Tech',
      };
      final parsed = Attendance.fromJson(jsonPayload);
      expect(parsed.checkInTime, equals(expectedLocalTime));
      expect(parsed.isCompleted, isTrue);
      expect(parsed.isOngoing, isFalse);

      final repository = MockHRRepository();
      repository.attendanceList.value = [parsed];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      // UI should display local time formatted string, never the raw ISO
      expect(find.textContaining(rawIsoCheckIn), findsNothing);
      expect(find.text('In: $expectedLocalTime'), findsOneWidget);

      // Open detail sheet
      await tester.tap(find.text('In: $expectedLocalTime'));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Details'), findsOneWidget);
      expect(find.textContaining(rawIsoCheckIn), findsNothing);
    });

    testWidgets(
        '9. Completed record never displays In Progress badge',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const completedRecord = Attendance(
        id: 'att_comp_guard',
        staffId: 'staff_att_01',
        date: '2026-11-06',
        checkInTime: '10:00 AM',
        checkOutTime: '06:00 PM',
        status: 'PRESENT',
        sessionStatus: 'COMPLETED',
      );
      expect(completedRecord.isCompleted, isTrue);
      expect(completedRecord.isOngoing, isFalse);
      expect(completedRecord.sessionStatusLabel, equals('Completed'));

      final repository = MockHRRepository();
      repository.attendanceList.value = [completedRecord];

      await tester.pumpWidget(buildTestShell(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('In Progress'), findsNothing);
    });
  });
}
