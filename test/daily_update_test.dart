// test/daily_update_test.dart
// Tests for the Staff Daily Work Update feature

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hr_core/models.dart';
import 'package:hr_core/staff_screens.dart';
import 'mock_hr_repository.dart';

class _FailingMockHRRepository extends MockHRRepository {
  final String errorMessage;
  final bool failFetch;

  _FailingMockHRRepository({
    this.errorMessage = 'Network error',
    this.failFetch = false,
  });

  @override
  Future<void> fetchDailyUpdates() async {
    if (failFetch) throw Exception(errorMessage);
  }

  @override
  Future<DailyUpdate> submitDailyUpdate(String title, String text) async {
    throw Exception(errorMessage);
  }
}

class _SlowSubmitMockHRRepository extends MockHRRepository {
  final Completer<void> completer;
  bool submitCalled = false;

  _SlowSubmitMockHRRepository({required this.completer});

  @override
  Future<DailyUpdate> submitDailyUpdate(String title, String text) async {
    submitCalled = true;
    await completer.future;
    final update = DailyUpdate(
      id: 'slow_upd',
      staffId: 'staff_test',
      title: title,
      updateText: text,
      date: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now(),
    );
    dailyUpdatesList.value = [update, ...dailyUpdatesList.value];
    return update;
  }
}

Widget _buildShell(MockHRRepository repo, {int pageIndex = 0}) {
  return MaterialApp(
    home: StaffHubShell(
      repository: repo,
      pageIndex: pageIndex,
      department: 'Tech',
      staff: const Staff(
        id: 'staff_test',
        name: 'Test Staff',
        email: 'test@example.com',
        department: 'Tech',
        role: Role.staff,
        status: Status.active,
      ),
      workMode: 'Office',
      workLocation: null,
      onNavigate: (_) {},
      onLogout: () {},
    ),
  );
}

void main() {
  group('DailyUpdate.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        '_id': 'abc123',
        'employee': 'emp456',
        'title': 'Sprint Review',
        'updateText': 'Completed all tasks.',
        'createdAt': '2026-10-23T10:30:00.000Z',
      };
      final update = DailyUpdate.fromJson(json);

      expect(update.id, 'abc123');
      expect(update.staffId, 'emp456');
      expect(update.title, 'Sprint Review');
      expect(update.updateText, 'Completed all tasks.');
      expect(update.date, '2026-10-23');
      expect(update.createdAt, isNotNull);
    });

    test('handles missing optional fields gracefully', () {
      final json = {'_id': 'id1', 'title': '', 'updateText': ''};
      final update = DailyUpdate.fromJson(json);
      expect(update.id, 'id1');
      expect(update.title, '');
      expect(update.updateText, '');
      expect(update.createdAt, isNull);
    });

    test('falls back to id field when _id is absent', () {
      final json = {'id': 'fallback_id', 'title': 'Test', 'updateText': 'body'};
      final update = DailyUpdate.fromJson(json);
      expect(update.id, 'fallback_id');
    });
  });

  group('MockHRRepository.submitDailyUpdate', () {
    test('successful submission adds update to list', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockHRRepository();
      expect(repo.dailyUpdatesList.value, isEmpty);

      final update =
          await repo.submitDailyUpdate('My Title', 'My update details.');

      expect(update.title, 'My Title');
      expect(update.updateText, 'My update details.');
      expect(repo.dailyUpdatesList.value, hasLength(1));
      expect(repo.dailyUpdatesList.value.first.title, 'My Title');
    });

    test('empty title throws validation error', () {
      final repo = MockHRRepository();
      expect(
        () => repo.submitDailyUpdate('', 'Some details'),
        throwsA(predicate<Exception>((e) => e.toString().contains('title'))),
      );
    });

    test('empty text throws validation error', () {
      final repo = MockHRRepository();
      expect(
        () => repo.submitDailyUpdate('A Title', ''),
        throwsA(predicate<Exception>((e) => e.toString().contains('details'))),
      );
    });

    test('multiple submissions accumulate in order (most recent first)',
        () async {
      final repo = MockHRRepository();
      await repo.submitDailyUpdate('First', 'First details');
      await repo.submitDailyUpdate('Second', 'Second details');

      expect(repo.dailyUpdatesList.value, hasLength(2));
      expect(repo.dailyUpdatesList.value.first.title, 'Second');
    });
  });

  group('MockHRRepository.fetchDailyUpdates', () {
    test('no-op does not throw and leaves list unchanged', () async {
      final repo = MockHRRepository();
      repo.dailyUpdatesList.value = [
        const DailyUpdate(id: 'u1', staffId: 's1', title: 'T', updateText: 'D'),
      ];
      await repo.fetchDailyUpdates();
      expect(repo.dailyUpdatesList.value, hasLength(1));
    });

    test('empty list is handled without error', () async {
      final repo = MockHRRepository();
      await repo.fetchDailyUpdates();
      expect(repo.dailyUpdatesList.value, isEmpty);
    });
  });

  group('_HomePageState - daily update display', () {
    testWidgets('shows empty state text when no updates exist',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockHRRepository();

      await tester.pumpWidget(_buildShell(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('No update submitted yet'), findsOneWidget);
      expect(find.text('Add Update  ›'), findsOneWidget);
    });

    testWidgets('shows update title and body when updates exist',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockHRRepository();
      repo.dailyUpdatesList.value = [
        DailyUpdate(
          id: 'u1',
          staffId: 'staff_test',
          title: 'Daily Sprint Update',
          updateText: 'Fixed critical bug in payment module.',
          date: DateTime.now().toIso8601String().substring(0, 10),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_buildShell(repo));
      await tester.pump();

      expect(find.text('Daily Sprint Update'), findsOneWidget);
      expect(
          find.text('Fixed critical bug in payment module.'), findsOneWidget);
      expect(find.text('✓ Synced'), findsOneWidget);
    });

    testWidgets('shows error banner and Retry on fetch failure',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _FailingMockHRRepository(
        errorMessage: 'Connection refused',
        failFetch: true,
      );

      await tester.pumpWidget(_buildShell(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('_EditWorkUpdatePage - submission', () {
    Future<void> openEditPage(
        WidgetTester tester, MockHRRepository repo) async {
      await tester.pumpWidget(_buildShell(repo));
      await tester.pump();
      final editBtn = find.textContaining('Update  ');
      expect(editBtn, findsWidgets);
      await tester.ensureVisible(editBtn.first);
      await tester.tap(editBtn.first);
      await tester.pumpAndSettle();
    }

    testWidgets('Save Update submits and closes on success',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockHRRepository();

      await openEditPage(tester, repo);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter update title'), 'Sprint Day 5');
      await tester.enterText(
          find.widgetWithText(TextField, "Enter today's work update"),
          'Completed refactoring of auth module.');

      await tester.tap(find.text('Save Update'));
      await tester.pumpAndSettle();

      expect(repo.dailyUpdatesList.value, isNotEmpty);
      expect(repo.dailyUpdatesList.value.first.title, 'Sprint Day 5');
      expect(find.text('Edit Work Update'), findsNothing);
    });

    testWidgets('Save Update shows error and keeps form open on API failure',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _FailingMockHRRepository(errorMessage: 'Server error 500');

      await openEditPage(tester, repo);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter update title'), 'My Update');
      await tester.enterText(
          find.widgetWithText(TextField, "Enter today's work update"),
          'Some details here.');

      await tester.tap(find.text('Save Update'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Work Update'), findsOneWidget);
      expect(find.textContaining('Server error 500'), findsOneWidget);
      expect(repo.dailyUpdatesList.value, isEmpty);
    });

    testWidgets('shows loading spinner and disables button while saving',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final completer = Completer<void>();
      final repo = _SlowSubmitMockHRRepository(completer: completer);

      await openEditPage(tester, repo);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter update title'), 'Loading test');
      await tester.enterText(
          find.widgetWithText(TextField, "Enter today's work update"),
          'Details go here.');

      await tester.tap(find.text('Save Update'));
      await tester.pump(); // Start save – do NOT settle yet

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Edit Work Update'), findsNothing);
      expect(repo.dailyUpdatesList.value, isNotEmpty);
    });

    testWidgets('Validation: snackbar shown when title is empty',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockHRRepository();

      await openEditPage(tester, repo);

      await tester.enterText(
          find.widgetWithText(TextField, "Enter today's work update"),
          'Some details.');

      await tester.tap(find.text('Save Update'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a title'), findsOneWidget);
      expect(find.text('Edit Work Update'), findsOneWidget);
    });

    testWidgets('Persisted update visible after re-opening the screen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockHRRepository();

      await repo.submitDailyUpdate('Persistent Title', 'Persistent body.');
      expect(repo.dailyUpdatesList.value, hasLength(1));

      await tester.pumpWidget(_buildShell(repo));
      await tester.pump();

      expect(find.text('Persistent Title'), findsOneWidget);
      expect(find.text('Persistent body.'), findsOneWidget);
      expect(find.text('✓ Synced'), findsOneWidget);
    });

    testWidgets('Authentication error is surfaced via snackbar',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _FailingMockHRRepository(
          errorMessage: 'Access denied. No authorization token provided.');

      await openEditPage(tester, repo);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter update title'), 'Title');
      await tester.enterText(
          find.widgetWithText(TextField, "Enter today's work update"),
          'Details.');

      await tester.tap(find.text('Save Update'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Access denied'), findsOneWidget);
    });
  });
}
