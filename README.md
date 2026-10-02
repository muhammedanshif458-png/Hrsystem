# StaffHub

StaffHub is a Flutter staff attendance and HR portal. The app includes staff sign-in, check-in/check-out, break tracking, leave requests, staff profiles, and an HR dashboard.

## Requirements

- Flutter SDK and Dart (the project lockfile currently requires Dart 3.12 or newer and Flutter 3.44 or newer).
- Android Studio and an Android emulator or USB-connected Android phone for Android development.
- For other platforms, install the corresponding Flutter toolchain.

## Run the app

From the project root, resolve dependencies and start Flutter:

```sh
flutter pub get
flutter run
```

If Flutter reports that it cannot resolve `shared_preferences`, run `flutter pub get` after opening the project at this root directory, then stop and start the app again. Hot reload alone does not install newly added packages.

Useful development commands:

```sh
flutter analyze
flutter test
```

## App flow

1. Choose a staff department.
2. Sign in using a seeded staff email and a non-empty password in the demo repository.
3. On Home, check in, start/end eligible breaks, and review worked time.
4. Use Punch to review today's attendance, break details, and attendance/break history.
5. Use Leave and Settings for the related staff features.
6. The staff entry flow accepts Staff accounts. HR manager functionality is implemented in the HR dashboard and view-model portion of the project.

The demo sign-in checks that the email exists and that the password field is non-empty. It does not authenticate against a production identity provider.

## Architecture

The Flutter application code is under `lib/`.

| File | Responsibility |
| --- | --- |
| `main.dart` | Creates the app, repository instance, and staff navigation flow. |
| `models.dart` | Staff, attendance, break, leave, task, and related data models. |
| `hr_repository.dart` | Repository interface and demo implementation; publishes updates through `ValueNotifier`s. |
| `hr_view_model.dart` | Dashboard, filtering, navigation, and repository actions for HR screens. |
| `staff_screens.dart` | Staff Home, Punch, Leave, and Settings UI. |
| `hr_dashboard_screen.dart` | HR dashboard and staff attendance overview. |
| `login_screen.dart`, `staff_department_screen.dart` | Department choice and staff login. |
| `date_time_utils.dart` | Shared date, time, and attendance formatting helpers. |

Screens should use the repository's attendance records as the source of truth. Attendance records contain their associated break records; Home and Punch derive current status and totals from those records.

## Attendance and break behavior

- Check-in creates one attendance record for the staff member and local calendar day. A second check-in that day is rejected.
- Breaks are stored on the attendance record with an ID, attendance ID, type, start time, optional end time, and duration.
- The current schedule has Morning Break, Lunch Break, and Afternoon Break. The scheduled start times are 11:30 AM, 1:30 PM, and 4:00 PM. The lunch allowance is 30 minutes; the other allowances are 15 minutes.
- Break duration is derived from timestamps, with active break time reflected in the live UI. Worked time subtracts break time from elapsed shift time.
- Starting a break requires an active check-in. Only one break can be active, and the schedule limits the day to three breaks.
- Checking out during a break closes and records that break before finalizing the shift.
- Attendance data is persisted on the device with `shared_preferences`, so attendance and break state survives app restarts on that device. Other demo repository data (such as leave requests and tasks) is held in memory.

## Data and production readiness

`HRRepositoryImpl` seeds sample staff and uses a local demo implementation. Firebase calls are not connected in the Flutter repository, even though Firebase-related Android dependencies and a Kotlin implementation are present in the repository. Local device persistence is not a shared server database: it does not sync attendance between devices or provide server-side audit controls. A production deployment should connect the repository interface to the intended backend and enforce attendance rules there.

The `.env.example` file is a template only. The Flutter app currently does not require a Gemini key to run. Never commit real API keys or credentials.

## Project layout

- `lib/` — Flutter app and business logic.
- `test/` — Flutter widget tests.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` — Flutter platform projects.
- `app/` — Android/Kotlin source and Gradle configuration retained in this repository.

## Troubleshooting and maintenance

### `shared_preferences` cannot be resolved

Run `flutter pub get` from the directory containing `pubspec.yaml`. Then stop and start the app again. Flutter hot reload does not fetch packages or rebuild the package configuration.

### Updating the break schedule

Break types, display names, and scheduled start times are centralized in `AttendanceBreakSchedule` in `lib/models.dart`. The repository validates break actions, and the staff screens display the same schedule. Break allowances are defined by the `AttendanceBreak` model. Keep these rules together so the UI and repository stay consistent.

### Attendance storage

Attendance is serialized to the device's `shared_preferences` store under the `staffhub.attendance.v1` key. Clearing app storage removes this local demo attendance data. This storage is device-local and is not a substitute for a cloud database or a durable server audit log.
