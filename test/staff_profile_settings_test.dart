import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:hr_core/profile_page.dart';
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

  group('StaffHub Profile Page Navigation Tests', () {
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
        '2. Profile page: Privacy & Policy opens StaffPrivacyPolicyPage and back button returns to Profile (not Settings)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile from Settings
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);

      // Tap Privacy & Policy from Profile
      final privacyOption = find.text('Privacy & Policy');
      expect(privacyOption, findsOneWidget);
      await tester.tap(privacyOption);
      await tester.pumpAndSettle();

      // Verify dedicated StaffPrivacyPolicyPage screen is shown
      expect(find.byType(StaffPrivacyPolicyPage), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Information We Collect'), findsOneWidget);
      expect(find.text('How We Use Employee Information'), findsOneWidget);
      expect(find.text('Data Protection'), findsOneWidget);
      expect(find.text('Information Sharing'), findsOneWidget);
      expect(find.text('Employee Privacy Rights'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);

      // Tap back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // VERIFY: We are back on the PROFILE page, NOT the Settings page
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Privacy & Policy'), findsOneWidget);
      expect(find.text('ACCOUNT ACTIONS'), findsNothing); // Settings page is NOT visible
    });

    testWidgets(
        '3. Profile page: Terms & Conditions opens StaffTermsConditionsPage and back button returns to Profile (not Settings)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile from Settings
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);

      // Tap Terms & Conditions from Profile
      final termsOption = find.text('Terms & Conditions');
      expect(termsOption, findsOneWidget);
      await tester.tap(termsOption);
      await tester.pumpAndSettle();

      // Verify dedicated StaffTermsConditionsPage screen is shown
      expect(find.byType(StaffTermsConditionsPage), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Employee Account Usage'), findsOneWidget);
      expect(find.text('Attendance Rules'), findsOneWidget);
      expect(find.text('Leave Policy'), findsOneWidget);
      expect(find.text('Workplace Responsibilities'), findsOneWidget);
      expect(find.text('Acceptable Use of the StaffHub Application'),
          findsOneWidget);
      expect(find.text('Account Security'), findsOneWidget);
      expect(find.text('Policy Updates'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // VERIFY: Back on the PROFILE page, NOT the Settings page
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('ACCOUNT ACTIONS'), findsNothing);
    });

    testWidgets(
        '4. Profile page: Support & Helpdesk opens StaffSupportHelpdeskPage and back button returns to Profile (not Settings)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // Open Profile from Settings
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);

      // Tap Support & Helpdesk from Profile
      final supportOption = find.text('Support & Helpdesk');
      expect(supportOption, findsOneWidget);
      await tester.tap(supportOption);
      await tester.pumpAndSettle();

      // Verify dedicated StaffSupportHelpdeskPage screen is shown
      expect(find.byType(StaffSupportHelpdeskPage), findsOneWidget);
      expect(find.text('CONTACT SUPPORT'), findsOneWidget);
      expect(find.text('HR Department'), findsOneWidget);
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('Phone Support'), findsOneWidget);
      expect(find.text('FREQUENTLY ASKED QUESTIONS (FAQ)'), findsOneWidget);

      // Expand FAQ item
      final faqQuestion = find.text('How can I mark attendance?');
      await tester.ensureVisible(faqQuestion);
      await tester.tap(faqQuestion);
      await tester.pumpAndSettle();
      expect(find.textContaining('Navigate to the Punch page'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // VERIFY: Back on the PROFILE page, NOT the Settings page
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Support & Helpdesk'), findsOneWidget);
      expect(find.text('ACCOUNT ACTIONS'), findsNothing);
    });

    testWidgets(
        '5. Settings page navigation remains working correctly and independently',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = MockHRRepository();
      await tester.pumpWidget(buildStaffHubShell(repository: repository));
      await tester.pumpAndSettle();

      // 1. Settings -> Privacy Policy
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffPrivacyPolicyPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);

      // 2. Settings -> Terms & Conditions
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffTermsConditionsPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);

      // 3. Settings -> Support & Helpdesk
      await tester.tap(find.text('Support & Helpdesk'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffSupportHelpdeskPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
    });

    testWidgets(
        '6. Standalone ProfilePage (profile_page.dart) connects to the same destination screens',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      // Tap Privacy & Policy
      final privacyFinder = find.text('Privacy & Policy');
      expect(privacyFinder, findsOneWidget);
      await tester.ensureVisible(privacyFinder);
      await tester.tap(privacyFinder);
      await tester.pumpAndSettle();
      expect(find.byType(StaffPrivacyPolicyPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Tap Terms & Conditions
      final termsFinder = find.text('Terms & Conditions');
      expect(termsFinder, findsOneWidget);
      await tester.ensureVisible(termsFinder);
      await tester.tap(termsFinder);
      await tester.pumpAndSettle();
      expect(find.byType(StaffTermsConditionsPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Tap Support & Helpdesk
      final supportFinder = find.text('Support & Helpdesk');
      expect(supportFinder, findsOneWidget);
      await tester.ensureVisible(supportFinder);
      await tester.tap(supportFinder);
      await tester.pumpAndSettle();
      expect(find.byType(StaffSupportHelpdeskPage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Back on ProfilePage
      expect(find.text('PROFILE'), findsOneWidget);
    });
  });
}
