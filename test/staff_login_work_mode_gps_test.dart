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
    this.openLocationSettingsResult = true,
    this.position,
    this.positionError,
  });

  bool serviceEnabled;
  LocationPermission initialPermission;
  LocationPermission requestPermissionResult;
  bool openAppSettingsResult;
  bool openAppSettingsThrows;
  bool openLocationSettingsResult;
  Position? position;
  Object? positionError;

  int isServiceEnabledCalls = 0;
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int getCurrentPositionCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

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

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return openLocationSettingsResult;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StaffHub Login GPS Validation by Work Mode', () {
    // Scenario 1: WFH + first-time permission grant -> automatically capture GPS and login
    testWidgets('1. WFH + first-time permission grant -> automatically captures GPS and continues login',
        (WidgetTester tester) async {
      final fixedUtcTime = DateTime.utc(2026, 11, 5, 8, 15, 30);
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.denied, // First time: denied
        requestPermissionResult: LocationPermission.whileInUse, // User grants on prompt
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

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'wfh@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'SecretWfhPass1');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Automatically requested permission and captured GPS
      expect(fakeGps.checkPermissionCalls, 1);
      expect(fakeGps.requestPermissionCalls, 1);
      expect(fakeGps.getCurrentPositionCalls, 1);

      // Automatically continued login with captured location
      expect(capturedWorkMode, 'WORK_FROM_HOME');
      expect(capturedLocation, isNotNull);
      expect(capturedLocation!.latitude, 28.6139);
      expect(capturedLocation!.longitude, 77.2090);
      expect(capturedLocation!.accuracy, 8.5);
      expect(capturedLocation!.capturedAt.toIso8601String(), '2026-11-05T08:15:30.000Z');
      expect(find.text('✓ Location captured'), findsOneWidget);
    });

    // Scenario 2: WFH + permission already granted -> capture GPS without another permission dialog
    testWidgets('2. WFH + permission already granted -> captures GPS without another permission dialog',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.whileInUse, // Already granted
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

      expect(fakeGps.checkPermissionCalls, 1);
      // Did NOT show another permission dialog
      expect(fakeGps.requestPermissionCalls, 0);
      expect(fakeGps.getCurrentPositionCalls, 1);

      expect(capturedWorkMode, 'WORK_FROM_HOME');
      expect(capturedLocation, isNotNull);
    });

    // Scenario 3: WFH + permission temporarily denied -> request permission
    testWidgets('3. WFH + permission temporarily denied -> requests permission and blocks login if user denies',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied, // User denies prompt
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

      expect(fakeGps.requestPermissionCalls, 1);
      expect(fakeGps.getCurrentPositionCalls, 0);
      expect(loginCalled, isFalse);
      expect(find.textContaining('Location permission was denied'), findsWidgets);
    });

    // Scenario 4: WFH + permanently denied -> open app settings and retry after granting permission
    testWidgets('4. WFH + permanently denied -> opens settings and automatically captures GPS on retry',
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

      // Attempt 1: Permanently denied
      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      final settingsBtnFinder = find.byKey(const ValueKey('open-app-settings-button'));
      expect(settingsBtnFinder, findsOneWidget);
      expect(find.textContaining('Location permission is blocked'), findsWidgets);
      expect(loggedInWorkMode, isNull);

      // Simulate granting permission in settings
      fakeGps.initialPermission = LocationPermission.whileInUse;

      // User taps "Open app settings"
      await tester.tap(settingsBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeGps.openAppSettingsCalls, 1);
      expect(find.text('Open app settings'), findsNothing);

      // User retries Sign In -> fresh location captured and login succeeds
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(loggedInWorkMode, 'WORK_FROM_HOME');
      expect(loggedInLocation, isNotNull);
      expect(loggedInLocation!.latitude, 19.0760);
      expect(loggedInLocation!.longitude, 72.8777);
    });

    // Scenario 5: WFH + GPS disabled -> guide user to enable GPS and retry
    testWidgets('5. WFH + GPS disabled -> guides user to enable GPS with action button',
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

      // Action button to enable location services exists and functions
      final enableGpsBtn = find.byKey(const ValueKey('enable-location-services-button'));
      expect(enableGpsBtn, findsOneWidget);
      await tester.tap(enableGpsBtn);
      await tester.pumpAndSettle();

      expect(fakeGps.openLocationSettingsCalls, 1);
    });

    // Scenario 6: WFH + timeout -> show retry guidance
    testWidgets('6. WFH + timeout -> shows retry guidance and blocks login',
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

    // Scenario 7: OFFICE + permission denied -> login succeeds without GPS
    testWidgets('7. OFFICE + permission denied -> login succeeds without GPS',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied,
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

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your email'), 'office@company.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your password'), 'Pass@1234');

      final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(capturedWorkMode, 'OFFICE');
      expect(capturedLocation, isNull);
      expect(fakeGps.checkPermissionCalls, 0);
      expect(fakeGps.requestPermissionCalls, 0);
      expect(fakeGps.getCurrentPositionCalls, 0);
    });

    // Scenario 8: OFFICE + GPS disabled -> login succeeds without GPS
    testWidgets('8. OFFICE + GPS disabled -> login succeeds without GPS',
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
      expect(fakeGps.isServiceEnabledCalls, 0);
      expect(fakeGps.getCurrentPositionCalls, 0);
    });

    testWidgets('9. WORK_FROM_HOME + placeholder coordinates (0,0) -> login blocked',
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

    testWidgets('10. Open App Settings handles failure/false safely without crashing',
        (WidgetTester tester) async {
      final fakeGps = FakeLoginLocationProvider(
        serviceEnabled: true,
        initialPermission: LocationPermission.deniedForever,
        openAppSettingsResult: false,
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
      expect(find.textContaining('Could not open settings automatically'), findsOneWidget);
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

      fakeGps.initialPermission = LocationPermission.whileInUse;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

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

      const provider = DefaultLoginLocationProvider();
      final result = await provider.openAppSettings();

      expect(channelCalled, isTrue);
      expect(result, isTrue);
    });
  });
}
