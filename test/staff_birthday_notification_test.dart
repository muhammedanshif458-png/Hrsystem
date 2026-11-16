import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_hr_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('birthday card slides and fades into view once', (tester) async {
    final repository = _BirthdayRepository([_employee('Asha Mehta')]);
    await tester.pumpWidget(_dashboard(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Birthday Celebration'), findsNothing);
    expect(
        find.textContaining('🎉 Happy Birthday, Asha Mehta!'), findsOneWidget);
    expect(find.text('AM'), findsNothing);
    expect(find.byType(ClipOval), findsNothing);
    expect(find.byTooltip('Dismiss birthday notifications'), findsOneWidget);
    expect(
        tester
            .widgetList<SlideTransition>(find.byType(SlideTransition))
            .any((transition) => transition.position.value.dy < 0),
        isTrue);
    expect(
        tester
            .widgetList<FadeTransition>(find.byType(FadeTransition))
            .any((transition) => transition.opacity.value < 1),
        isTrue);

    await tester.pumpAndSettle();
    final completedSlides =
        tester.widgetList<SlideTransition>(find.byType(SlideTransition));
    expect(completedSlides.first.position.value, Offset.zero);

    await tester.pumpWidget(_dashboard(repository));
    await tester.pump();
    final rebuiltSlides =
        tester.widgetList<SlideTransition>(find.byType(SlideTransition));
    expect(rebuiltSlides.first.position.value, Offset.zero);
  });

  testWidgets('dismiss closes smoothly and removes the birthday card',
      (tester) async {
    final repository = _BirthdayRepository([_employee('Asha Mehta')]);
    await tester.pumpWidget(_dashboard(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss birthday notifications'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Happy Birthday, Asha Mehta!'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Birthday Celebration'), findsNothing);
    expect(find.textContaining('Happy Birthday, Asha Mehta!'), findsNothing);
  });

  testWidgets('shows every birthday compactly when multiple employees match',
      (tester) async {
    final repository = _BirthdayRepository([
      _employee('Asha Mehta'),
      _employee('Ben Kumar'),
    ]);
    await tester.pumpWidget(_dashboard(repository));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('🎉 Happy Birthday, Asha Mehta!'), findsOneWidget);
    expect(
        find.textContaining('🎉 Happy Birthday, Ben Kumar!'), findsOneWidget);
    expect(find.text('Birthday Celebration'), findsNothing);
    expect(find.text('AM'), findsNothing);
    expect(find.text('BK'), findsNothing);
    expect(find.byType(ClipOval), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard remains scrollable and navigation works during entry',
      (tester) async {
    final repository = _BirthdayRepository([_employee('Asha Mehta')]);
    await tester.pumpWidget(_dashboard(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Punch').last);
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Punch')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

BirthdayEmployee _employee(String name) =>
    BirthdayEmployee(name: name, profileImageUrl: null);

Widget _dashboard(_BirthdayRepository repository) =>
    _DashboardHarness(repository: repository);

class _DashboardHarness extends StatefulWidget {
  const _DashboardHarness({required this.repository});

  final _BirthdayRepository repository;

  @override
  State<_DashboardHarness> createState() => _DashboardHarnessState();
}

class _DashboardHarnessState extends State<_DashboardHarness> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: StaffHubShell(
          repository: widget.repository,
          pageIndex: _pageIndex,
          department: Department.tech,
          staff: const Staff(
            id: 'staff-test',
            name: 'Staff Tester',
            department: Department.tech,
          ),
          workMode: 'Office',
          workLocation: null,
          onNavigate: (index) => setState(() => _pageIndex = index),
          onLogout: () {},
        ),
      );
}

class _BirthdayRepository extends MockHRRepository {
  _BirthdayRepository(this.birthdays);

  final List<BirthdayEmployee> birthdays;

  @override
  Future<List<BirthdayEmployee>> fetchTodaysBirthdays() async => birthdays;
}
