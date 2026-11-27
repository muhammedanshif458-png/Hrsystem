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

  testWidgets(
      'Leave Request Update card renders and can be cleared locally without mutating repository',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = MockHRRepository();
    const staff = Staff(
      id: 'staff_test_1',
      name: 'Shyam Sundar',
      email: 'shyam@company.com',
      department: Department.tech,
      role: Role.staff,
      status: Status.active,
    );

    repository.leaveRequests.value = [
      LeaveRequest(
        id: 'leave-101',
        staffId: 'staff_test_1',
        type: 'Sick Leave',
        fromDate: '2026-11-25',
        toDate: '2026-11-25',
        reason: 'Severe cold and fever',
        status: 'Approved',
        createdAt: DateTime(2026, 11, 25, 9, 0),
      ),
    ];

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
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify card is rendered with Leave Request Update title, Approved badge, and Clear button
    expect(find.text('Leave Request Update'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    final clearButtonFinder =
        find.byKey(const ValueKey('leave_update_clear_button'));
    expect(clearButtonFinder, findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Reason: Severe cold and fever'), findsOneWidget);
    expect(find.text('Your request has been approved by HR.'), findsOneWidget);

    // 2. Ensure visible and tap the Clear button
    await tester.ensureVisible(clearButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(clearButtonFinder);
    await tester.pumpAndSettle();

    // 3. Verify card is dismissed locally from the Home screen
    expect(find.text('Leave Request Update'), findsNothing);
    expect(find.text('Reason: Severe cold and fever'), findsNothing);

    // 4. Verify repository leave requests list is completely intact (not deleted/mutated)
    expect(repository.leaveRequests.value.length, 1);
    expect(repository.leaveRequests.value.first.id, 'leave-101');
    expect(repository.leaveRequests.value.first.status, 'Approved');

    // 5. If a new leave request or updated status comes in, card appears again
    repository.leaveRequests.value = [
      LeaveRequest(
        id: 'leave-102',
        staffId: 'staff_test_1',
        type: 'Casual Leave',
        fromDate: '2026-11-28',
        toDate: '2026-11-29',
        reason: 'Family event',
        status: 'Pending',
        createdAt: DateTime(2026, 11, 26, 10, 0),
      ),
      ...repository.leaveRequests.value,
    ];
    await tester.pumpAndSettle();

    // Verify new card shows up cleanly
    expect(find.text('Leave Request Update'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Reason: Family event'), findsOneWidget);
    expect(find.byKey(const ValueKey('leave_update_clear_button')),
        findsOneWidget);
  });
}
