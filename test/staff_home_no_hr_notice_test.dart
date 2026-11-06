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
      id: 'staff_home_01',
      name: 'Rohan Sharma',
      email: 'rohan@lysoftware.com',
      department: department,
      role: Role.staff,
      status: Status.active,
    );
    return MaterialApp(
      home: StaffHubShell(
        repository: repository,
        pageIndex: 0, // Home Page
        department: department,
        staff: staff,
        workMode: workMode,
        workLocation: null,
        onNavigate: (_) {},
        onLogout: () {},
      ),
    );
  }

  group('StaffHub Home – HR Notice Removal & Features Preservation', () {
    testWidgets(
        '1. Tech staff Home screen does not display HR Notice card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();

      await tester.pumpWidget(buildTestShell(
        repository: repository,
        department: Department.tech,
      ));
      await tester.pumpAndSettle();

      // Verify HR Notice is completely absent
      expect(find.text('HR Notice'), findsNothing);
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      expect(
          find.textContaining(
              'Office will start at 9:30 AM tomorrow for scheduled infrastructure maintenance.'),
          findsNothing);

      // Verify all preserved features remain present on Tech Home
      expect(find.text('ACTIVE TIME'), findsOneWidget);
      expect(find.text('Daily Work Update'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Punch'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets(
        '2. Telecalling staff Home screen does not display HR Notice card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();

      await tester.pumpWidget(buildTestShell(
        repository: repository,
        department: Department.telecalling,
      ));
      await tester.pumpAndSettle();

      // Verify HR Notice is completely absent
      expect(find.text('HR Notice'), findsNothing);
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      expect(
          find.textContaining(
              'Office will start at 9:30 AM tomorrow for scheduled infrastructure maintenance.'),
          findsNothing);

      // Verify all preserved features remain present on Telecalling Home
      expect(find.text('ACTIVE TIME'), findsOneWidget);
      expect(find.text('Daily Work Update'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Punch'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets(
        '3. Spacing and layout are clean with and without leave updates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      repository.leaveRequests.value = [
        LeaveRequest(
          id: 'leave_1',
          staffId: 'staff_home_01',
          type: 'Casual Leave',
          fromDate: '2026-11-10',
          toDate: '2026-11-11',
          reason: 'Personal errands',
          status: 'Approved',
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      await tester.pumpWidget(buildTestShell(
        repository: repository,
        department: Department.tech,
      ));
      await tester.pumpAndSettle();

      expect(find.text('HR Notice'), findsNothing);
      expect(find.text('Daily Work Update'), findsOneWidget);
      expect(find.text('Leave Request Update'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
    });
  });
}

