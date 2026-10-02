// ─── hr_view_model.dart ────────────────────────────────────────────────────────
// Converted from Kotlin HRViewModel (ViewModel + StateFlow) to
// Flutter ChangeNotifier + ValueNotifier pattern.

import 'package:flutter/foundation.dart';
import 'models.dart';
import 'hr_repository.dart';
import 'date_time_utils.dart';

// ─── Screen sealed class (Kotlin sealed interface → Dart sealed class) ─────────

sealed class Screen {}

class LoginScreen extends Screen {}

class StaffPortalScreen extends Screen {}

class HRDashboardScreen extends Screen {}

class DepartmentScreen extends Screen {
  DepartmentScreen(this.department);
  final String department;
}

class DashboardMetricScreen extends Screen {
  DashboardMetricScreen(this.filter);
  final String filter;
}

class StaffProfileScreen extends Screen {
  StaffProfileScreen(this.staffId);
  final String staffId;
}

// ─── Dashboard Metrics ────────────────────────────────────────────────────────

class DashboardMetrics {
  const DashboardMetrics({
    this.presentToday = 0,
    this.lateCheckIns = 0,
    this.openTasks = 0,
    this.onLeaveToday = 0,
    this.resignedLast30Days = 0,
  });

  final int presentToday;
  final int lateCheckIns;
  final int openTasks;
  final int onLeaveToday;
  final int resignedLast30Days;
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

class HRViewModel extends ChangeNotifier {
  HRViewModel(this._repository) {
    _repository.staffList.addListener(_onDataChanged);
    _repository.attendanceList.addListener(_onDataChanged);
    _repository.tasksList.addListener(_onDataChanged);
    _repository.dailyUpdatesList.addListener(_onDataChanged);
    _repository.leaveRequests.addListener(_onDataChanged);
    _repository.resignationRequests.addListener(_onDataChanged);
    _onDataChanged();
  }

  final HRRepository _repository;
  HRRepository get repository => _repository;

  // ── Navigation ──────────────────────────────────────────────────────────────

  Screen _currentScreen = LoginScreen();
  Screen get currentScreen => _currentScreen;

  void navigateTo(Screen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void openDepartmentScreen(String department) {
    _departmentFilter = department;
    _dashboardFilter = 'all';
    _recomputeDashboard();
    _recomputeFilteredStaff();
    _currentScreen = DepartmentScreen(department);
    notifyListeners();
  }

  // ── Search & Filter ─────────────────────────────────────────────────────────

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _departmentFilter = Department.all;
  String get departmentFilter => _departmentFilter;

  String _dashboardFilter = 'all';
  String get dashboardFilter => _dashboardFilter;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDepartmentFilter(String department) {
    _departmentFilter = department;
    _dashboardFilter = 'all';
    _recomputeDashboard();
    _recomputeFilteredStaff();
    notifyListeners();
  }

  void setDashboardFilter(String filter) {
    _dashboardFilter = filter;
    _recomputeFilteredStaff();
    notifyListeners();
  }

  // ── Toast / Snackbar ────────────────────────────────────────────────────────

  String? _toastMessage;
  String? get toastMessage => _toastMessage;

  void showToast(String message) {
    _toastMessage = message;
    notifyListeners();
  }

  void clearToast() {
    _toastMessage = null;
    notifyListeners();
  }

  // ── Modal visibility ────────────────────────────────────────────────────────

  bool isAddStaffModalOpen = false;
  bool isAssignTaskModalOpen = false;
  bool isEditStaffModalOpen = false;
  bool isForgotPasswordOpen = false;
  bool isFirestoreRulesOpen = false;
  String? assignTaskPreselectedStaffId;

  void openAddStaffModal() {
    isAddStaffModalOpen = true;
    notifyListeners();
  }

  void closeAddStaffModal() {
    isAddStaffModalOpen = false;
    notifyListeners();
  }

  void openAssignTaskModal([String? staffId]) {
    assignTaskPreselectedStaffId = staffId;
    isAssignTaskModalOpen = true;
    notifyListeners();
  }

  void closeAssignTaskModal() {
    assignTaskPreselectedStaffId = null;
    isAssignTaskModalOpen = false;
    notifyListeners();
  }

  void openEditStaffModal() {
    isEditStaffModalOpen = true;
    notifyListeners();
  }

  void closeEditStaffModal() {
    isEditStaffModalOpen = false;
    notifyListeners();
  }

  void openForgotPassword() {
    isForgotPasswordOpen = true;
    notifyListeners();
  }

  void closeForgotPassword() {
    isForgotPasswordOpen = false;
    notifyListeners();
  }

  void openFirestoreRules() {
    isFirestoreRulesOpen = true;
    notifyListeners();
  }

  void closeFirestoreRules() {
    isFirestoreRulesOpen = false;
    notifyListeners();
  }

  void _setModal(void Function() fn) {
    fn();
    notifyListeners();
  }

  // ── Repository pass-throughs ────────────────────────────────────────────────

  Staff? get currentUser => _repository.currentUser.value;
  List<Staff> get staffList => _repository.staffList.value;
  List<Attendance> get attendanceList => _repository.attendanceList.value;
  List<TaskItem> get tasksList => _repository.tasksList.value;
  List<DailyUpdate> get dailyUpdatesList => _repository.dailyUpdatesList.value;
  List<LeaveRequest> get leaveRequests => _repository.leaveRequests.value;
  List<ResignationRequest> get resignationRequests =>
      _repository.resignationRequests.value;
  bool get isFirebaseConnected => _repository.isFirebaseConnected.value;

  // ── Derived / computed ──────────────────────────────────────────────────────

  DashboardMetrics _dashboardMetrics = const DashboardMetrics();
  DashboardMetrics get dashboardMetrics => _dashboardMetrics;

  List<Staff> _filteredStaffList = [];
  List<Staff> get filteredStaffList => _filteredStaffList;

  void _onDataChanged() {
    _recomputeDashboard();
    _recomputeFilteredStaff();
    notifyListeners();
  }

  void _recomputeDashboard() {
    final today = DateTimeUtils.getTodayIsoDate();
    final departmentStaff = staffList.where((staff) =>
        _departmentFilter == Department.all ||
        staff.department.toLowerCase() == _departmentFilter.toLowerCase());
    final activeIds = departmentStaff
        .where((s) => s.status == 'active')
        .map((s) => s.id)
        .toSet();
    final todayAtt = attendanceList
        .where((a) => a.date == today && activeIds.contains(a.staffId))
        .toList();

    _dashboardMetrics = DashboardMetrics(
      presentToday: todayAtt.length,
      lateCheckIns: todayAtt.where((a) => a.isLate).length,
      openTasks: tasksList
          .where((task) =>
              activeIds.contains(task.staffId) && task.status != 'done')
          .length,
      onLeaveToday: departmentStaff
          .where((s) => s.status == 'active' && s.onLeaveToday)
          .length,
      resignedLast30Days: departmentStaff
          .where(
            (s) =>
                s.status == 'resigned' &&
                DateTimeUtils.isWithinLast30Days(s.resignedDate),
          )
          .length,
    );
  }

  void _recomputeFilteredStaff() {
    _filteredStaffList = staffList.where((s) {
      final matchesDept = _departmentFilter == Department.all ||
          s.department.toLowerCase() == _departmentFilter.toLowerCase();
      final matchesQuery = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.phoneNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      final today = DateTimeUtils.getTodayIsoDate();
      final todayAttendance =
          attendanceList.where((a) => a.staffId == s.id && a.date == today);
      final hasAttendance = todayAttendance.isNotEmpty;
      final isLate = todayAttendance.any((a) => a.isLate);
      final hasOpenTask = tasksList
          .any((t) => t.staffId == s.id && t.status != TaskStatus.done);
      final matchesDashboard = switch (_dashboardFilter) {
        'active' => s.status == Status.active,
        'present' => hasAttendance,
        'leave' => s.onLeaveToday,
        'late' => isLate,
        'tasks' => hasOpenTask,
        'resigned' => s.status == Status.resigned,
        _ => true,
      };
      return matchesDept && matchesQuery && matchesDashboard;
    }).toList();
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  void login(
    String email,
    String password, {
    required void Function(String) onError,
  }) {
    _repository.signIn(email, password).then((staff) {
      if (staff.role != Role.staff) {
        _repository.signOut();
        onError('Please sign in through the HR portal.');
        return;
      }
      navigateTo(StaffPortalScreen());
    }).catchError((err) {
      onError(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void quickLogin(Staff staff) {
    _repository.switchUserDirect(staff).then((_) {
      _routeByRole(staff);
    });
  }

  void _routeByRole(Staff staff) {
    if (staff.role == Role.hrManager) {
      navigateTo(HRDashboardScreen());
    } else {
      navigateTo(StaffPortalScreen());
    }
  }

  void logout() {
    _repository.signOut();
    navigateTo(LoginScreen());
  }

  // ── Attendance ──────────────────────────────────────────────────────────────

  void checkIn() {
    final user = currentUser;
    if (user == null) return;
    _repository.checkIn(user.id).then((att) {
      showToast(
        att.isLate
            ? 'Checked in at ${att.checkInTime} (Late check-in)'
            : 'Checked in at ${att.checkInTime} (On time)',
      );
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void checkOut(String attendanceId) {
    _repository.checkOut(attendanceId).then((_) {
      showToast('Checked out successfully');
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void toggleBreak(String attendanceId) {
    _repository
        .toggleBreak(attendanceId)
        .then((_) => showToast('Break status updated'));
  }

  void applyLeave(String fromDate, String toDate, String reason) {
    final user = currentUser;
    if (user == null) return;
    _repository
        .requestLeave(
            staffId: user.id,
            fromDate: fromDate,
            toDate: toDate,
            reason: reason)
        .then((_) => showToast('Leave request sent to HR'))
        .catchError(
            (e) => showToast(e.toString().replaceFirst('Exception: ', '')));
  }

  void reviewLeave(String requestId, bool approved) {
    _repository
        .reviewLeave(requestId, approved)
        .then((_) => showToast(approved ? 'Leave approved' : 'Leave rejected'));
  }

  void deleteLeave(String requestId) {
    _repository
        .deleteLeaveRequest(requestId)
        .then((_) => showToast('Leave request deleted'));
  }

  void submitResignation(String lastWorkingDate, String reason) {
    final user = currentUser;
    if (user == null) return;
    _repository
        .requestResignation(
            staffId: user.id, lastWorkingDate: lastWorkingDate, reason: reason)
        .then((_) => showToast('Resignation request sent to HR'))
        .catchError(
            (e) => showToast(e.toString().replaceFirst('Exception: ', '')));
  }

  void reviewResignation(String requestId, bool approved) {
    _repository.reviewResignation(requestId, approved).then((_) =>
        showToast(approved ? 'Resignation approved' : 'Resignation rejected'));
  }

  // ── Daily Updates ───────────────────────────────────────────────────────────

  void submitDailyUpdate(String text, {required VoidCallback onSuccess}) {
    final user = currentUser;
    if (user == null) return;
    _repository.submitDailyUpdate(user.id, text).then((_) {
      showToast('Daily update submitted successfully');
      onSuccess();
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  // ── Tasks ───────────────────────────────────────────────────────────────────

  void updateTaskStatus(String taskId, String newStatus) {
    _repository.updateTaskStatus(taskId, newStatus).then((_) {
      showToast('Task status updated to $newStatus');
    });
  }

  // ── Staff management ────────────────────────────────────────────────────────

  void addStaff(
    String name,
    String email,
    String phoneNumber,
    String department,
    String role,
    String joinDate,
  ) {
    _repository
        .addStaff(
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      department: department,
      role: role,
      joinDate: joinDate,
    )
        .then((_) {
      _setModal(() => isAddStaffModalOpen = false);
      showToast('Staff member added successfully');
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void updateStaff(Staff staff) {
    _repository.updateStaff(staff).then((_) {
      _setModal(() => isEditStaffModalOpen = false);
      showToast('Staff details updated');
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void markStaffResigned(String staffId) {
    _repository
        .markStaffResigned(staffId, DateTimeUtils.getTodayIsoDate())
        .then((_) {
      showToast('Staff marked as resigned');
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void assignTask(
    String staffId,
    String department,
    String description,
    String dueDate,
  ) {
    _repository
        .assignTask(
      staffId: staffId,
      department: department,
      description: description,
      dueDate: dueDate,
    )
        .then((_) {
      _setModal(() {
        isAssignTaskModalOpen = false;
        assignTaskPreselectedStaffId = null;
      });
      showToast('Task assigned successfully');
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  void sendPasswordReset(String email) {
    _repository.sendPasswordReset(email).then((msg) {
      _setModal(() => isForgotPasswordOpen = false);
      showToast(msg);
    }).catchError((err) {
      showToast(err.toString().replaceFirst('Exception: ', ''));
    });
  }

  @override
  void dispose() {
    _repository.staffList.removeListener(_onDataChanged);
    _repository.attendanceList.removeListener(_onDataChanged);
    _repository.tasksList.removeListener(_onDataChanged);
    _repository.dailyUpdatesList.removeListener(_onDataChanged);
    _repository.leaveRequests.removeListener(_onDataChanged);
    _repository.resignationRequests.removeListener(_onDataChanged);
    super.dispose();
  }
}
