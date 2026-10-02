import 'package:flutter/material.dart';
import 'hr_repository.dart';
import 'login_screen.dart';
import 'models.dart';
import 'staff_department_screen.dart';
import 'staff_screens.dart';

void main() => runApp(const StaffHubApp());

class StaffHubApp extends StatefulWidget {
  const StaffHubApp({super.key});

  @override
  State<StaffHubApp> createState() => _StaffHubAppState();
}

class _StaffHubAppState extends State<StaffHubApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StaffHub',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: staffHubThemeData(ThemeMode.light),
        home: _AppPages(
          themeMode: _themeMode,
          onThemeModeChanged: (themeMode) => setState(() {
            _themeMode = themeMode;
            staffHubThemeMode = themeMode;
          }),
        ),
      );
}

class _AppPages extends StatefulWidget {
  const _AppPages({required this.themeMode, required this.onThemeModeChanged});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_AppPages> createState() => _AppPagesState();
}

class _AppPagesState extends State<_AppPages> {
  bool _loggedIn = false;
  bool _departmentSelected = false;
  String? _selectedDepartment;
  int _page = 0;
  final HRRepositoryImpl _repository = HRRepositoryImpl();
  Staff? _staff;
  String _workMode = 'Office';
  String? _workLocation;

  @override
  Widget build(BuildContext context) {
    if (!_departmentSelected) {
      return StaffDepartmentScreen(
        onSelect: (department) => setState(() {
          _selectedDepartment = department;
          _departmentSelected = true;
        }),
      );
    }
    if (!_loggedIn) {
      return StaffLoginPage(
        selectedDepartment: _selectedDepartment!,
        onSignIn: (email, password, workMode, location) async {
          final staff = await _repository.signIn(email, password);
          if (staff.role != Role.staff) {
            _repository.signOut();
            throw Exception('Please sign in through the HR portal.');
          }
          await _repository.recordStaffSignIn(StaffSignInRecord(
            staffId: staff.id,
            department: _selectedDepartment!,
            workMode: workMode,
            timestamp: DateTime.now(),
            latitude: workMode == 'Work From Home' ? location?.latitude : null,
            longitude:
                workMode == 'Work From Home' ? location?.longitude : null,
            locationAddress:
                workMode == 'Work From Home' ? location?.address : null,
          ));
          setState(() {
            _staff = staff;
            _workMode = workMode;
            _workLocation =
                workMode == 'Work From Home' ? location?.address : null;
            _loggedIn = true;
          });
        },
      );
    }
    final onLogout = () => setState(() {
          _loggedIn = false;
          _repository.signOut();
          _staff = null;
          _workMode = 'Office';
          _workLocation = null;
          _departmentSelected = false;
          _selectedDepartment = null;
          _page = 0;
        });
    return StaffHubShell(
      pageIndex: _page,
      department: _selectedDepartment!,
      staff: _staff!,
      workMode: _workMode,
      workLocation: _workLocation,
      repository: _repository,
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      onNavigate: (index) => setState(() => _page = index),
      onLogout: onLogout,
    );
  }
}
