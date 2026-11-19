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

  Widget buildStaffHub({
    required MockHRRepository repository,
    required Staff staff,
  }) {
    return MaterialApp(
      home: StaffHubShell(
        repository: repository,
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

  testWidgets('1. Dynamic Leave Counts: Two different staff see only their own application counts',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = MockHRRepository();

    const rahul = Staff(
      id: 'staff_rahul_01',
      name: 'Rahul K',
      email: 'rahul@example.com',
      department: Department.tech,
      role: Role.staff,
      status: Status.active,
    );

    const priya = Staff(
      id: 'staff_priya_02',
      name: 'Priya S',
      email: 'priya@example.com',
      department: Department.tech,
      role: Role.staff,
      status: Status.active,
    );

    // Populate repository with leave requests for both staff members:
    // Rahul:
    // - 3 Casual Leave
    // - 1 Medical Leave
    // - 2 Earned Leave
    // - 0 Sick Leave
    // Plus 1 Cancelled Casual Leave (must be excluded)
    //
    // Priya:
    // - 1 Casual Leave
    // - 0 Medical Leave
    // - 0 Earned Leave
    // - 4 Sick Leave
    repository.leaveRequests.value = [
      // Rahul's leaves:
      LeaveRequest(
        id: 'r_c1',
        staffId: rahul.id,
        type: 'Casual Leave',
        fromDate: '2026-11-01',
        toDate: '2026-11-02',
        reason: 'Casual 1',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 1),
      ),
      LeaveRequest(
        id: 'r_c2',
        staffId: rahul.id,
        type: 'Casual Leave',
        fromDate: '2026-11-05',
        toDate: '2026-11-05',
        reason: 'Casual 2',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 5),
      ),
      LeaveRequest(
        id: 'r_c3',
        staffId: rahul.id,
        type: 'Casual Leave',
        fromDate: '2026-11-08',
        toDate: '2026-11-09',
        reason: 'Casual 3',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 8),
      ),
      LeaveRequest(
        id: 'r_c_cancelled',
        staffId: rahul.id,
        type: 'Casual Leave',
        fromDate: '2026-11-12',
        toDate: '2026-11-13',
        reason: 'Cancelled request',
        status: 'Cancelled',
        createdAt: DateTime(2026, 11, 12),
      ),
      LeaveRequest(
        id: 'r_m1',
        staffId: rahul.id,
        type: 'Medical Leave',
        fromDate: '2026-11-15',
        toDate: '2026-11-16',
        reason: 'Medical 1',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 15),
      ),
      LeaveRequest(
        id: 'r_e1',
        staffId: rahul.id,
        type: 'Earned Leave',
        fromDate: '2026-11-20',
        toDate: '2026-11-22',
        reason: 'Earned 1',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 20),
      ),
      LeaveRequest(
        id: 'r_e2',
        staffId: rahul.id,
        type: 'Earned Leave',
        fromDate: '2026-11-25',
        toDate: '2026-11-26',
        reason: 'Earned 2',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 25),
      ),

      // Priya's leaves:
      LeaveRequest(
        id: 'p_c1',
        staffId: priya.id,
        type: 'Casual Leave',
        fromDate: '2026-11-02',
        toDate: '2026-11-03',
        reason: 'Priya Casual 1',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 2),
      ),
      LeaveRequest(
        id: 'p_s1',
        staffId: priya.id,
        type: 'Sick Leave',
        fromDate: '2026-11-04',
        toDate: '2026-11-04',
        reason: 'Priya Sick 1',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 4),
      ),
      LeaveRequest(
        id: 'p_s2',
        staffId: priya.id,
        type: 'Sick Leave',
        fromDate: '2026-11-06',
        toDate: '2026-11-06',
        reason: 'Priya Sick 2',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 6),
      ),
      LeaveRequest(
        id: 'p_s3',
        staffId: priya.id,
        type: 'Sick Leave',
        fromDate: '2026-11-10',
        toDate: '2026-11-11',
        reason: 'Priya Sick 3',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 10),
      ),
      LeaveRequest(
        id: 'p_s4',
        staffId: priya.id,
        type: 'Sick Leave',
        fromDate: '2026-11-14',
        toDate: '2026-11-14',
        reason: 'Priya Sick 4',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 14),
      ),
    ];

    // ==========================================
    // STEP 1: Render Leave Page for Rahul
    // ==========================================
    repository.currentUser.value = rahul;
    await tester.pumpWidget(buildStaffHub(repository: repository, staff: rahul));
    await tester.pumpAndSettle();

    // Helper to find the count displayed next to a card label
    int getCountForCategory(String categoryLabel) {
      final labelFinder = find.text(categoryLabel);
      expect(labelFinder, findsOneWidget);
      final columnFinder = find.ancestor(of: labelFinder, matching: find.byType(Column)).first;
      final textWidgets = tester.widgetList<Text>(find.descendant(of: columnFinder, matching: find.byType(Text)));
      // The second Text in the Column is the count
      final countText = textWidgets.elementAt(1).data;
      return int.parse(countText ?? '0');
    }

    // Verify Rahul's counts:
    // Casual Leave: 3 (cancelled one excluded)
    // Medical Leave: 1
    // Earned Leave: 2
    // Sick Leave: 0 (empty category displays 0)
    expect(getCountForCategory('CASUAL LEAVE'), equals(3));
    expect(getCountForCategory('MEDICAL LEAVE'), equals(1));
    expect(getCountForCategory('EARNED LEAVE'), equals(2));
    expect(getCountForCategory('SICK LEAVE'), equals(0));

    // ==========================================
    // STEP 2: Render Leave Page for Priya
    // ==========================================
    repository.currentUser.value = priya;
    await tester.pumpWidget(buildStaffHub(repository: repository, staff: priya));
    await tester.pumpAndSettle();

    // Verify Priya's counts:
    // Casual Leave: 1
    // Medical Leave: 0
    // Earned Leave: 0
    // Sick Leave: 4
    expect(getCountForCategory('CASUAL LEAVE'), equals(1));
    expect(getCountForCategory('MEDICAL LEAVE'), equals(0));
    expect(getCountForCategory('EARNED LEAVE'), equals(0));
    expect(getCountForCategory('SICK LEAVE'), equals(4));

    // ==========================================
    // STEP 3: Submitting new application updates count dynamically
    // ==========================================
    repository.currentUser.value = rahul;
    await tester.pumpWidget(buildStaffHub(repository: repository, staff: rahul));
    await tester.pumpAndSettle();

    // Add a new Sick Leave for Rahul
    repository.leaveRequests.value = [
      LeaveRequest(
        id: 'r_s1_new',
        staffId: rahul.id,
        type: 'Sick Leave',
        fromDate: '2026-11-28',
        toDate: '2026-11-28',
        reason: 'New headache',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 28),
      ),
      ...repository.leaveRequests.value,
    ];
    await tester.pumpAndSettle();

    // Rahul's Sick Leave count must now be 1
    expect(getCountForCategory('SICK LEAVE'), equals(1));
    expect(getCountForCategory('CASUAL LEAVE'), equals(3));
  });
}

