// ─── hr_repository.dart ───────────────────────────────────────────────────────
// Converted from Kotlin HRRepository interface + HRRepositoryImpl
// Uses ValueNotifier<T> in place of Kotlin StateFlow<T>.
// Firebase calls are stubbed (no firebase_firestore dependency required to run).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'date_time_utils.dart';

// ─── Interface (abstract class) ───────────────────────────────────────────────

abstract class HRRepository {
  ValueNotifier<Staff?> get currentUser;
  ValueNotifier<List<Staff>> get staffList;
  ValueNotifier<List<Attendance>> get attendanceList;
  ValueNotifier<List<StaffSignInRecord>> get staffSignInRecords;
  ValueNotifier<List<TaskItem>> get tasksList;
  ValueNotifier<List<DailyUpdate>> get dailyUpdatesList;
  ValueNotifier<List<LeaveRequest>> get leaveRequests;
  ValueNotifier<List<ResignationRequest>> get resignationRequests;
  ValueNotifier<bool> get isFirebaseConnected;

  Future<Staff> signIn(String email, String password);
  Future<void> recordStaffSignIn(StaffSignInRecord record);
  Future<void> switchUserDirect(Staff staff);
  void signOut();
  Future<String> sendPasswordReset(String email);

  Future<Staff> addStaff({
    required String name,
    required String email,
    required String phoneNumber,
    required String department,
    required String role,
    required String joinDate,
  });

  Future<void> updateStaff(Staff staff);
  Future<void> markStaffResigned(String staffId, String resignedDate);

  Future<Attendance> checkIn(String staffId);
  Future<void> checkOut(String attendanceId);
  Future<void> toggleBreak(String attendanceId);
  Future<void> endExpiredBreak(String attendanceId);
  Future<void> requestLeave(
      {required String staffId,
      required String fromDate,
      required String toDate,
      required String reason,
      String type = 'Casual Leave',
      String? documentName,
      String? documentUrl});
  Future<void> reviewLeave(String requestId, bool approved);
  Future<void> deleteLeaveRequest(String requestId);
  Future<void> requestResignation(
      {required String staffId,
      required String lastWorkingDate,
      required String reason});
  Future<void> reviewResignation(String requestId, bool approved);

  Future<TaskItem> assignTask({
    required String staffId,
    required String department,
    required String description,
    required String dueDate,
  });

  Future<void> updateTaskStatus(String taskId, String status);
  Future<DailyUpdate> submitDailyUpdate(String staffId, String text);
}

// ─── Implementation ───────────────────────────────────────────────────────────

class HRRepositoryImpl implements HRRepository {
  late final Future<void> _attendanceRestored;
  HRRepositoryImpl() {
    _seedInitialData();
    _attendanceRestored = _restoreAttendance();
  }

  @override
  final currentUser = ValueNotifier<Staff?>(null);
  @override
  final staffList = ValueNotifier<List<Staff>>([]);
  @override
  final attendanceList = ValueNotifier<List<Attendance>>([]);
  @override
  final staffSignInRecords = ValueNotifier<List<StaffSignInRecord>>([]);
  @override
  final tasksList = ValueNotifier<List<TaskItem>>([]);
  @override
  final dailyUpdatesList = ValueNotifier<List<DailyUpdate>>([]);
  @override
  final leaveRequests = ValueNotifier<List<LeaveRequest>>([]);
  @override
  final resignationRequests = ValueNotifier<List<ResignationRequest>>([]);
  @override
  final isFirebaseConnected = ValueNotifier<bool>(false);
  void _seedInitialData() {
    final today = DateTimeUtils.getTodayIsoDate();

    final hrManager = Staff(
      id: 'staff_1',
      name: 'Anita Rao',
      email: 'anita.rao@company.com',
      phoneNumber: '',
      department: Department.tech,
      role: Role.hrManager,
      joinDate: '2024-01-15',
      status: Status.active,
      onLeaveToday: true,
    );
    final techLead = Staff(
      id: 'staff_2',
      name: 'Arjun Desai',
      email: 'arjun.desai@company.com',
      phoneNumber: '',
      department: Department.tech,
      role: Role.staff,
      joinDate: '2024-02-01',
      status: Status.active,
      onLeaveToday: true,
    );
    final techDev = Staff(
      id: 'staff_3',
      name: 'Meera Iyer',
      email: 'meera.iyer@company.com',
      phoneNumber: '',
      department: Department.tech,
      role: Role.staff,
      joinDate: '2024-03-10',
      status: Status.active,
      onLeaveToday: true,
    );
    final telecallingLead = Staff(
      id: 'staff_4',
      name: 'Priya Nair',
      email: 'priya.nair@company.com',
      phoneNumber: '',
      department: Department.telecalling,
      role: Role.staff,
      joinDate: '2024-04-12',
      status: Status.active,
      onLeaveToday: false,
    );
    final telecallingAgent = Staff(
      id: 'staff_5',
      name: 'Rahul Menon',
      email: 'rahul.menon@company.com',
      phoneNumber: '',
      department: Department.telecalling,
      role: Role.staff,
      joinDate: '2024-05-20',
      status: Status.active,
      onLeaveToday: true,
    );
    final resignedStaff = Staff(
      id: 'staff_7',
      name: 'Vikram Shah',
      email: 'vikram.shah@company.com',
      phoneNumber: '',
      department: Department.tech,
      role: Role.staff,
      joinDate: '2024-04-10',
      status: Status.resigned,
      onLeaveToday: false,
      resignedDate: '2026-09-01',
    );
    final onLeaveStaff = Staff(
      id: 'staff_6',
      name: 'Sneha Kapoor',
      email: 'sneha.kapoor@company.com',
      phoneNumber: '',
      department: Department.telecalling,
      role: Role.staff,
      joinDate: '2024-06-15',
      status: Status.active,
      onLeaveToday: true,
    );

    staffList.value = [
      hrManager,
      techLead,
      techDev,
      telecallingLead,
      telecallingAgent,
      onLeaveStaff,
      resignedStaff,
    ];

    // Attendance
    attendanceList.value = [
      Attendance(
        id: 'att_2',
        staffId: telecallingLead.id,
        date: today,
        checkInTime: '10:26 AM',
        workedDuration: '5h 00m',
        breakDuration: '1 · 0h 00m',
        isLate: true,
      ),
    ];

    // Tasks
    tasksList.value = [];

    // Daily Updates
    dailyUpdatesList.value = [
      DailyUpdate(id: 'upd_1', staffId: techLead.id, date: '2026-09-08'),
      DailyUpdate(id: 'upd_2', staffId: techDev.id, date: '2026-09-08'),
      DailyUpdate(id: 'upd_3', staffId: telecallingLead.id, date: '2026-09-16'),
    ];
    leaveRequests.value = [];
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  @override
  Future<Staff> signIn(String email, String password) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || password.trim().isEmpty || !trimmed.contains('@')) {
      throw Exception('Please enter a valid demo email and password.');
    }

    final found = staffList.value.firstWhere(
      (s) => s.email.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => const Staff(id: '__not_found__'),
    );

    if (found.id != '__not_found__') {
      currentUser.value = found;
      return found;
    }

    throw Exception('No staff account was found for this email.');
  }

  @override
  Future<void> recordStaffSignIn(StaffSignInRecord record) async {
    staffSignInRecords.value = [record, ...staffSignInRecords.value];
  }

  @override
  Future<void> switchUserDirect(Staff staff) async {
    currentUser.value = staff;
  }

  @override
  void signOut() {
    currentUser.value = null;
  }

  @override
  Future<String> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    return 'Password reset link sent to $trimmed. Please check your inbox.';
  }

  // ── Staff CRUD ────────────────────────────────────────────────────────────

  @override
  Future<Staff> addStaff({
    required String name,
    required String email,
    required String phoneNumber,
    required String department,
    required String role,
    required String joinDate,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phoneNumber.trim();

    if (trimmedName.isEmpty || trimmedEmail.isEmpty || trimmedPhone.isEmpty) {
      throw Exception('Name, email, and phone number cannot be empty.');
    }
    if (staffList.value.any(
      (s) => s.email.toLowerCase() == trimmedEmail.toLowerCase(),
    )) {
      throw Exception('Staff member with this email already exists.');
    }

    final newStaff = Staff(
      id: 'staff_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      name: trimmedName,
      email: trimmedEmail,
      phoneNumber: trimmedPhone,
      department: department,
      role: role,
      joinDate:
          joinDate.isNotEmpty ? joinDate : DateTimeUtils.getTodayIsoDate(),
      status: Status.active,
    );

    staffList.value = [...staffList.value, newStaff];
    return newStaff;
  }

  @override
  Future<void> updateStaff(Staff staff) async {
    staffList.value =
        staffList.value.map((s) => s.id == staff.id ? staff : s).toList();
    if (currentUser.value?.id == staff.id) {
      currentUser.value = staff;
    }
  }

  @override
  Future<void> markStaffResigned(String staffId, String resignedDate) async {
    final date = resignedDate.isNotEmpty
        ? resignedDate
        : DateTimeUtils.getTodayIsoDate();
    staffList.value = staffList.value.map((s) {
      if (s.id == staffId) {
        return s.copyWith(status: Status.resigned, resignedDate: date);
      }
      return s;
    }).toList();
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  @override
  Future<Attendance> checkIn(String staffId) async {
    await _attendanceRestored;
    final today = DateTimeUtils.getTodayIsoDate();
    final existing = attendanceList.value.firstWhere(
      (a) => a.staffId == staffId && a.date == today,
      orElse: () => const Attendance(id: '__none__'),
    );
    if (existing.id != '__none__') {
      throw Exception('Already checked in today at ${existing.checkInTime}.');
    }

    final timeNow = DateTimeUtils.getCurrentTime();
    final attendance = Attendance(
      id: 'att_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      staffId: staffId,
      date: today,
      checkInTime: timeNow,
      isLate: DateTimeUtils.isTimeLate(timeNow),
      checkInAt: DateTime.now(),
    );

    attendanceList.value = [attendance, ...attendanceList.value];
    await _saveAttendance();
    return attendance;
  }

  @override
  Future<void> checkOut(String attendanceId) async {
    await _attendanceRestored;
    final timeNow = DateTimeUtils.getCurrentTime();
    final now = DateTime.now();
    attendanceList.value = attendanceList.value.map((a) {
      if (a.id == attendanceId) {
        if (a.checkOutTime != null) return a;
        final active = a.breaks.where((b) => b.isActive).toList();
        final open = active.isEmpty ? null : active.first;
        final attendance = open == null ? a : _closeBreak(a, open, now);
        final totalBreak = attendance.totalBreakSeconds;
        final worked = a.checkInAt == null
            ? ''
            : _formatDuration(
                now.difference(a.checkInAt!).inSeconds - totalBreak);
        return attendance.copyWith(
            checkOutTime: timeNow,
            checkOutAt: now,
            workedDuration: worked,
            breakDuration: _formatDuration(totalBreak),
        );
      }
      return a;
    }).toList();
    await _saveAttendance();
  }

  @override
  Future<void> toggleBreak(String attendanceId) async {
    await _attendanceRestored;
    final now = DateTime.now();
    final found = attendanceList.value.where((a) => a.id == attendanceId).toList();
    if (found.isEmpty) throw Exception('Attendance record not found.');
    final a = found.first;
    if (a.date != DateTimeUtils.getTodayIsoDate()) throw Exception('Breaks can only be recorded for today.');
    if (a.checkOutTime != null) throw Exception('This shift is already complete.');
    if (a.checkInAt == null) throw Exception('Check in before starting a break.');
    final active = a.breaks.where((b) => b.isActive).toList();
    Attendance updated;
    if (active.isNotEmpty) {
      updated = _closeBreak(a, active.first, now);
    } else {
      if (a.breaks.length >= AttendanceBreakSchedule.types.length) {
        throw Exception('All breaks for today have been used.');
      }
      final nextBreakIndex = a.breaks.length;
      if (!AttendanceBreakSchedule.canStart(now, nextBreakIndex)) {
        throw Exception('The next break is not available yet.');
      }
      final record = AttendanceBreak(id: 'break_${now.microsecondsSinceEpoch}',
          attendanceId: a.id,
          breakType: AttendanceBreakSchedule.types[nextBreakIndex],
          startTime: now);
      updated = a.copyWith(breakStartedAt: now, breaks: [...a.breaks, record]);
    }
    attendanceList.value = attendanceList.value.map((item) => item.id == a.id ? updated : item).toList();
    await _saveAttendance();
  }

  @override
  Future<void> endExpiredBreak(String attendanceId) async {
    await _attendanceRestored;
    final now = DateTime.now();
    final found = attendanceList.value.where((a) => a.id == attendanceId).toList();
    if (found.isEmpty) return;
    final attendance = found.first;
    if (attendance.checkOutTime != null) return;
    final active = attendance.breaks.where((b) => b.isActive).firstOrNull;
    if (active == null ||
        now.difference(active.startTime).inSeconds < active.allowanceSeconds) {
      return;
    }
    final updated = _closeBreak(attendance, active, now);
    attendanceList.value = attendanceList.value
        .map((item) => item.id == attendance.id ? updated : item)
        .toList();
    await _saveAttendance();
  }

  Attendance _closeBreak(
      Attendance attendance, AttendanceBreak activeBreak, DateTime now) {
    final seconds = activeBreak.durationAt(now);
    final endTime = activeBreak.startTime.add(Duration(seconds: seconds));
    final breaks = attendance.breaks.map((item) => item.id == activeBreak.id
        ? AttendanceBreak(
            id: activeBreak.id,
            attendanceId: activeBreak.attendanceId,
            breakType: activeBreak.breakType,
            startTime: activeBreak.startTime,
            endTime: endTime,
            durationSeconds: seconds)
        : item).toList();
    final total = attendance.totalBreakSeconds + seconds;
    return attendance.copyWith(
        breaks: breaks,
        totalBreakSeconds: total,
        breakDuration: _formatDuration(total),
        clearBreakStartedAt: true);
  }

  Future<void> _restoreAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('staffhub.attendance.v1');
      if (raw == null) return;
      final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      attendanceList.value = rows.map(_attendanceFromJson).toList();
    } catch (_) {}
  }

  Future<void> _saveAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staffhub.attendance.v1', jsonEncode(attendanceList.value.map(_attendanceToJson).toList()));
  }

  Map<String, dynamic> _attendanceToJson(Attendance a) => {
    'id': a.id, 'staffId': a.staffId, 'date': a.date, 'checkInTime': a.checkInTime,
    'checkOutTime': a.checkOutTime, 'workedDuration': a.workedDuration,
    'breakDuration': a.breakDuration, 'isLate': a.isLate,
    'checkInAt': a.checkInAt?.toIso8601String(), 'checkOutAt': a.checkOutAt?.toIso8601String(), 'totalBreakSeconds': a.totalBreakSeconds,
    'breaks': a.breaks.map((b) => {'id': b.id, 'attendanceId': b.attendanceId,
      'breakType': b.breakType, 'startTime': b.startTime.toIso8601String(),
      'endTime': b.endTime?.toIso8601String(), 'durationSeconds': b.durationSeconds}).toList(),
  };

  Attendance _attendanceFromJson(Map<String, dynamic> j) => Attendance(
    id: j['id'] as String, staffId: j['staffId'] as String, date: j['date'] as String,
    checkInTime: j['checkInTime'] as String, checkOutTime: j['checkOutTime'] as String?,
    workedDuration: j['workedDuration'] as String? ?? '', breakDuration: j['breakDuration'] as String? ?? '',
    isLate: j['isLate'] as bool? ?? false, checkInAt: DateTime.tryParse(j['checkInAt'] as String? ?? ''),
    checkOutAt: DateTime.tryParse(j['checkOutAt'] as String? ?? ''),
    totalBreakSeconds: j['totalBreakSeconds'] as int? ?? 0,
    breaks: ((j['breaks'] as List?) ?? []).map((x) { final b = x as Map<String, dynamic>;
      return AttendanceBreak(id: b['id'] as String, attendanceId: b['attendanceId'] as String,
        breakType: b['breakType'] as String, startTime: DateTime.parse(b['startTime'] as String),
        endTime: DateTime.tryParse(b['endTime'] as String? ?? ''), durationSeconds: b['durationSeconds'] as int? ?? 0);
    }).toList(),
  );

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    return '${safe ~/ 3600}h ${(safe % 3600) ~/ 60}m';
  }

  @override
  Future<void> requestLeave(
      {required String staffId,
      required String fromDate,
      required String toDate,
      required String reason,
      String type = 'Casual Leave',
      String? documentName,
      String? documentUrl}) async {
    if (reason.trim().isEmpty)
      throw Exception('Please enter a reason for leave.');
    leaveRequests.value = [
      LeaveRequest(
          id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
          staffId: staffId,
          fromDate: fromDate,
          toDate: toDate,
          reason: reason.trim(),
          type: type,
          documentName: documentName,
          documentUrl: documentUrl,
          createdAt: DateTime.now()),
      ...leaveRequests.value
    ];
  }

  @override
  Future<void> deleteLeaveRequest(String requestId) async {
    leaveRequests.value =
        leaveRequests.value.where((r) => r.id != requestId).toList();
  }

  @override
  Future<void> reviewLeave(String requestId, bool approved) async {
    final request =
        leaveRequests.value.where((r) => r.id == requestId).firstOrNull;
    leaveRequests.value = leaveRequests.value
        .map((r) => r.id == requestId
            ? r.copyWith(
                status: approved ? LeaveStatus.approved : LeaveStatus.rejected)
            : r)
        .toList();
    if (approved &&
        request != null &&
        request.fromDate == DateTimeUtils.getTodayIsoDate()) {
      staffList.value = staffList.value
          .map((s) =>
              s.id == request.staffId ? s.copyWith(onLeaveToday: true) : s)
          .toList();
    }
  }

  @override
  Future<void> requestResignation(
      {required String staffId,
      required String lastWorkingDate,
      required String reason}) async {
    if (reason.trim().isEmpty)
      throw Exception('Please enter a resignation reason.');
    resignationRequests.value = [
      ResignationRequest(
          id: 'res_${DateTime.now().millisecondsSinceEpoch}',
          staffId: staffId,
          lastWorkingDate: lastWorkingDate,
          reason: reason.trim()),
      ...resignationRequests.value
    ];
  }

  @override
  Future<void> reviewResignation(String requestId, bool approved) async {
    final request =
        resignationRequests.value.where((r) => r.id == requestId).firstOrNull;
    resignationRequests.value = resignationRequests.value
        .map((r) => r.id == requestId
            ? r.copyWith(
                status: approved ? LeaveStatus.approved : LeaveStatus.rejected)
            : r)
        .toList();
    if (approved && request != null)
      await markStaffResigned(request.staffId, request.lastWorkingDate);
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  @override
  Future<TaskItem> assignTask({
    required String staffId,
    required String department,
    required String description,
    required String dueDate,
  }) async {
    if (description.trim().isEmpty) {
      throw Exception('Task description cannot be empty.');
    }

    final task = TaskItem(
      id: 'task_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      staffId: staffId,
      department: department,
      description: description.trim(),
      status: TaskStatus.pending,
      date: DateTimeUtils.getTodayIsoDate(),
      dueDate: dueDate.isNotEmpty ? dueDate : DateTimeUtils.getTodayIsoDate(),
    );

    tasksList.value = [task, ...tasksList.value];
    return task;
  }

  @override
  Future<void> updateTaskStatus(String taskId, String status) async {
    tasksList.value = tasksList.value.map((t) {
      if (t.id == taskId) return t.copyWith(status: status);
      return t;
    }).toList();
  }

  // ── Daily Updates ─────────────────────────────────────────────────────────

  @override
  Future<DailyUpdate> submitDailyUpdate(String staffId, String text) async {
    if (text.trim().isEmpty) {
      throw Exception('Daily update description cannot be empty.');
    }

    final update = DailyUpdate(
      id: 'upd_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      staffId: staffId,
      date: DateTimeUtils.getTodayIsoDate(),
      updateText: text.trim(),
    );

    dailyUpdatesList.value = [update, ...dailyUpdatesList.value];
    return update;
  }

  void dispose() {
    currentUser.dispose();
    staffList.dispose();
    attendanceList.dispose();
    staffSignInRecords.dispose();
    tasksList.dispose();
    dailyUpdatesList.dispose();
    leaveRequests.dispose();
    resignationRequests.dispose();
    isFirebaseConnected.dispose();
  }
}
