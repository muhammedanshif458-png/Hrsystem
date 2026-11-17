import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'mock_hr_repository.dart';

class _CustomProfileMockRepository extends MockHRRepository {
  _CustomProfileMockRepository(this.customStaff);
  final Staff customStaff;

  @override
  Future<Staff> fetchProfile() async => customStaff;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildStaffHubShell({
    required MockHRRepository repository,
    int pageIndex = 3,
    String department = Department.tech,
    String workMode = 'Office',
    String? workLocation,
    Staff? customStaff,
  }) {
    final staff = customStaff ??
        Staff(
          id: 'EMP-2024-001',
          name: 'Rohan Sharma',
          email: 'rohan.sharma@lysoftware.com',
          phoneNumber: '+91 98765 43210',
          address: 'Bangalore, Karnataka, India',
          department: department,
          role: Role.staff,
          status: Status.active,
        );
    return MaterialApp(
      home: StaffHubShell(
        repository: repository,
        pageIndex: pageIndex,
        department: department,
        staff: staff,
        workMode: workMode,
        workLocation: workLocation,
        onNavigate: (_) {},
        onLogout: () {},
      ),
    );
  }

  group('StaffHub Profile and Settings Tests', () {
    testWidgets(
        '1. Personal Information is read-only and edit pencil icon is completely removed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final staff = Staff(
        id: 'EMP-2024-001',
        name: 'Rohan Sharma',
        email: 'rohan.sharma@lysoftware.com',
        phoneNumber: '+91 98765 43210',
        address: 'Bangalore, Karnataka, India',
        department: Department.tech,
        role: Role.staff,
        status: Status.active,
      );
      final repository = _CustomProfileMockRepository(staff);

      await tester.pumpWidget(buildStaffHubShell(
        repository: repository,
        customStaff: staff,
      ));
      await tester.pumpAndSettle();

      // Navigate to Profile from Settings
      final profileOption = find.text('Profile');
      expect(profileOption, findsOneWidget);
      await tester.tap(profileOption);
      await tester.pumpAndSettle();

      // Verify Personal Information section heading exists
      expect(find.text('Personal Information'), findsOneWidget);

      // Verify edit icon is NOT present anywhere on Personal Information section
      expect(find.byIcon(Icons.edit), findsNothing);

      // Verify personal details are displayed in read-only mode
      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('rohan.sharma@lysoftware.com'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Bangalore, Karnataka, India'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Work Mode'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);

      // Verify tapping personal information does not trigger any edit dialog
      await tester.tap(find.text('Personal Information'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsNothing);
    });

    testWidgets(
        '2. Privacy & Policy navigates to dedicated screen with all 7 required sections and back navigation works',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Tap Privacy & Policy
      final privacyOption = find.text('Privacy & Policy');
      expect(privacyOption, findsOneWidget);
      await tester.tap(privacyOption);
      await tester.pumpAndSettle();

      // Verify dedicated Privacy Policy screen is shown
      expect(find.byType(StaffPrivacyPolicyPage), findsOneWidget);

      // Verify all 7 required sections are present
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Information We Collect'), findsOneWidget);
      expect(find.text('How We Use Employee Information'), findsOneWidget);
      expect(find.text('Data Protection'), findsOneWidget);
      expect(find.text('Information Sharing'), findsOneWidget);
      expect(find.text('Employee Privacy Rights'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);

      // Verify back navigation returns to Profile page
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // We should be back on Profile page
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Privacy & Policy'), findsOneWidget);

      // Tapping back once more returns to Settings page
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets(
        '3. Terms & Conditions navigates to dedicated screen with all 8 required sections and back navigation works',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Tap Terms & Conditions
      final termsOption = find.text('Terms & Conditions');
      expect(termsOption, findsOneWidget);
      await tester.tap(termsOption);
      await tester.pumpAndSettle();

      // Verify dedicated Terms & Conditions screen is shown
      expect(find.byType(StaffTermsConditionsPage), findsOneWidget);

      // Verify all 8 required sections are present
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Employee Account Usage'), findsOneWidget);
      expect(find.text('Attendance Rules'), findsOneWidget);
      expect(find.text('Leave Policy'), findsOneWidget);
      expect(find.text('Workplace Responsibilities'), findsOneWidget);
      expect(find.text('Acceptable Use of the StaffHub Application'),
          findsOneWidget);
      expect(find.text('Account Security'), findsOneWidget);
      expect(find.text('Policy Updates'), findsOneWidget);

      // Verify back button returns to Profile
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
    });

    testWidgets(
        '4. Support & Helpdesk navigates to dedicated screen with Contact Support and all 5 expandable FAQs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Tap Support & Helpdesk
      final supportOption = find.text('Support & Helpdesk');
      expect(supportOption, findsOneWidget);
      await tester.tap(supportOption);
      await tester.pumpAndSettle();

      // Verify dedicated Support & Helpdesk screen is shown
      expect(find.byType(StaffSupportHelpdeskPage), findsOneWidget);

      // Verify Contact Support section and entries
      expect(find.text('CONTACT SUPPORT'), findsOneWidget);
      expect(find.text('HR Department'), findsOneWidget);
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('Phone Support'), findsOneWidget);

      // Verify Frequently Asked Questions section and all 5 questions
      expect(find.text('FREQUENTLY ASKED QUESTIONS (FAQ)'), findsOneWidget);
      expect(find.text('How can I mark attendance?'), findsOneWidget);
      expect(find.text('How can I apply for leave?'), findsOneWidget);
      expect(find.text('How can I check my attendance history?'), findsOneWidget);
      expect(find.text('How can I change my password?'), findsOneWidget);
      expect(
          find.text('What should I do if I face a technical issue?'),
          findsOneWidget);

      // Test expanding an FAQ item (e.g. "How can I mark attendance?")
      final faqQuestion = find.text('How can I mark attendance?');
      await tester.ensureVisible(faqQuestion);
      await tester.tap(faqQuestion);
      await tester.pumpAndSettle();

      // Verify the expanded answer content is revealed
      expect(
          find.textContaining('Navigate to the Punch page'),
          findsOneWidget);

      // Verify back navigation returns to Profile
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
    });

    testWidgets('5. Notifications switch can be toggled without error',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Find Notifications row and Switch
      expect(find.text('Notifications'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle switch
      final initialSwitch = tester.widget<Switch>(switchFinder);
      expect(initialSwitch.value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isFalse);
    });

    testWidgets(
        '6. Direct standalone navigation for Privacy Policy, Terms, and Support pages',
        (WidgetTester tester) async {
      // Test standalone mode with AppBar
      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPrivacyPolicyPage(isStandalone: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StaffPrivacyPolicyPage), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffTermsConditionsPage(isStandalone: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StaffTermsConditionsPage), findsOneWidget);
      expect(find.text('Employee Account Usage'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffSupportHelpdeskPage(isStandalone: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StaffSupportHelpdeskPage), findsOneWidget);
      expect(find.text('HR Department'), findsOneWidget);
    });
  });
}
