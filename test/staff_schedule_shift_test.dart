import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';

import 'mock_hr_repository.dart';

void main() {
  group('Shift Resolution Unit Tests', () {
    test('Tech department resolves to 10:00 AM – 06:00 PM', () {
      const staff = Staff(
        id: 'tech-1',
        name: 'Tech Worker',
        department: Department.tech,
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        department: Department.tech,
      );
      expect(shift, '10:00 AM – 06:00 PM');
    });

    test('Telecalling department resolves to 09:00 AM – 06:00 PM', () {
      const staff = Staff(
        id: 'tele-1',
        name: 'Telecalling Agent',
        department: Department.telecalling,
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        department: Department.telecalling,
      );
      expect(shift, '09:00 AM – 06:00 PM');
    });

    test('Employee individual schedule override takes precedence over Tech department', () {
      const staff = Staff(
        id: 'tech-override-1',
        name: 'Flexible Tech Worker',
        department: Department.tech,
        schedule: {
          'scheduledCheckIn': '08:00',
          'scheduledCheckOut': '16:00',
        },
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        department: Department.tech,
      );
      expect(shift, '08:00 AM – 04:00 PM');
      expect(shift, isNot(equals('10:00 AM – 06:00 PM')));
    });

    test('Employee individual shift text override takes precedence over Telecalling department', () {
      const staff = Staff(
        id: 'tele-override-1',
        name: 'Flexible Telecalling Agent',
        department: Department.telecalling,
        shift: '11:00 AM – 07:00 PM',
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        department: Department.telecalling,
      );
      expect(shift, '11:00 AM – 07:00 PM');
      expect(shift, isNot(equals('09:00 AM – 06:00 PM')));
    });

    test('Backend attendance scheduleSnapshot overrides default department schedule', () {
      const staff = Staff(
        id: 'tech-snap-1',
        name: 'Tech Worker',
        department: Department.tech,
      );
      final attendance = Attendance(
        id: 'att-snap-1',
        staffId: 'tech-snap-1',
        date: DateTime.now().toIso8601String().substring(0, 10),
        checkInAt: DateTime.now(),
        scheduleSnapshot: const {
          'checkInTime': '07:30',
          'checkOutTime': '15:30',
        },
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        attendance: attendance,
        department: Department.tech,
      );
      expect(shift, '07:30 AM – 03:30 PM');
    });

    test('Missing schedule for unconfigured department resolves to Not Scheduled', () {
      const staff = Staff(
        id: 'unassigned-1',
        name: 'Unassigned Staff',
        department: 'Operations',
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        department: 'Operations',
      );
      expect(shift, 'Not Scheduled');
    });

    test('Missing schedule when attendance explicitly marks UNCONFIGURED resolves to Not Scheduled', () {
      const staff = Staff(
        id: 'tech-unconfigured',
        name: 'Tech Worker Unconfigured',
        department: Department.tech,
      );
      const attendance = Attendance(
        id: 'att-unconf',
        scheduleStatus: 'UNCONFIGURED',
        scheduleConfigured: false,
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        attendance: attendance,
        department: Department.tech,
      );
      expect(shift, 'Not Scheduled');
    });

    test('Missing schedule when staff.schedule marks scheduleStatus UNCONFIGURED', () {
      const staff = Staff(
        id: 'tech-staff-unconf',
        name: 'Tech Worker',
        department: Department.tech,
        schedule: {'scheduleStatus': 'UNCONFIGURED'},
      );
      final shift = resolveEffectiveShift(
        staff: staff,
        department: Department.tech,
      );
      expect(shift, 'Not Scheduled');
    });

    test('Attendance.fromJson parses backend schedule and lateness fields', () {
      const json = {
        '_id': 'att-backend-1',
        'employee': {'_id': 'staff-123'},
        'date': '2026-10-23T00:00:00.000Z',
        'checkIn': '2026-10-23T04:45:00.000Z',
        'status': 'LATE',
        'isLate': true,
        'minutesLate': 15,
        'scheduledCheckIn': '10:00',
        'scheduledCheckOut': '18:00',
        'scheduleStatus': 'CONFIGURED',
        'scheduleConfigured': true,
        'scheduleSnapshot': {
          'scheduledCheckIn': '10:00',
          'scheduledCheckOut': '18:00',
          'timezone': 'Asia/Kolkata',
        },
      };

      final att = Attendance.fromJson(json);
      expect(att.id, 'att-backend-1');
      expect(att.isLate, isTrue);
      expect(att.minutesLate, 15);
      expect(att.status, 'LATE');
      expect(att.scheduledCheckIn, '10:00');
      expect(att.scheduledCheckOut, '18:00');
      expect(att.scheduleStatus, 'CONFIGURED');
      expect(att.scheduleConfigured, isTrue);
      expect(att.scheduleSnapshot?['timezone'], 'Asia/Kolkata');
    });
  });

  group('StaffHub UI Shift Display Tests', () {
    testWidgets('Tech employee home screen displays Shift: 10:00 AM – 06:00 PM',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff-tech',
        name: 'Tech Employee',
        department: Department.tech,
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

      expect(find.text('Shift: 10:00 AM – 06:00 PM'), findsOneWidget);
      expect(find.text('Not Checked In'), findsOneWidget);
    });

    testWidgets(
        'Telecalling employee home screen displays Shift: 09:00 AM – 06:00 PM',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff-tele',
        name: 'Telecalling Employee',
        department: Department.telecalling,
        status: Status.active,
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffHubShell(
          repository: repository,
          pageIndex: 0,
          department: Department.telecalling,
          staff: staff,
          workMode: 'Office',
          workLocation: null,
          onNavigate: (_) {},
          onLogout: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Shift: 09:00 AM – 06:00 PM'), findsOneWidget);
      expect(find.text('Not Checked In'), findsOneWidget);
    });

    testWidgets('Employee with individual schedule override displays custom shift',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff-override',
        name: 'Shift Override Worker',
        department: Department.tech,
        status: Status.active,
        schedule: {
          'scheduledCheckIn': '08:00',
          'scheduledCheckOut': '16:00',
        },
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

      // Should display individual override and NOT the Tech default
      expect(find.text('Shift: 08:00 AM – 04:00 PM'), findsOneWidget);
      expect(find.text('Shift: 10:00 AM – 06:00 PM'), findsNothing);
    });

    testWidgets('Missing schedule displays Shift: Not Scheduled',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      const staff = Staff(
        id: 'staff-nosched',
        name: 'No Sched Worker',
        department: 'Operations',
        status: Status.active,
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffHubShell(
          repository: repository,
          pageIndex: 0,
          department: 'Operations',
          staff: staff,
          workMode: 'Office',
          workLocation: null,
          onNavigate: (_) {},
          onLogout: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Shift: Not Scheduled'), findsOneWidget);
    });

    testWidgets('Lateness and check-in status from backend are consistently reflected',
        (WidgetTester tester) async {
      final repository = MockHRRepository();
      final now = DateTime.now();
      const staff = Staff(
        id: 'staff-late',
        name: 'Late Worker',
        department: Department.tech,
        status: Status.active,
      );

      repository.attendanceList.value = [
        Attendance(
          id: 'att-late-1',
          staffId: 'staff-late',
          date: now.toIso8601String().substring(0, 10),
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkInTime: '10:30 AM',
          status: 'LATE',
          isLate: true,
          minutesLate: 30,
          scheduledCheckIn: '10:00',
          scheduledCheckOut: '18:00',
        ),
      ];

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

      // Shift is 10:00 AM – 06:00 PM
      expect(find.text('Shift: 10:00 AM – 06:00 PM'), findsOneWidget);
      // Status pill displays Late
      expect(find.text('Late'), findsOneWidget);
      // Check-in text displays checked-in time
      expect(find.textContaining('Checked in at'), findsOneWidget);
    });
  });
}
