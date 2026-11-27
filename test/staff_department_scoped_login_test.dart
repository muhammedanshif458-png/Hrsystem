import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/core/api/api_exception.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/login_screen.dart';
import 'package:hr_core/services/api_service.dart';
import 'package:hr_core/staff_department_screen.dart';
import 'package:hr_core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLoginApiService extends ApiService {
  _FakeLoginApiService({
    this.responseHandler,
  });

  final Future<dynamic> Function(String endpoint, Map<String, dynamic>? body)?
      responseHandler;
  final List<Map<String, dynamic>> postRequests = [];

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    postRequests.add({
      'endpoint': endpoint,
      'body': body,
    });
    if (responseHandler != null) {
      return responseHandler!(endpoint, body);
    }
    throw const ApiException(statusCode: 400, message: 'Unhandled request');
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.clearTokens();
  });

  group('StaffHub Department-Scoped Login API Payload & Client Guard', () {
    test('1. selected department is included in login API request payload',
        () async {
      late Map<String, dynamic> capturedBody;
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          capturedBody = Map<String, dynamic>.from(body ?? {});
          return {
            'success': true,
            'data': {
              'accessToken': 'valid-tech-token',
              'workMode': 'OFFICE',
              'user': {
                '_id': 'user_tech_1',
                'role': 'STAFF',
                'isActive': true,
                'email': 'tech.user@company.com',
                'department': 'Tech',
                'employee': {
                  'employeeId': 'emp_tech_1',
                  'firstName': 'Alex',
                  'lastName': 'Tech',
                  'department': 'Tech',
                },
              },
            },
          };
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);
      final staff = await repo.signIn(
        'tech.user@company.com',
        'Password@123',
        department: 'Tech',
      );

      expect(capturedBody['department'], 'Tech');
      expect(capturedBody['email'], 'tech.user@company.com');
      expect(capturedBody['workMode'], 'OFFICE');
      expect(staff.department, 'Tech');
      expect(await TokenStorage.getToken(), 'valid-tech-token');
    });

    test(
        '2. Telecalling department is included in payload and succeeds when department matches',
        () async {
      late Map<String, dynamic> capturedBody;
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          capturedBody = Map<String, dynamic>.from(body ?? {});
          return {
            'success': true,
            'data': {
              'accessToken': 'valid-tele-token',
              'workMode': 'OFFICE',
              'user': {
                '_id': 'user_tele_1',
                'role': 'STAFF',
                'isActive': true,
                'email': 'tele.user@company.com',
                'department': 'Telecalling',
                'employee': {
                  'employeeId': 'emp_tele_1',
                  'firstName': 'Sam',
                  'lastName': 'Caller',
                  'department': 'Telecalling',
                },
              },
            },
          };
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);
      final staff = await repo.signIn(
        'tele.user@company.com',
        'Password@123',
        department: 'Telecalling',
      );

      expect(capturedBody['department'], 'Telecalling');
      expect(staff.department, 'Telecalling');
      expect(await TokenStorage.getToken(), 'valid-tele-token');
    });

    test(
        '3. Client-side guard rejects Tech account signing into Telecalling, clears session, and throws dynamic registration message',
        () async {
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          return {
            'success': true,
            'data': {
              'accessToken': 'should-not-be-stored',
              'refreshToken': 'should-not-be-stored-ref',
              'workMode': 'OFFICE',
              'user': {
                '_id': 'user_tech_99',
                'role': 'STAFF',
                'isActive': true,
                'email': 'tech.guy@company.com',
                'department': 'Tech',
                'employee': {
                  'employeeId': 'emp_tech_99',
                  'department': 'Tech',
                },
              },
            },
          };
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);

      expect(
        () => repo.signIn(
          'tech.guy@company.com',
          'Password@123',
          department: 'Telecalling',
        ),
        throwsA(
          predicate<Exception>((e) =>
              e.toString().contains(
                  'This account is registered under the Tech department. Please switch to the Tech workspace to sign in.')),
        ),
      );

      // Session / tokens must NOT be persisted
      expect(await TokenStorage.hasToken(), isFalse);
      expect(await TokenStorage.getToken(), isNull);
      expect(repo.currentUser.value, isNull);
    });

    test(
        '4. Client-side guard rejects Telecalling account signing into Tech, clears session, and throws dynamic registration message',
        () async {
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          return {
            'success': true,
            'data': {
              'accessToken': 'should-not-be-stored-tele',
              'workMode': 'OFFICE',
              'user': {
                '_id': 'user_tele_88',
                'role': 'STAFF',
                'isActive': true,
                'email': 'tele.girl@company.com',
                'department': 'Telecalling',
                'employee': {
                  'employeeId': 'emp_tele_88',
                  'department': 'Telecalling',
                },
              },
            },
          };
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);

      expect(
        () => repo.signIn(
          'tele.girl@company.com',
          'Password@123',
          department: 'Tech',
        ),
        throwsA(
          predicate<Exception>((e) =>
              e.toString().contains(
                  'This account is registered under the Telecalling department. Please switch to the Telecalling workspace to sign in.')),
        ),
      );

      // Session / tokens must NOT be persisted
      expect(await TokenStorage.hasToken(), isFalse);
      expect(await TokenStorage.getToken(), isNull);
      expect(repo.currentUser.value, isNull);
    });

    test('5. Backend 403 department rejection error message is preserved cleanly',
        () async {
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          throw const ApiException(
            statusCode: 403,
            message:
                'Access forbidden: Your account is restricted to the Tech division.',
          );
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);

      expect(
        () => repo.signIn(
          'user@company.com',
          'Password@123',
          department: 'Telecalling',
        ),
        throwsA(
          predicate<Exception>((e) => e.toString().contains(
              'Access forbidden: Your account is restricted to the Tech division.')),
        ),
      );
      expect(await TokenStorage.hasToken(), isFalse);
    });

    test(
        '6. Backend 401 department rejection error message is cleanly displayed instead of generic message',
        () async {
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          throw const ApiException(
            statusCode: 401,
            message:
                'Invalid credentials for department Telecalling: user belongs to Tech.',
          );
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);

      expect(
        () => repo.signIn(
          'user@company.com',
          'Password@123',
          department: 'Telecalling',
        ),
        throwsA(
          predicate<Exception>((e) => e.toString().contains(
              'Invalid credentials for department Telecalling: user belongs to Tech.')),
        ),
      );
      expect(await TokenStorage.hasToken(), isFalse);
    });

    test('7. Generic 401 (e.g. wrong password) displays Invalid email or password',
        () async {
      final fakeApi = _FakeLoginApiService(
        responseHandler: (endpoint, body) async {
          throw const ApiException(
            statusCode: 401,
            message: 'Unauthorized',
          );
        },
      );

      final repo = HRRepositoryImpl(api: fakeApi);

      expect(
        () => repo.signIn(
          'user@company.com',
          'WrongPassword',
          department: 'Tech',
        ),
        throwsA(
          predicate<Exception>((e) =>
              e.toString().contains('Invalid email or password.')),
        ),
      );
      expect(await TokenStorage.hasToken(), isFalse);
    });
  });

  group('StaffHub UI: Department-Scoped Error Banner on Login Screen', () {
    testWidgets(
        '8. Login screen displays inline card with Plus Jakarta Sans and NO bottom snackbar on Tech -> Telecalling mismatch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Telecalling',
          onSignIn: (email, password, workMode) async {
            throw Exception(
                'This account is registered under the Tech department. Please switch to the Tech workspace to sign in.');
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Initially no error banner
      expect(find.byKey(const ValueKey('login_error_banner')), findsNothing);

      // Enter credentials
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter email'), 'tech.user@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter password'), 'Secret123');

      // Click Login
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      // 1. Error banner is visible
      expect(find.byKey(const ValueKey('login_error_banner')), findsOneWidget);

      // 2. Bold heading "Workspace Access Restricted" is present
      expect(find.text('Workspace Access Restricted'), findsOneWidget);
      final headingWidget = tester.widget<Text>(find.text('Workspace Access Restricted'));
      expect(headingWidget.style?.fontFamily, 'Plus Jakarta Sans');
      expect(headingWidget.style?.fontWeight, FontWeight.w700);

      // 3. Dynamic message text is present
      const expectedMsg =
          'This account is registered under the Tech department. Please switch to the Tech workspace to sign in.';
      expect(find.text(expectedMsg), findsOneWidget);
      final msgWidget = tester.widget<Text>(find.text(expectedMsg));
      expect(msgWidget.style?.fontFamily, 'Plus Jakarta Sans');

      // 4. Container has borderRadius 12 and warm fill
      final containerFinder = find.byKey(const ValueKey('login_error_banner'));
      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(boxDecoration.borderRadius, BorderRadius.circular(12));
      expect(boxDecoration.color, const Color(0xfffff8f1));

      // 5. Info icon is present
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // 6. NO bottom SnackBar rendered
      expect(find.byType(SnackBar), findsNothing);

      // Remains on login screen
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets(
        '9. Login screen displays inline card on Telecalling -> Tech mismatch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode) async {
            throw Exception(
                'This account is registered under the Telecalling department. Please switch to the Telecalling workspace to sign in.');
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter email'), 'tele.user@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter password'), 'Secret123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login_error_banner')), findsOneWidget);
      expect(find.text('Workspace Access Restricted'), findsOneWidget);
      expect(
          find.text(
              'This account is registered under the Telecalling department. Please switch to the Telecalling workspace to sign in.'),
          findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        '10. Typing in email or password, or toggling work mode clears the error banner',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode) async {
            throw Exception(
                'This account is registered under the Telecalling department. Please switch to the Telecalling workspace to sign in.');
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter email'), 'tele@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter password'), 'Pass@123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login_error_banner')), findsOneWidget);

      // 1. User modifies email to try another account -> banner cleared
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter email'), 'another@company.com');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login_error_banner')), findsNothing);

      // Submit again to re-trigger error
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login_error_banner')), findsOneWidget);

      // 2. Toggling work mode pill (Remote) -> banner cleared
      await tester.tap(find.text('Remote'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login_error_banner')), findsNothing);
    });

    testWidgets(
        '11. End-to-End flow: Department screen -> Continue as Tech -> Mismatch blocked without SnackBar',
        (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? chosenDepartment;
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            if (chosenDepartment == null) {
              return StaffDepartmentScreen(
                onSelect: (dept) => setState(() => chosenDepartment = dept),
              );
            }
            return StaffLoginPage(
              selectedDepartment: chosenDepartment!,
              onBack: () => setState(() => chosenDepartment = null),
              onSignIn: (email, password, workMode) async {
                if (chosenDepartment == 'Tech' &&
                    email.contains('telecalling')) {
                  throw Exception(
                      'This account is registered under the Telecalling department. Please switch to the Telecalling workspace to sign in.');
                }
              },
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Department selection is shown
      expect(find.text('Choose Your Department'), findsOneWidget);
      expect(find.text('Continue as Tech'), findsOneWidget);
      expect(find.text('Continue as Telecalling'), findsOneWidget);

      // Click "Continue as Tech"
      await tester.tap(find.text('Continue as Tech'));
      await tester.pumpAndSettle();

      // Reached login screen with Tech department badge
      expect(find.text('Engineering & Tech (DIV-01)'), findsOneWidget);

      // Attempt to sign in with a telecalling email
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter email'), 'telecalling.agent@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter password'), 'Secret123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      // Department mismatch banner is shown
      expect(find.byKey(const ValueKey('login_error_banner')), findsOneWidget);
      expect(find.text('Workspace Access Restricted'), findsOneWidget);
      expect(
          find.text(
              'This account is registered under the Telecalling department. Please switch to the Telecalling workspace to sign in.'),
          findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // Tap back button
      await tester.tap(find.byKey(const ValueKey('login_back_button')));
      await tester.pumpAndSettle();

      // Returns cleanly to department selection screen
      expect(find.text('Choose Your Department'), findsOneWidget);
    });
  });
}
