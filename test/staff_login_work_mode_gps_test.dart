import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hr_core/login_screen.dart';
import 'package:hr_core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLoginLocationProvider implements LoginLocationProvider {
  FakeLoginLocationProvider({
    this.serviceEnabled = true,
    this.initialPermission = LocationPermission.whileInUse,
    this.requestPermissionResult = LocationPermission.whileInUse,
    this.openAppSettingsResult = true,
    this.openAppSettingsThrows = false,
    this.position,
    this.positionError,
  });

  bool serviceEnabled;
  LocationPermission initialPermission;
  LocationPermission requestPermissionResult;
  bool openAppSettingsResult;
  bool openAppSettingsThrows;
  Position? position;
  Object? positionError;

  int isServiceEnabledCalls = 0;
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int getCurrentPositionCalls = 0;
  int openAppSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    isServiceEnabledCalls++;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCalls++;
    return initialPermission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return requestPermissionResult;
  }

  @override
  Future<Position> getCurrentPosition() async {
    getCurrentPositionCalls++;
    if (positionError != null) {
      throw positionError!;
    }
    return position ??
        Position(
          latitude: 12.9716,
          longitude: 77.5946,
          timestamp: DateTime.utc(2026, 11, 5, 10, 30),
          accuracy: 12.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    if (openAppSettingsThrows) {
      throw PlatformException(code: 'FAILED', message: 'Could not open settings');
    }
    return openAppSettingsResult;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub Login GPS Validation by Work Mode', () {
    testWidgets('1. OFFICE + GPS permission denied -> login succeeds without GPS',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied,
      );

      String? capturedEmail;
      String? capturedPassword;
      String? capturedWorkMode;
      LocationCapture? capturedLocation;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            capturedEmail = email;
            capturedPassword = password;
            capturedWorkMode = workMode;
            capturedLocation = location;
          },
        ),
      ));

      // Defaults to Office
      expect(find.text('Office'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'staff@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@1234');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Login succeeds with OFFICE and null location
      expect(capturedEmail, 'staff@company.com');
      expect(capturedPassword, 'Pass@1234');
      expect(capturedWorkMode, 'OFFICE');
      expect(capturedLocation, isNull);

      // GPS provider was never invoked for Office mode
      expect(fakeGps.isServiceEnabledCalls, 0);
      expect(fakeGps.checkPermissionCalls, 0);
      expect(fakeGps.requestPermissionCalls, 0);
      expect(fakeGps.getCurrentPositionCalls, 0);
    });

    testWidgets('2. OFFICE + GPS disabled -> login succeeds without GPS',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: false,
      );

      String? capturedWorkMode;
      LocationCapture? capturedLocation;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Telecalling',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            capturedWorkMode = workMode;
            capturedLocation = location;
          },
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'tele@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'TelePass@1');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(capturedWorkMode, 'OFFICE');
      expect(capturedLocation, isNull);

      // Never checked GPS status
      expect(fakeGps.isServiceEnabledCalls, 0);
      expect(fakeGps.getCurrentPositionCalls, 0);
    });

    testWidgets('3. WORK_FROM_HOME + permission granted -> login with GPS and UTC ISO timestamp',
        (WidgetTester tester) async {
      final fixedUtcTime = DateTime.utc(2026, 11, 5, 8, 15, 30);
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.whileInUse,
        position: Position(
          latitude: 28.6139,
          longitude: 77.2090,
          timestamp: fixedUtcTime,
          accuracy: 8.5,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      String? capturedWorkMode;
      LocationCapture? capturedLocation;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            capturedWorkMode = workMode;
            capturedLocation = location;
          },
        ),
      ));

      // Switch to Work From Home
      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      // Tapping mode switch must NOT trigger GPS detection immediately
      expect(fakeGps.getCurrentPositionCalls, 0);
      expect(fakeGps.checkPermissionCalls, 0);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'SecretWfhPass1');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // GPS captured upon Sign In
      expect(fakeGps.isServiceEnabledCalls, 1);
      expect(fakeGps.checkPermissionCalls, 1);
      expect(fakeGps.getCurrentPositionCalls, 1);

      expect(capturedWorkMode, 'WORK_FROM_HOME');
      expect(capturedLocation, isNotNull);
      expect(capturedLocation!.latitude, 28.6139);
      expect(capturedLocation!.longitude, 77.2090);
      expect(capturedLocation!.accuracy, 8.5);
      expect(capturedLocation!.capturedAt.isUtc, isTrue);
      expect(capturedLocation!.capturedAt.toIso8601String(), '2026-11-05T08:15:30.000Z');
    });

    testWidgets('4. WORK_FROM_HOME + permission denied -> login blocked with retry guidance',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied,
      );

      var loginCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            loginCalled = true;
          },
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Login is blocked
      expect(loginCalled, isFalse);

      // Retry guidance displayed
      expect(find.textContaining('Location permission was denied'), findsWidgets);
    });

    testWidgets('5. WORK_FROM_HOME + GPS disabled -> login blocked with retry guidance',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: false,
      );

      var loginCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            loginCalled = true;
          },
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(loginCalled, isFalse);
      expect(find.textContaining('Location services are turned off. Enable GPS and retry.'), findsWidgets);
    });

    testWidgets('6. WORK_FROM_HOME + location detection timeout -> login blocked',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        positionError: TimeoutException('GPS timed out'),
      );

      var loginCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            loginCalled = true;
          },
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(loginCalled, isFalse);
      expect(find.textContaining('Location detection timed out'), findsWidgets);
    });

    testWidgets('7. WORK_FROM_HOME + placeholder coordinates (0,0) -> login blocked',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        position: Position(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now().toUtc(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      var loginCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            loginCalled = true;
          },
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(loginCalled, isFalse);
      expect(find.textContaining('placeholder coordinates'), findsWidgets);
    });

    testWidgets('8. WORK_FROM_HOME + permission permanently denied -> shows open settings button and invokes callback',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.deniedForever,
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      final settingsBtnFinder = find.byKey(const ValueKey('open-app-settings-button'));
      expect(settingsBtnFinder, findsOneWidget);
      await tester.tap(settingsBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGps.openAppSettingsCalls, 1);
    });

    testWidgets('9. Open App Settings handles failure/false safely without crashing',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.deniedForever,
        openAppSettingsResult: false, // returns false
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      final settingsBtnFinder = find.byKey(const ValueKey('open-app-settings-button'));
      expect(settingsBtnFinder, findsOneWidget);
      await tester.tap(settingsBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGps.openAppSettingsCalls, 1);
      // Fallback message shown in SnackBar
      expect(find.textContaining('Could not open settings automatically'), findsOneWidget);
    });

    testWidgets('10. After returning from Settings: permission granted clears permanent-denial and retry sign-in succeeds',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.deniedForever,
        position: Position(
          latitude: 19.0760,
          longitude: 72.8777,
          timestamp: DateTime.utc(2026, 11, 5, 11, 0),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      String? loggedInWorkMode;
      LocationCapture? loggedInLocation;

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {
            loggedInWorkMode = workMode;
            loggedInLocation = location;
          },
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      // Attempt 1: Permanently denied -> blocked
      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Open app settings'), findsOneWidget);
      expect(find.textContaining('Location permission is blocked'), findsWidgets);
      expect(loggedInWorkMode, isNull);

      // User simulates granting permission in Settings
      fakeGps.initialPermission = LocationPermission.whileInUse;

      // User taps "Open app settings" button
      await tester.tap(find.byKey(const ValueKey('open-app-settings-button')));
      await tester.pumpAndSettle();

      // Permanent denial error and open settings button must be gone!
      expect(find.text('Open app settings'), findsNothing);
      expect(find.textContaining('Location permission is blocked'), findsNothing);

      // Now user taps Sign In -> fresh location captured and login succeeds
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(loggedInWorkMode, 'WORK_FROM_HOME');
      expect(loggedInLocation, isNotNull);
      expect(loggedInLocation!.latitude, 19.0760);
      expect(loggedInLocation!.longitude, 72.8777);
    });

    testWidgets('11. Returning via app lifecycle resume re-checks permission and removes permanent denial',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.deniedForever,
      );

      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          locationProvider: fakeGps,
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      await tester.tap(find.text('Work From Home'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@123');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Open app settings'), findsOneWidget);

      // User changes permission in Android Settings and returns to app (triggering lifecycle resume)
      fakeGps.initialPermission = LocationPermission.whileInUse;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Re-checked on resume: open settings button and error cleared
      expect(find.text('Open app settings'), findsNothing);
      expect(find.textContaining('Location permission is blocked'), findsNothing);
    });

    testWidgets('12. UI: GPS explanation clarifies location is required only for Work From Home',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffLoginPage(
          selectedDepartment: 'Tech',
          onSignIn: (email, password, workMode, location) async {},
        ),
      ));

      expect(
        find.text(
          'GPS location is collected during sign in for attendance and work-location records (required only for Work From Home).',
        ),
        findsOneWidget,
      );
    });
  });

  group('DefaultLoginLocationProvider platform fallback', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('openAppSettings falls back to platform settings channel if Geolocator throws',
        () async {
      var channelCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.hr_core/app_settings'),
        (MethodCall call) async {
          if (call.method == 'openAppSettings') {
            channelCalled = true;
            return true;
          }
          if (call.method == 'getApplicationId') {
            return 'com.example.hr_core';
          }
          return null;
        },
      );

      // In unit test without real Geolocator plugin, openAppSettings throws or fails
      // and invokes our custom Android platform channel fallback
      const provider = DefaultLoginLocationProvider();
      final result = await provider.openAppSettings();

      expect(channelCalled, isTrue);
      expect(result, isTrue);
    });
  });
}
