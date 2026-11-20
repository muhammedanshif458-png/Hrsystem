import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:hr_core/hr_repository.dart';
import 'mock_hr_repository.dart';

// Spy repository to capture exact leave request arguments
class SpyHRRepository extends MockHRRepository {
  String? lastSubmittedType;
  String? lastSubmittedStaffId;
  String? lastSubmittedFromDate;
  String? lastSubmittedToDate;
  String? lastSubmittedReason;
  String? lastSubmittedDocName;
  Uint8List? lastSubmittedDocBytes;
  int requestLeaveCallCount = 0;

  @override
  Future<void> requestLeave({
    required String staffId,
    required String fromDate,
    required String toDate,
    required String reason,
    String type = 'Casual Leave',
    String durationType = 'FULL_DAY',
    String? halfDaySession,
    String? documentName,
    String? documentUrl,
    Uint8List? documentBytes,
  }) async {
    requestLeaveCallCount++;
    lastSubmittedType = type;
    lastSubmittedStaffId = staffId;
    lastSubmittedFromDate = fromDate;
    lastSubmittedToDate = toDate;
    lastSubmittedReason = reason;
    lastSubmittedDocName = documentName;
    lastSubmittedDocBytes = documentBytes;

    final newReq = LeaveRequest(
      id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
      staffId: staffId,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      type: type,
      documentName: documentName,
      documentUrl: documentUrl,
      createdAt: DateTime.now(),
    );
    leaveRequests.value = [newReq, ...leaveRequests.value];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestShell({
    required MockHRRepository repository,
    int pageIndex = 2, // Leave tab
  }) {
    const staff = Staff(
      id: 'staff_leave_test_01',
      name: 'Priya Sharma',
      email: 'priya.sharma@lysoftware.com',
      department: Department.tech,
      role: Role.staff,
      status: Status.active,
    );
    return MaterialApp(
      home: StaffHubShell(
        repository: repository,
        pageIndex: pageIndex,
        department: Department.tech,
        staff: staff,
        workMode: 'Office',
        workLocation: null,
        onNavigate: (_) {},
        onLogout: () {},
      ),
    );
  }

  group('Leave Type Mapping in HRRepositoryImpl', () {
    test('1. SICK leave type mappings remain strictly isolated from MEDICAL', () {
      final repo = HRRepositoryImpl();

      // Sick Leave -> SICK
      expect(repo.mapLeaveTypeToBackend('Sick Leave'), equals('SICK'));
      expect(repo.mapLeaveTypeToBackend('SICK'), equals('SICK'));
      expect(repo.mapLeaveTypeToBackend('SICK LEAVE'), equals('SICK'));

      // Medical Leave -> MEDICAL (NOT SICK!)
      expect(repo.mapLeaveTypeToBackend('Medical Leave'), equals('MEDICAL'));
      expect(repo.mapLeaveTypeToBackend('MEDICAL'), equals('MEDICAL'));
      expect(repo.mapLeaveTypeToBackend('MEDICAL LEAVE'), equals('MEDICAL'));

      // Other standard leaves
      expect(repo.mapLeaveTypeToBackend('Casual Leave'), equals('CASUAL'));
      expect(repo.mapLeaveTypeToBackend('Earned Leave'), equals('ANNUAL'));
      expect(repo.mapLeaveTypeToBackend('Unpaid Leave'), equals('UNPAID'));
    });

    test('2. Backend SICK response maps to Sick Leave regardless of document attachment', () {
      final repo = HRRepositoryImpl();

      // SICK with NO document -> Sick Leave
      expect(repo.mapBackendLeaveTypeToUi('SICK', hasDoc: false), equals('Sick Leave'));

      // SICK with document attached -> MUST REMAIN Sick Leave!
      expect(repo.mapBackendLeaveTypeToUi('SICK', hasDoc: true), equals('Sick Leave'));

      // SICK with backend displayType
      expect(repo.mapBackendLeaveTypeToUi('SICK', displayType: 'Sick Leave', hasDoc: true),
          equals('Sick Leave'));

      // MEDICAL with document -> Medical Leave
      expect(repo.mapBackendLeaveTypeToUi('MEDICAL', hasDoc: true), equals('Medical Leave'));
      expect(repo.mapBackendLeaveTypeToUi('MEDICAL', displayType: 'Medical Leave'),
          equals('Medical Leave'));

      // Other types
      expect(repo.mapBackendLeaveTypeToUi('CASUAL'), equals('Casual Leave'));
      expect(repo.mapBackendLeaveTypeToUi('ANNUAL'), equals('Earned Leave'));
      expect(repo.mapBackendLeaveTypeToUi('UNPAID'), equals('Unpaid Leave'));
    });
  });

  group('StaffHub Leave UI – Sick Leave vs Medical Leave Flow', () {
    testWidgets('3. Sick Leave can be submitted without medical proof',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = SpyHRRepository();
      await tester.pumpWidget(buildTestShell(repository: repository, pageIndex: 2));
      await tester.pumpAndSettle();

      // Select 'Sick Leave' from dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sick Leave').last);
      await tester.pumpAndSettle();

      // Enter reason
      final reasonField = find.byType(TextField).first;
      await tester.ensureVisible(reasonField);
      await tester.enterText(reasonField, 'Recovering from viral fever and headache');
      await tester.pumpAndSettle();

      // Helper text confirms medical proof is optional
      expect(find.text('Submit as soon as possible. Medical proof is optional.'), findsOneWidget);
      expect(find.text('Medical Document (Optional)'), findsOneWidget);
      expect(find.text('No document attached (Optional)'), findsOneWidget);

      // Submit leave request without attaching document
      final submitBtn = find.widgetWithText(FilledButton, 'Submit Request');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verified: request was submitted successfully
      expect(repository.requestLeaveCallCount, equals(1));
      expect(repository.lastSubmittedType, equals('Sick Leave'));
      expect(repository.lastSubmittedDocBytes, isNull);
      expect(repository.lastSubmittedDocName, isNull);
      expect(find.text('Leave request submitted. Check Home for the update.'), findsOneWidget);

      // History tile displays 'Sick Leave'
      expect(find.text('Sick Leave'), findsWidgets);
    });

    testWidgets('4. Medical Leave requires medical proof before submission',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = SpyHRRepository();
      await tester.pumpWidget(buildTestShell(repository: repository, pageIndex: 2));
      await tester.pumpAndSettle();

      // Select 'Medical Leave' from dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Medical Leave').last);
      await tester.pumpAndSettle();

      // Enter valid reason
      final reasonField = find.byType(TextField).first;
      await tester.ensureVisible(reasonField);
      await tester.enterText(reasonField, 'Hospitalized for minor knee surgery');
      await tester.pumpAndSettle();

      // Helper text confirms medical proof is required
      expect(find.text('Submit as soon as possible. Medical proof is required.'), findsOneWidget);
      expect(find.text('Medical Document (Required)'), findsOneWidget);

      // Attempt to submit WITHOUT proof
      final submitBtn = find.widgetWithText(FilledButton, 'Submit Request');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Blocked! Error snackbar displayed
      expect(repository.requestLeaveCallCount, equals(0));
      expect(find.text('Medical proof document is required for Medical Leave.'), findsOneWidget);
    });

    testWidgets('5. Leave history displays Sick Leave and Medical Leave as distinct records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = SpyHRRepository();
      repository.leaveRequests.value = [
        LeaveRequest(
          id: 'leave_sick_1',
          staffId: 'staff_leave_test_01',
          type: 'Sick Leave',
          fromDate: '2026-11-04',
          toDate: '2026-11-05',
          reason: 'Fever and cold',
          documentName: 'rx_slip.pdf',
          status: 'Approved',
          createdAt: DateTime(2026, 11, 4),
        ),
        LeaveRequest(
          id: 'leave_med_1',
          staffId: 'staff_leave_test_01',
          type: 'Medical Leave',
          fromDate: '2026-11-01',
          toDate: '2026-11-03',
          reason: 'Orthopedic treatment',
          documentName: 'hospital_admission.pdf',
          status: 'Pending',
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      await tester.pumpWidget(buildTestShell(repository: repository, pageIndex: 2));
      await tester.pumpAndSettle();

      // Both records appear in Leave History with their distinct types
      expect(find.text('Sick Leave'), findsOneWidget);
      expect(find.text('Medical Leave'), findsOneWidget);

      // Tap Sick Leave to view details sheet
      await tester.tap(find.text('Sick Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Leave Details'), findsOneWidget);
      expect(find.text('Sick Leave'), findsWidgets);
      expect(find.text('rx_slip.pdf'), findsWidgets);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap Medical Leave to view details sheet
      await tester.tap(find.text('Medical Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Leave Details'), findsOneWidget);
      expect(find.text('Medical Leave'), findsWidgets);
      expect(find.text('hospital_admission.pdf'), findsWidgets);
    });

    testWidgets('6. Staff Home active leave card shows correct Sick Leave and Medical Leave types',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = SpyHRRepository();
      repository.leaveRequests.value = [
        LeaveRequest(
          id: 'leave_sick_active',
          staffId: 'staff_leave_test_01',
          type: 'Sick Leave',
          fromDate: '2026-11-06',
          toDate: '2026-11-07',
          reason: 'Severe migraine',
          status: 'Pending',
          createdAt: DateTime(2026, 11, 6),
        ),
      ];

      // Navigate to Home tab (pageIndex: 0)
      await tester.pumpWidget(buildTestShell(repository: repository, pageIndex: 0));
      await tester.pumpAndSettle();

      // Verified: Sick Leave appears on Home card
      expect(find.text('Leave Request Update'), findsOneWidget);
      expect(find.textContaining('Sick Leave'), findsOneWidget);
      expect(find.textContaining('Medical Leave'), findsNothing);
    });
  });
}

