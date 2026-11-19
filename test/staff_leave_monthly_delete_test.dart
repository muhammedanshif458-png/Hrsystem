import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/core/api/api_exception.dart';
import 'package:hr_core/staff_screens.dart';
import 'mock_hr_repository.dart';

void main() {
  late MockHRRepository repository;
  late Staff testStaff;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockHRRepository();
    testStaff = const Staff(
      id: 'staff_101',
      name: 'Rahul K',
      email: 'rahul@example.com',
      department: Department.tech,
      role: Role.staff,
      status: Status.active,
    );
    repository.currentUser.value = testStaff;
  });

  Widget buildStaffHub({
    required MockHRRepository repo,
    required Staff staff,
  }) {
    return MaterialApp(
      home: StaffHubShell(
        repository: repo,
        pageIndex: 2, // Leave tab
        department: Department.tech,
        staff: staff,
        workMode: 'Office',
        workLocation: null,
        onNavigate: (_) {},
        onLogout: () {},
      ),
    );
  }

  int getCountForCategory(WidgetTester tester, String categoryLabel) {
    final labelFinder = find.text(categoryLabel);
    expect(labelFinder, findsOneWidget);
    final columnFinder =
        find.ancestor(of: labelFinder, matching: find.byType(Column)).first;
    final textWidgets = tester.widgetList<Text>(
        find.descendant(of: columnFinder, matching: find.byType(Text)));
    final countText = textWidgets.elementAt(1).data;
    return int.parse(countText ?? '0');
  }

  group('Staff Leave – Delete / Hide Request Tests', () {
    testWidgets('1. Delete button displays with text Delete in Leave Details modal',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final leave = LeaveRequest(
        id: 'leave_hide_1',
        staffId: testStaff.id,
        type: 'Casual Leave',
        fromDate: '2026-11-20',
        toDate: '2026-11-21',
        reason: 'Personal reason',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 15),
      );

      repository.leaveRequests.value = [leave];

      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the leave item in history to open details
      final itemFinder = find.textContaining('Personal reason');
      expect(itemFinder, findsOneWidget);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      // Verify Delete button is visible and displays "Delete"
      expect(find.byKey(const ValueKey('delete_cancel_leave_button')),
          findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets(
        '2. Clicking Delete shows exact confirmation dialog and Cancel leaves history unchanged',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final leave = LeaveRequest(
        id: 'leave_hide_2',
        staffId: testStaff.id,
        type: 'Medical Leave',
        fromDate: '2026-11-01',
        toDate: '2026-11-02',
        reason: 'Medical checkup',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 1),
      );

      repository.leaveRequests.value = [leave];

      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Medical checkup'));
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.byKey(const ValueKey('delete_cancel_leave_button')));
      await tester.pumpAndSettle();

      // Verify dialog title and message
      expect(find.text('Remove this leave request from your history?'), findsOneWidget);
      expect(
          find.text(
              'This will only remove the request from your history. HR records and leave status will remain unchanged.'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsWidgets);

      // Tap Cancel in dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Request is still present in history
      expect(find.textContaining('Medical checkup'), findsOneWidget);
    });

    testWidgets(
        '3. Confirming Delete removes request from staff history UI immediately',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final leave1 = LeaveRequest(
        id: 'leave_hide_3a',
        staffId: testStaff.id,
        type: 'Casual Leave',
        fromDate: '2026-11-20',
        toDate: '2026-11-21',
        reason: 'Event to delete',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 18),
      );
      final leave2 = LeaveRequest(
        id: 'leave_hide_3b',
        staffId: testStaff.id,
        type: 'Casual Leave',
        fromDate: '2026-11-22',
        toDate: '2026-11-23',
        reason: 'Event to keep',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 19),
      );

      repository.leaveRequests.value = [leave1, leave2];

      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 total'), findsOneWidget);
      expect(find.textContaining('Event to delete'), findsOneWidget);
      expect(find.textContaining('Event to keep'), findsOneWidget);

      // Tap on leave1
      await tester.tap(find.textContaining('Event to delete'));
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.byKey(const ValueKey('delete_cancel_leave_button')));
      await tester.pumpAndSettle();

      // Confirm deletion in dialog
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // Verified: removed from Request History immediately
      expect(find.textContaining('Event to delete'), findsNothing);
      expect(find.textContaining('Event to keep'), findsOneWidget);
      expect(find.text('1 total'), findsOneWidget);
    });

    testWidgets(
        '4. Deleting a request does NOT delete from backend and does NOT change monthly leave summary counts',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final leave = LeaveRequest(
        id: 'leave_hide_4',
        staffId: testStaff.id,
        type: 'Casual Leave',
        fromDate: '2026-11-20',
        toDate: '2026-11-21',
        reason: 'Doctor appointment',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 18),
      );

      repository.leaveRequests.value = [leave];

      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      // Monthly Casual Leave count is 1
      expect(getCountForCategory(tester, 'CASUAL LEAVE'), equals(1));

      // Open detail sheet and delete
      await tester.tap(find.textContaining('Doctor appointment'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete_cancel_leave_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // 1. CRITICAL: Backend repository still retains the leave request
      expect(repository.leaveRequests.value.any((r) => r.id == 'leave_hide_4'), isTrue);
      expect(repository.leaveRequests.value.firstWhere((r) => r.id == 'leave_hide_4').status, equals('Pending'));

      // 2. CRITICAL: Monthly Leave summary count is STILL 1 (unchanged)
      expect(getCountForCategory(tester, 'CASUAL LEAVE'), equals(1));

      // 3. Request history shows empty state
      expect(find.text('No leave requests submitted yet.'), findsOneWidget);
    });

    testWidgets(
        '5. Hidden requests persist across app reloads and are isolated per employee',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const telecallingStaff = Staff(
        id: 'tele_102',
        name: 'Priya S',
        email: 'priya@example.com',
        department: Department.telecalling,
        role: Role.staff,
        status: Status.active,
      );

      final leaveTech = LeaveRequest(
        id: 'leave_tech_persist',
        staffId: testStaff.id,
        type: 'Casual Leave',
        fromDate: '2026-11-20',
        toDate: '2026-11-21',
        reason: 'Tech personal leave',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 18),
      );

      final leaveTele = LeaveRequest(
        id: 'leave_tele_persist',
        staffId: telecallingStaff.id,
        type: 'Casual Leave',
        fromDate: '2026-11-20',
        toDate: '2026-11-21',
        reason: 'Telecalling personal leave',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 18),
      );

      repository.leaveRequests.value = [leaveTech, leaveTele];

      // 1. Tech staff logs in, deletes leave_tech_persist from history
      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Tech personal leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete_cancel_leave_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Tech personal leave'), findsNothing);

      // 2. Re-pump widget for Tech staff (simulating refresh/reopen) -> remains hidden
      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tech personal leave'), findsNothing);

      // 3. Telecalling staff logs in -> their request is NOT hidden
      repository.currentUser.value = telecallingStaff;
      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: telecallingStaff,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Telecalling personal leave'), findsOneWidget);
    });
  });

  group('Task 2: Staff Leave – Monthly Leave Summary Tests', () {
    testWidgets(
        '5. Monthly Leave Summary counts ONLY current calendar month applications based on createdAt',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final currentMonthDate = DateTime(2026, 11, 15);
      final lastMonthDate = DateTime(2026, 10, 15);
      final nextMonthDate = DateTime(2026, 12, 15);
      final lastYearDate = DateTime(2025, 11, 15);

      repository.leaveRequests.value = [
        // ── Current Month (November 2026) ──
        LeaveRequest(
          id: 'c_curr_1',
          staffId: testStaff.id,
          type: 'Casual Leave',
          fromDate: '2026-11-02',
          toDate: '2026-11-03',
          reason: 'Current Month Casual 1',
          status: 'Approved',
          createdAt: currentMonthDate,
        ),
        LeaveRequest(
          id: 'c_curr_2',
          staffId: testStaff.id,
          type: 'Casual Leave',
          fromDate: '2026-11-05',
          toDate: '2026-11-05',
          reason: 'Current Month Casual 2',
          status: 'Pending',
          createdAt: currentMonthDate,
        ),
        LeaveRequest(
          id: 'm_curr_1',
          staffId: testStaff.id,
          type: 'Medical Leave',
          fromDate: '2026-11-10',
          toDate: '2026-11-11',
          reason: 'Current Month Medical',
          status: 'Approved',
          createdAt: currentMonthDate,
        ),
        LeaveRequest(
          id: 'e_curr_1',
          staffId: testStaff.id,
          type: 'Earned Leave',
          fromDate: '2026-11-20',
          toDate: '2026-11-22',
          reason: 'Current Month Earned',
          status: 'Pending',
          createdAt: currentMonthDate,
        ),
        LeaveRequest(
          id: 's_curr_1',
          staffId: testStaff.id,
          type: 'Sick Leave',
          fromDate: '2026-11-18',
          toDate: '2026-11-18',
          reason: 'Current Month Sick 1',
          status: 'Approved',
          createdAt: currentMonthDate,
        ),
        LeaveRequest(
          id: 's_curr_2',
          staffId: testStaff.id,
          type: 'Sick Leave',
          fromDate: '2026-11-19',
          toDate: '2026-11-19',
          reason: 'Current Month Sick 2',
          status: 'Pending',
          createdAt: currentMonthDate,
        ),
        LeaveRequest(
          id: 's_curr_3',
          staffId: testStaff.id,
          type: 'Sick Leave',
          fromDate: '2026-11-20',
          toDate: '2026-11-20',
          reason: 'Current Month Sick 3',
          status: 'Approved',
          createdAt: currentMonthDate,
        ),
        // Plus 1 cancelled current month request (must be excluded)
        LeaveRequest(
          id: 'c_curr_can',
          staffId: testStaff.id,
          type: 'Casual Leave',
          fromDate: '2026-11-12',
          toDate: '2026-11-13',
          reason: 'Cancelled Casual',
          status: 'Cancelled',
          createdAt: currentMonthDate,
        ),

        // ── Previous Month (October 2026) – Must NOT be counted ──
        LeaveRequest(
          id: 'c_prev_1',
          staffId: testStaff.id,
          type: 'Casual Leave',
          fromDate: '2026-10-10',
          toDate: '2026-10-11',
          reason: 'Previous Month Casual',
          status: 'Approved',
          createdAt: lastMonthDate,
        ),
        LeaveRequest(
          id: 'm_prev_1',
          staffId: testStaff.id,
          type: 'Medical Leave',
          fromDate: '2026-10-15',
          toDate: '2026-10-16',
          reason: 'Previous Month Medical',
          status: 'Approved',
          createdAt: lastMonthDate,
        ),

        // ── Next Month (December 2026) – Must NOT be counted ──
        LeaveRequest(
          id: 'e_next_1',
          staffId: testStaff.id,
          type: 'Earned Leave',
          fromDate: '2026-12-05',
          toDate: '2026-12-06',
          reason: 'Future Month Earned',
          status: 'Approved',
          createdAt: nextMonthDate,
        ),

        // ── Previous Year (November 2025) – Must NOT be counted ──
        LeaveRequest(
          id: 's_prev_year_1',
          staffId: testStaff.id,
          type: 'Sick Leave',
          fromDate: '2025-11-15',
          toDate: '2025-11-16',
          reason: 'Last Year Sick',
          status: 'Approved',
          createdAt: lastYearDate,
        ),
      ];

      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      // Expected Current Month counts (Nov 2026):
      // - Casual Leave: 2 (2 approved/pending, 1 cancelled excluded, 1 from Oct excluded)
      // - Medical Leave: 1 (1 current, 1 from Oct excluded)
      // - Earned Leave: 1 (1 current, 1 from Dec excluded)
      // - Sick Leave: 3 (3 current, 1 from 2025 excluded)
      expect(getCountForCategory(tester, 'CASUAL LEAVE'), equals(2));
      expect(getCountForCategory(tester, 'MEDICAL LEAVE'), equals(1));
      expect(getCountForCategory(tester, 'EARNED LEAVE'), equals(1));
      expect(getCountForCategory(tester, 'SICK LEAVE'), equals(3));
    });

    testWidgets('6. Empty categories display 0 in the summary card',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // No leave requests at all
      repository.leaveRequests.value = [];

      await tester.pumpWidget(
        buildStaffHub(
          repo: repository,
          staff: testStaff,
        ),
      );
      await tester.pumpAndSettle();

      expect(getCountForCategory(tester, 'CASUAL LEAVE'), equals(0));
      expect(getCountForCategory(tester, 'MEDICAL LEAVE'), equals(0));
      expect(getCountForCategory(tester, 'EARNED LEAVE'), equals(0));
      expect(getCountForCategory(tester, 'SICK LEAVE'), equals(0));
    });
  });
}

class _FailingDeleteMockHRRepository extends MockHRRepository {
  @override
  Future<void> deleteLeaveRequest(String requestId) async {
    throw ApiException(
      statusCode: 500,
      message: 'Backend database error',
    );
  }
}
