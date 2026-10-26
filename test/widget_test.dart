// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mock_hr_repository.dart';

import 'package:hr_core/main.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/profile_page.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('break schedule is informational and break allowances remain configured', () async {
    final day = DateTime(2026, 9, 24);
    expect(AttendanceBreakSchedule.canStart(DateTime(2026, 9, 24, 11, 29), 0), isFalse);
    expect(AttendanceBreakSchedule.canStart(DateTime(2026, 9, 24, 11, 30), 0), isTrue);
    expect(AttendanceBreakSchedule.startsAt(day, 1), DateTime(2026, 9, 24, 13, 30));
    expect(AttendanceBreakSchedule.startsAt(day, 2), DateTime(2026, 9, 24, 16));

    SharedPreferences.setMockInitialValues({});
    final repository = MockHRRepository();
    final attendance = await repository.checkIn('staff_break_test');
    await repository.toggleBreak(attendance.id, breakType: 'afternoon');
    expect(repository.attendanceList.value.single.breaks.single.breakType, 'afternoon');

    final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
    final expiredBreak = AttendanceBreak(
      id: 'expired_break',
      attendanceId: attendance.id,
      breakType: 'morning',
      startTime: startedAt,
    );
    final updated = attendance.copyWith(
      breaks: [expiredBreak],
      breakStartedAt: startedAt,
    );
    repository.attendanceList.value = [updated];

    await repository.endExpiredBreak(updated.id);

    final endedBreak = repository.attendanceList.value.single.breaks.single;
    expect(endedBreak.isActive, isFalse);
    expect(endedBreak.durationSeconds, 15 * 60);
    expect(endedBreak.endTime, startedAt.add(const Duration(minutes: 15)));
    expect(repository.attendanceList.value.single.totalBreakSeconds, 15 * 60);
    expect(
      AttendanceBreak(
        id: 'lunch_break',
        attendanceId: attendance.id,
        breakType: 'lunch',
        startTime: startedAt,
      ).durationAt(startedAt.add(const Duration(minutes: 45))),
      30 * 60,
    );
    expect(
      AttendanceBreak(
        id: 'afternoon_break',
        attendanceId: attendance.id,
        breakType: 'afternoon',
        startTime: startedAt,
      ).allowanceSeconds,
      15 * 60,
    );
  });

  testWidgets('Home break controls show progress for both departments',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final department in [Department.tech, Department.telecalling]) {
      SharedPreferences.setMockInitialValues({});
      final repository = MockHRRepository();
      final now = DateTime.now();
      repository.attendanceList.value = [
        Attendance(
          id: 'att_break_ui',
          staffId: 'staff_break_ui',
          date: now.toIso8601String().substring(0, 10),
          checkInTime: '10:00 AM',
          checkInAt: now.subtract(const Duration(hours: 1)),
          breaks: [
            AttendanceBreak(
              id: 'break_ui',
              attendanceId: 'att_break_ui',
              breakType: 'morning',
              startTime: now.subtract(const Duration(minutes: 5)),
            ),
          ],
        ),
      ];
      final staff = Staff(
        id: 'staff_break_ui',
        name: 'Anshi',
        email: 'anshi@example.com',
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

      expect(find.text('Break in Progress'), findsWidgets);
      expect(find.text('Morning Break'), findsOneWidget);
      expect(find.textContaining(RegExp(r'elapsed')), findsOneWidget);
      expect(find.text('End Break'), findsOneWidget);

      await tester.tap(find.text('End Break'));
      await tester.pumpAndSettle();

      expect(find.text('Breaks'), findsOneWidget);
      expect(find.text('Morning Break'), findsOneWidget);
      expect(find.text('Lunch Break'), findsOneWidget);
      expect(find.text('Afternoon Break'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.textContaining('Available'), findsNWidgets(2));
      expect(find.text('Start Break'), findsNWidgets(2));
    }
  });

  testWidgets('Punch page omits break history for both staff departments',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final department in [Department.tech, Department.telecalling]) {
      SharedPreferences.setMockInitialValues({});
      final repository = MockHRRepository();
      final now = DateTime.now();
      repository.attendanceList.value = [
        Attendance(
          id: 'att_history_test',
          staffId: 'staff_history_test',
          date: now.toIso8601String().substring(0, 10),
          checkInTime: '10:00 AM',
          checkInAt: now.subtract(const Duration(hours: 1)),
          breaks: [
            AttendanceBreak(
              id: 'break_history_test',
              attendanceId: 'att_history_test',
              breakType: 'morning',
              startTime: now.subtract(const Duration(minutes: 30)),
              endTime: now.subtract(const Duration(minutes: 15)),
              durationSeconds: 15 * 60,
            ),
          ],
        ),
      ];
      final staff = Staff(
        id: 'staff_history_test',
        name: 'Staff Member',
        email: 'staff@example.com',
        department: department,
        role: Role.staff,
        status: Status.active,
      );
      await tester.pumpWidget(MaterialApp(
        home: StaffHubShell(
          repository: repository,
          key: ValueKey(department),
          pageIndex: 1,
          department: department,
          staff: staff,
          workMode: 'Office',
          workLocation: null,
          
          onNavigate: (_) {},
          onLogout: () {},
        ),
      ));

      expect(find.text('BREAK HISTORY'), findsNothing);
      expect(find.text('Break Details'), findsOneWidget);
      expect(find.text('Attendance History'), findsOneWidget);
    }
  });

  testWidgets('Settings opens privacy and terms for both departments',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final department in [Department.tech, Department.telecalling]) {
      final staff = Staff(
        id: 'staff_legal_test',
        name: 'Staff Member',
        email: 'staff@example.com',
        department: department,
        role: Role.staff,
        status: Status.active,
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffHubShell(
          repository: MockHRRepository(),
          key: ValueKey(department),
          pageIndex: 3,
          department: department,
          staff: staff,
          workMode: 'Office',
          workLocation: null,
          
          onNavigate: (_) {},
          onLogout: () {},
        ),
      ));

      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.textContaining('Your privacy is important to us.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();
      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.textContaining('Users are responsible for keeping their account'), findsOneWidget);
    }
  });

  testWidgets('Top bar Chat opens the shared screen for both departments',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final department in [Department.tech, Department.telecalling]) {
      var selectedPage = 0;
      final staff = Staff(
        id: 'staff_chat_test',
        name: 'Staff Member',
        email: 'staff@example.com',
        department: department,
        role: Role.staff,
        status: Status.active,
      );

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
          repository: MockHRRepository(),
            key: ValueKey(department),
            pageIndex: selectedPage,
            department: department,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            
            onNavigate: (index) =>
                updateParent(() => selectedPage = index),
            onLogout: () {},
          ),
        ),
      ));

      expect(find.byTooltip('Open chat'), findsOneWidget);
      expect(find.text(department.toUpperCase()), findsOneWidget);
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();

      expect(find.text('Message everyone...'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('All Staff'), findsNothing);
      expect(find.text('Today, 24 Sep'), findsOneWidget);

      await tester.tap(find.byTooltip('Search messages or staff'));
      await tester.pumpAndSettle();
      final searchField = find.byKey(const ValueKey('chat-search'));
      await tester.enterText(searchField, 'Apex Tower');
      await tester.pumpAndSettle();
      expect(find.text('Rahul K.'), findsOneWidget);
      expect(find.text('Anshi M.'), findsNothing);

      await tester.enterText(searchField, 'Priya');
      await tester.pumpAndSettle();
      expect(find.text('Priya S.'), findsOneWidget);
      expect(find.text('Rahul K.'), findsNothing);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('chat-message-composer'));
      await tester.enterText(composer, 'Hello from $department');
      await tester.pumpAndSettle();
        expect(tester.widget<TextField>(composer).controller!.text,
          'Hello from $department');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
        expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      expect(find.text('Hello from $department'), findsOneWidget);
    }
  });

  testWidgets('Staff department selection opens the login screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StaffHubApp());

    expect(find.text('Choose Your Department'), findsOneWidget);
    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Sign in to continue to your workspace'), findsOneWidget);
    expect(find.text('Work Email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile page includes attendance, leave, and chat quick links', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets('Profile attendance link opens the attendance page', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT PROFILE'), findsOneWidget);
  });

  testWidgets('Staff tabs and Settings notification options work', (WidgetTester tester) async {
    var selectedPage = 0;
    var selectedThemeMode = ThemeMode.light;
    addTearDown(() => staffHubThemeMode = ThemeMode.light);
    final staff = Staff(
      id: 'staff_1',
      name: 'Olivia',
      email: 'olivia@example.com',
      phoneNumber: '9999999999',
      department: Department.tech,
      role: Role.staff,
      status: 'active',
    );
    final repository = MockHRRepository();
    repository.dailyUpdatesList.value = [
      DailyUpdate(
        id: 'work-update-test',
        staffId: staff.id,
        title: 'Installations',
        updateText: 'Completed client installation',
      ),
    ];

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: selectedThemeMode,
        home: StaffHubShell(
          repository: repository,
          pageIndex: selectedPage,
          department: 'Tech',
          staff: staff,
          
          workMode: 'Office',
          workLocation: null,
          themeMode: selectedThemeMode,
          onThemeModeChanged: (mode) => setState(() {
            selectedThemeMode = mode;
            staffHubThemeMode = mode;
          }),
          onNavigate: (index) => setState(() => selectedPage = index),
          onLogout: () {},
        ),
      ),
    ));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Punch'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Profile')),
        findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('Settings')));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();

    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Message everyone...'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Chat notifications'), findsOneWidget);
    expect(find.text('Leave status notifications'), findsOneWidget);
    expect(find.text('Attendance/punch reminders'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Appearance'));
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsNothing);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(selectedThemeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Leave')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xff10151c),
    );
    expect(find.text('Leave Request'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Submit Request')).style?.color,
      Colors.white,
    );
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xff151d26)),
        findsNWidgets(2),
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>))
            .decoration
            .fillColor,
        const Color(0xff19232d),
      );
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.calendar_month).first))
            .color,
        Theme.of(tester.element(find.byType(Scaffold).first))
            .colorScheme
            .onPrimaryContainer,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medical Leave').last);
      await tester.pumpAndSettle();
      expect(find.text('View Document'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sick Leave').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, 'Medical appointment');
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      await tester.ensureVisible(find.text('Submit Request'));
      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Leave request submitted. Check Home for the update.'),
          findsOneWidget);
      expect(find.text('Medical appointment'), findsOneWidget);
      expect(find.text('Submit Request'), findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Home')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.textContaining('Completed client installation'))
            .style
            ?.color,
        const Color(0xffeef2f7),
      );
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xff19232d)),
        findsOneWidget,
      );
  });

  testWidgets('Staff home page updates leave status to Approved when HR accepts for Tech and Telecalling', (tester) async {
    for (final dept in ['Tech', 'Telecalling']) {
      final repository = MockHRRepository();
      final staff = Staff(
        id: 'staff_${dept.toLowerCase()}_1',
        name: 'Alex $dept',
        email: 'alex.$dept@example.com',
        phoneNumber: '9876543210',
        department: dept,
        role: Role.staff,
        joinDate: '2026-01-01',
      );
      repository.staffList.value = [staff];

      final leaveReq = LeaveRequest(
        id: 'leave_${dept.toLowerCase()}_1',
        staffId: staff.id,
        fromDate: '2026-10-27',
        toDate: '2026-10-27',
        reason: 'fever',
        type: 'Sick Leave',
        status: LeaveStatus.pending,
        createdAt: DateTime.now(),
      );
      repository.leaveRequests.value = [leaveReq];

      await tester.pumpWidget(
        MaterialApp(
          theme: staffHubThemeData(ThemeMode.light),
          home: StaffHubShell(
            pageIndex: 0,
            department: dept,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            repository: repository,
            onNavigate: (_) {},
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home page initially shows Leave Request Update with Pending
      expect(find.text('Leave Request Update'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Your request was submitted and is waiting for HR approval.'), findsOneWidget);

      // HR approves the leave request
      await repository.reviewLeave(leaveReq.id, true);
      await tester.pumpAndSettle();

      // Home page immediately reflects the HR Approved status!
      expect(find.text('Leave Request Update'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Your request has been approved by HR.'), findsOneWidget);
    }
  });
}
