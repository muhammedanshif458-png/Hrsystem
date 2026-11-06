import 'package:flutter/material.dart';
import 'hr_repository.dart';
import 'login_screen.dart';
import 'models.dart';
import 'staff_department_screen.dart';
import 'staff_screens.dart';
import 'storage/token_storage.dart';

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
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      if (await TokenStorage.hasToken()) {
        final staff = await _repository.fetchProfile();
        final mode = await TokenStorage.getWorkMode();
        if (staff.id.isNotEmpty && mounted) {
          setState(() {
            _staff = staff;
            _selectedDepartment = staff.department;
            _departmentSelected = true;
            _workMode = mode == 'WORK_FROM_HOME' ? 'Work From Home' : 'Office';
            _loggedIn = true;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_departmentSelected) {
      return StaffDepartmentScreen(
        selectedDepartment: _selectedDepartment,
        onSelect: (department) => setState(() {
          _selectedDepartment = department;
          _departmentSelected = true;
        }),
      );
    }
    if (!_loggedIn) {
      return StaffLoginPage(
        selectedDepartment: _selectedDepartment!,
        onBack: () => setState(() {
          _departmentSelected = false;
        }),
        onSignIn: (email, password, workMode) async {
          final staff = await _repository.signIn(email, password,
              workMode: workMode);
          final savedWorkMode = await TokenStorage.getWorkMode();
          final displayWorkMode =
              savedWorkMode == 'WORK_FROM_HOME' ? 'Work From Home' : 'Office';
          if (staff.role != Role.staff) {
            _repository.signOut();
            throw Exception('Not a staff account.');
          }
          await _repository.recordStaffSignIn(StaffSignInRecord(
            staffId: staff.id,
            department: _selectedDepartment!,
            workMode: displayWorkMode,
            timestamp: DateTime.now(),
          ));
          final effectiveDept = (staff.department.isNotEmpty &&
                  staff.department != Department.all)
              ? staff.department
              : _selectedDepartment!;
          setState(() {
            _staff = staff;
            _selectedDepartment = effectiveDept;
            _workMode = displayWorkMode;
            _workLocation = null;
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
