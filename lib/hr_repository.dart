// ─── hr_repository.dart ───────────────────────────────────────────────────────
// Converted from Kotlin HRRepository interface + HRRepositoryImpl
// Uses ValueNotifier<T> in place of Kotlin StateFlow<T>.
// Firebase calls are stubbed (no firebase_firestore dependency required to run).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'date_time_utils.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';
import 'core/api/api_exception.dart';
import 'storage/token_storage.dart';

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

  Future<Staff> signIn(String email, String password,
      {String workMode = 'OFFICE'});
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
  Future<Staff> fetchProfile();
  Future<void> updateProfile({String? phone, String? address});

  Future<void> fetchStaffAttendance();
  Future<Attendance> fetchAttendanceDetail(String attendanceId);
  Future<void> clearAttendanceHistory();
  Future<Attendance> checkIn(String staffId);
  Future<void> checkOut(String attendanceId);
  Future<void> toggleBreak(String attendanceId, {String? breakType});
  Future<void> requestLeave(
      {required String staffId,
      required String fromDate,
      required String toDate,
      required String reason,
      String type = 'Casual Leave',
      String? documentName,
      String? documentUrl,
      Uint8List? documentBytes});
  Future<Uint8List> downloadDocument(String documentUrlOrId);
  Future<void> reviewLeave(String requestId, bool approved);
  Future<void> fetchStaffLeaves();
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

  /// Fetch this staff member's daily updates from the backend.
  Future<void> fetchDailyUpdates();

  /// Submit a new daily update for this staff member.
  /// [title] and [text] are validated before sending.
  Future<DailyUpdate> submitDailyUpdate(String title, String text);

  /// Real-time department chat messages stream / value notifier
  ValueNotifier<List<StaffChatMessage>> get departmentChatMessages;

  /// Fetch department messages for the authenticated staff member's department
  /// or explicitly for [departmentKey] if provided.
  Future<List<StaffChatMessage>> fetchDepartmentMessages({
    String? departmentKey,
    int page = 1,
    int limit = 50,
  });

  /// Send a message from the authenticated staff member to their department conversation.
  Future<StaffChatMessage> sendDepartmentMessage(
    String text, {
    String? departmentKey,
    String? clientMessageId,
  });

  /// Delete a message for the local user only
  Future<void> deleteDepartmentMessageForMe(String messageId);

  /// Delete a message for everyone (if authorized)
  Future<void> deleteDepartmentMessageForEveryone(String messageId);
}

// ─── Implementation ───────────────────────────────────────────────────────────

class HRRepositoryImpl implements HRRepository {
  late final Future<void> _attendanceRestored;
  final ApiService _api;

  HRRepositoryImpl({ApiService? api}) : _api = api ?? ApiService() {
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
  @override
  final departmentChatMessages = ValueNotifier<List<StaffChatMessage>>([]);
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

    // Daily Updates: seeded from backend on demand; start empty.
    dailyUpdatesList.value = [];
    leaveRequests.value = [];
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  @override
  Future<Staff> signIn(String email, String password,
      {String workMode = 'OFFICE'}) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw Exception('Please enter a valid work email.');
    }
    if (trimmedPassword.isEmpty) {
      throw Exception('Please enter your password.');
    }

    if (workMode != 'OFFICE' && workMode != 'WORK_FROM_HOME') {
      throw Exception('Please select a valid work mode.');
    }

    try {
      final body = <String, dynamic>{
        'email': trimmedEmail,
        'password': trimmedPassword,
        'workMode': workMode,
      };
      final response = await _api.post(
        ApiConfig.login,
        body: body,
        requiresAuth: false,
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        final message =
            (response is Map ? response['message']?.toString() : null) ??
                'Login failed. Please verify your credentials.';
        throw Exception(message);
      }

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Malformed login response: missing data object.');
      }

      final token = data['accessToken']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString();
      if (token.isNotEmpty) {
        await TokenStorage.saveTokens(token: token, refreshToken: refreshToken);
      }
      final savedWorkMode = _canonicalWorkMode(data['workMode'] ?? workMode);
      await TokenStorage.saveWorkMode(savedWorkMode);

      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final rawRole = (userMap['role'] ?? '').toString().toUpperCase();

      if (userMap['isActive'] == false) {
        await TokenStorage.clearTokens();
        throw Exception(
            'Your account has been deactivated. Please contact HR.');
      }

      // Check role: Only staff accounts may sign in to the Staff Portal
      if (rawRole != 'STAFF' && rawRole != 'EMPLOYEE') {
        await TokenStorage.clearTokens();
        throw Exception(
            'Access denied: Only staff accounts can access the Staff Portal.');
      }

      final empMap = (userMap['employee'] is Map<String, dynamic>)
          ? userMap['employee'] as Map<String, dynamic>
          : (userMap['employee'] is Map
              ? Map<String, dynamic>.from(userMap['employee'] as Map)
              : null);

      final staffId = empMap?['employeeId']?.toString() ??
          empMap?['_id']?.toString() ??
          userMap['_id']?.toString() ??
          '';

      final firstName = empMap?['firstName']?.toString() ??
          userMap['firstName']?.toString() ??
          '';
      final lastName = empMap?['lastName']?.toString() ??
          userMap['lastName']?.toString() ??
          '';
      final fullName = ('$firstName $lastName').trim();
      final staffName = fullName.isNotEmpty
          ? fullName
          : (userMap['name']?.toString() ?? 'Staff Member');

      final rawDept = (empMap?['department'] ?? userMap['department'] ?? '')
          .toString()
          .trim();
      final staffDept = rawDept.toLowerCase().contains('tele')
          ? Department.telecalling
          : (rawDept.toLowerCase().contains('tech')
              ? Department.tech
              : (rawDept.isNotEmpty ? rawDept : Department.tech));

      final staffStatus =
          (empMap?['status']?.toString().toUpperCase() == 'INACTIVE' ||
                  empMap?['status']?.toString().toUpperCase() == 'TERMINATED')
              ? Status.resigned
              : Status.active;

      final rawSchedule = empMap?['schedule'] ??
          empMap?['scheduleSnapshot'] ??
          userMap['schedule'];
      final rawShift = empMap?['shift'] ?? userMap['shift'];

      final staff = Staff(
        id: staffId,
        name: staffName,
        email: userMap['email']?.toString() ?? trimmedEmail,
        phoneNumber:
            empMap?['phone']?.toString() ?? userMap['phone']?.toString() ?? '',
        address: empMap?['address']?.toString() ?? '',
        department: staffDept,
        role: Role.staff,
        joinDate: empMap?['joiningDate'] != null
            ? empMap!['joiningDate'].toString().split('T').first
            : DateTime.now().toString().split(' ').first,
        status: staffStatus,
        onLeaveToday: empMap?['status']?.toString().toUpperCase() == 'ON_LEAVE',
        schedule:
            rawSchedule is Map ? Map<String, dynamic>.from(rawSchedule) : null,
        shift: rawShift?.toString(),
      );

      currentUser.value = staff;

      // Update local staffList so UI screens find the logged-in staff member
      final list = List<Staff>.from(staffList.value);
      final idx = list.indexWhere((s) =>
          s.id == staff.id ||
          s.email.toLowerCase() == staff.email.toLowerCase());
      if (idx != -1) {
        list[idx] = staff;
      } else {
        list.add(staff);
      }
      staffList.value = list;

      return staff;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw Exception('Invalid email or password.');
      } else if (e.statusCode == 403) {
        throw Exception(e.message);
      } else if (e.statusCode == 404) {
        throw Exception(
            'Account not found or not linked to an employee profile.');
      } else if (e.statusCode == 422) {
        throw Exception(e.message);
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> recordStaffSignIn(StaffSignInRecord record) async {
    staffSignInRecords.value = [record, ...staffSignInRecords.value];
  }

  String _canonicalWorkMode(dynamic raw) {
    final value = raw
        ?.toString()
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return value == 'WORK_FROM_HOME' ? 'WORK_FROM_HOME' : 'OFFICE';
  }

  @override
  Future<void> switchUserDirect(Staff staff) async {
    currentUser.value = staff;
  }

  @override
  Future<Staff> fetchProfile() async {
    try {
      final response = await _api.get(ApiConfig.staffProfile);
      if (response['success'] == true) {
        final data = response['data'];
        final backendWorkMode = data is Map ? data['workMode'] : null;
        if (backendWorkMode != null) {
          await TokenStorage.saveWorkMode(_canonicalWorkMode(backendWorkMode));
        }
        final rawSchedule = data['schedule'] ?? data['scheduleSnapshot'];
        final rawShift = data['shift']?.toString();
        final updatedStaff = currentUser.value?.copyWith(
              id: data['employeeId'] ?? currentUser.value?.id,
              name: data['firstName'] ?? currentUser.value?.name,
              department: data['department'] ?? currentUser.value?.department,
              schedule: rawSchedule is Map
                  ? Map<String, dynamic>.from(rawSchedule)
                  : currentUser.value?.schedule,
              shift: rawShift ?? currentUser.value?.shift,
            ) ??
            Staff(
              id: data['employeeId'] ?? '',
              name: data['firstName'] ?? '',
              department: data['department'] ?? Department.tech,
              schedule: rawSchedule is Map
                  ? Map<String, dynamic>.from(rawSchedule)
                  : null,
              shift: rawShift,
            );
        currentUser.value = updatedStaff;
        return updatedStaff;
      }
    } catch (e) {
      debugPrint('fetchProfile error: $e');
    }
    return currentUser.value ?? const Staff();
  }

  @override
  Future<void> updateProfile({String? phone, String? address}) async {
    final body = <String, dynamic>{};
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    try {
      final response = await _api.put(ApiConfig.staffProfile, body: body);
      if (response['success'] == true) {
        await fetchProfile();
      }
    } catch (e) {
      debugPrint('updateProfile error: $e');
      rethrow;
    }
  }

  @override
  void signOut() {
    currentUser.value = null;
    TokenStorage.clearTokens();
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
  Future<void> fetchStaffAttendance() async {
    try {
      final response = await _api.get(ApiConfig.attendance);
      if (response is! Map ||
          response['success'] != true ||
          response['data'] is! List) {
        throw const FormatException(
            'Malformed attendance response from server.');
      }
      attendanceList.value = (response['data'] as List).map((e) {
        if (e is! Map)
          throw const FormatException(
              'Malformed attendance record from server.');
        return Attendance.fromJson(
          Map<String, dynamic>.from(e),
          staffId: currentUser.value?.id,
        );
      }).toList();
      await _saveAttendance();
    } catch (e) {
      debugPrint('fetchStaffAttendance error: $e');
      rethrow;
    }
  }

  @override
  Future<Attendance> fetchAttendanceDetail(String attendanceId) async {
    try {
      final response = await _api.get(ApiConfig.attendanceDetail(attendanceId));
      if (response is! Map ||
          response['success'] != true ||
          response['data'] is! Map) {
        throw const FormatException(
            'Malformed attendance detail response from server.');
      }
      return Attendance.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
        staffId: currentUser.value?.id,
      );
    } catch (e) {
      debugPrint('fetchAttendanceDetail error: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAttendanceHistory() async {
    try {
      // Find active session for today if any (ongoing shift must not be cleared)
      Attendance? activeSession;
      for (final a in attendanceList.value) {
        if (a.isOngoing) {
          activeSession = a;
          break;
        }
      }
      dynamic response;
      try {
        response = await _api.delete(ApiConfig.attendanceClearHistory);
      } catch (_) {
        response = await _api.post(ApiConfig.attendanceClearHistoryPost, body: {});
      }
      if (response is! Map || response['success'] != true) {
        throw const FormatException(
            'Server did not confirm attendance history clearing.');
      }
      await fetchStaffAttendance();
      if (activeSession != null &&
          !attendanceList.value.any((a) => a.id == activeSession!.id)) {
        attendanceList.value = [activeSession, ...attendanceList.value];
        await _saveAttendance();
      }
    } catch (e) {
      debugPrint('clearAttendanceHistory error: $e');
      rethrow;
    }
  }

  @override
  Future<Attendance> checkIn(String staffId) async {
    try {
      final response = await _api.post(ApiConfig.attendanceCheckIn, body: {});
      if (response is! Map ||
          response['success'] != true ||
          response['data'] is! Map) {
        throw const FormatException('Malformed check-in response from server.');
      }
      final returned = Attendance.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
        staffId: currentUser.value?.id ?? staffId,
      );
      // Attendance GET is the authoritative refreshed record; never classify late locally.
      await fetchStaffAttendance();
      final refreshed = attendanceList.value
          .where((record) =>
              (returned.id.isNotEmpty && record.id == returned.id) ||
              (returned.id.isEmpty &&
                  record.isToday &&
                  (record.staffId.isEmpty ||
                      record.staffId == (currentUser.value?.id ?? staffId))))
          .firstOrNull;
      return refreshed ?? returned;
    } on ApiException catch (e) {
      if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('already checked in')) {
        await fetchStaffAttendance();
      }
      rethrow;
    } catch (e) {
      debugPrint('checkIn error: $e');
      rethrow;
    }
  }

  @override
  Future<void> checkOut(String attendanceId) async {
    try {
      final response = await _api.post(ApiConfig.attendanceCheckOut, body: {});
      if (response is! Map || response['success'] != true) {
        final message =
            response is Map ? response['message']?.toString() : null;
        throw ApiException(
            statusCode: null,
            message: message ?? 'Check-out was not confirmed by the server.');
      }
      await fetchStaffAttendance();
    } on ApiException catch (e) {
      if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('already checked out')) {
        await fetchStaffAttendance();
      }
      rethrow;
    } catch (e) {
      debugPrint('checkOut error: $e');
      rethrow;
    }
  }

  @override
  Future<void> toggleBreak(String attendanceId, {String? breakType}) async {
    await _attendanceRestored;
    final found =
        attendanceList.value.where((a) => a.id == attendanceId).toList();
    if (found.isEmpty) throw Exception('Attendance record not found.');
    final a = found.first;
    if (a.date != DateTimeUtils.getTodayIsoDate())
      throw Exception('Breaks can only be recorded for today.');
    if (a.checkOutTime != null)
      throw Exception('This shift is already complete.');
    if (a.checkInAt == null)
      throw Exception('Check in before starting a break.');
    final active = a.breaks.where((b) => b.isActive).toList();
    if (active.isNotEmpty) {
      if (breakType != null && breakType != active.first.breakType) {
        throw Exception('End the active break before starting another break.');
      }
      final response = await _api.post(
        ApiConfig.attendanceBreakEnd(a.id),
        body: {'breakType': active.first.breakType},
      );
      _validateBreakResponse(response, 'end');
    } else {
      final selectedType = breakType;
      if (selectedType == null ||
          !AttendanceBreakSchedule.types.contains(selectedType)) {
        throw ArgumentError.value(
            breakType, 'breakType', 'Choose one of the configured breaks.');
      }
      if (a.breaks.any((item) =>
          item.breakType == selectedType ||
          (selectedType == 'tea_break_1' && item.breakType == 'morning') ||
          (selectedType == 'tea_break_2' && item.breakType == 'afternoon'))) {
        throw Exception('This break has already been completed.');
      }
      final response = await _api.post(
        ApiConfig.attendanceBreakStart(a.id),
        body: {'breakType': selectedType},
      );
      _validateBreakResponse(response, 'start');
      if (response is Map && response['data'] is Map) {
        final d = Map<String, dynamic>.from(response['data'] as Map);
        final rawStart = d['startTime'] ?? d['breakStartedAt'];
        if (rawStart != null && rawStart.toString().isNotEmpty) {
          final bStart = DateTime.tryParse(rawStart.toString())?.toLocal();
          if (bStart != null) {
            final newBreak = AttendanceBreak(
              id: d['id']?.toString() ?? d['_id']?.toString() ?? '',
              attendanceId: d['attendanceId']?.toString() ?? a.id,
              breakType: d['breakType']?.toString() ?? selectedType,
              startTime: bStart,
              endTime: null,
            );
            final updatedBreaks = List<AttendanceBreak>.from(a.breaks)
              ..add(newBreak);
            final updatedRecord = a.copyWith(breaks: updatedBreaks);
            attendanceList.value = attendanceList.value.map((rec) {
              return rec.id == a.id ? updatedRecord : rec;
            }).toList();
            await _saveAttendance();
          }
        }
      }
    }
    // The attendance endpoint is authoritative for saved break timestamps.
    await fetchStaffAttendance();
  }

  void _validateBreakResponse(dynamic response, String operation) {
    if (response is! Map || response['success'] != true) {
      final message = response is Map ? response['message']?.toString() : null;
      throw ApiException(
          statusCode: null,
          message:
              message ?? 'The server did not confirm the break $operation.');
    }
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
    await prefs.setString('staffhub.attendance.v1',
        jsonEncode(attendanceList.value.map(_attendanceToJson).toList()));
  }

  Map<String, dynamic> _attendanceToJson(Attendance a) => a.toJson();

  Attendance _attendanceFromJson(Map<String, dynamic> j) =>
      Attendance.fromJson(j);

  @visibleForTesting
  String mapLeaveTypeToBackend(String t) => _mapLeaveTypeToBackend(t);

  @visibleForTesting
  String mapBackendLeaveTypeToUi(String? backendType,
          {String? displayType, bool hasDoc = false}) =>
      _mapBackendLeaveTypeToUi(backendType,
          displayType: displayType, hasDoc: hasDoc);

  String _mapLeaveTypeToBackend(String t) {
    switch (t.trim().toUpperCase()) {
      case 'CASUAL LEAVE':
      case 'CASUAL':
        return 'CASUAL';
      case 'SICK LEAVE':
      case 'SICK':
        return 'SICK';
      case 'MEDICAL LEAVE':
      case 'MEDICAL':
        return 'MEDICAL';
      case 'EARNED LEAVE':
      case 'ANNUAL LEAVE':
      case 'ANNUAL':
      case 'EARNED':
        return 'ANNUAL';
      case 'UNPAID LEAVE':
      case 'UNPAID':
        return 'UNPAID';
      case 'OTHER':
        return 'OTHER';
      default:
        return 'CASUAL';
    }
  }

  String _mapBackendLeaveTypeToUi(String? backendType,
      {String? displayType, bool hasDoc = false}) {
    if (displayType != null && displayType.trim().isNotEmpty) {
      final dt = displayType.trim().toUpperCase();
      if (dt == 'SICK LEAVE' || dt == 'SICK') return 'Sick Leave';
      if (dt == 'MEDICAL LEAVE' || dt == 'MEDICAL') return 'Medical Leave';
      if (dt == 'CASUAL LEAVE' || dt == 'CASUAL') return 'Casual Leave';
      if (dt == 'EARNED LEAVE' || dt == 'ANNUAL LEAVE' || dt == 'EARNED' || dt == 'ANNUAL') return 'Earned Leave';
      if (dt == 'UNPAID LEAVE' || dt == 'UNPAID') return 'Unpaid Leave';
      if (dt == 'OTHER') return 'Other';
    }
    switch (backendType?.trim().toUpperCase()) {
      case 'CASUAL':
        return 'Casual Leave';
      case 'SICK':
        return 'Sick Leave';
      case 'MEDICAL':
        return 'Medical Leave';
      case 'ANNUAL':
      case 'EARNED':
        return 'Earned Leave';
      case 'UNPAID':
        return 'Unpaid Leave';
      case 'OTHER':
        return 'Other';
      default:
        return backendType ?? 'Casual Leave';
    }
  }

  String _mapBackendStatusToUi(String? status) {
    switch (status?.trim().toUpperCase()) {
      case 'APPROVED':
        return LeaveStatus.approved;
      case 'REJECTED':
        return LeaveStatus.rejected;
      case 'PENDING':
        return LeaveStatus.pending;
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status ?? LeaveStatus.pending;
    }
  }

  String _formatDateForBackend(String d) {
    if (d.contains('T')) return d.split('T')[0];
    return d.trim();
  }

  @override
  Future<void> fetchStaffLeaves() async {
    try {
      final response = await _api.get(ApiConfig.leaves);
      if (response['success'] == true) {
        final data = response['data'] as List?;
        if (data != null) {
          leaveRequests.value = data.map((e) {
            final docName = e['documentName'] as String?;
            final docUrl = e['documentUrl'] as String?;
            final rawDoc = e['document'];
            String? docId;
            String? resolvedDocName = docName;
            if (rawDoc is Map) {
              docId = rawDoc['_id']?.toString() ?? rawDoc['id']?.toString();
              resolvedDocName ??= (rawDoc['originalName'] as String?) ??
                  (rawDoc['fileName'] as String?);
            } else if (rawDoc is String && rawDoc.isNotEmpty) {
              docId = rawDoc;
            }
            if (docId == null && e['documentId'] != null) {
              docId = e['documentId']?.toString();
            }
            final rawType = e['leaveType'] as String?;
            final displayType = e['leaveTypeDisplay'] as String?;
            final rawStatus = e['status'] as String?;
            final staffObj = e['staff'] ?? e['employee'];
            String parsedStaffId = '';
            if (staffObj is Map) {
              parsedStaffId = staffObj['_id']?.toString() ??
                  staffObj['id']?.toString() ??
                  '';
            } else if (staffObj is String) {
              parsedStaffId = staffObj;
            }
            if (parsedStaffId.isEmpty && e['staffId'] != null) {
              parsedStaffId = e['staffId'].toString();
            }
            if (parsedStaffId.isEmpty && e['employeeId'] != null) {
              parsedStaffId = e['employeeId'].toString();
            }
            if (parsedStaffId.isEmpty) {
              parsedStaffId = currentUser.value?.id ?? '';
            }
            return LeaveRequest(
              id: e['_id'] ?? e['id'] ?? '',
              staffId: parsedStaffId,
              fromDate: e['startDate'] ?? '',
              toDate: e['endDate'] ?? '',
              reason: e['reason'] ?? '',
              type: _mapBackendLeaveTypeToUi(rawType,
                  displayType: displayType,
                  hasDoc: resolvedDocName != null ||
                      docUrl != null ||
                      docId != null),
              status: _mapBackendStatusToUi(rawStatus),
              documentName: resolvedDocName,
              documentUrl: docUrl,
              documentId: docId,
              createdAt:
                  DateTime.tryParse(e['createdAt'] ?? '') ?? DateTime.now(),
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('fetchStaffLeaves error: $e');
    }
  }

  @override
  Future<void> requestLeave(
      {required String staffId,
      required String fromDate,
      required String toDate,
      required String reason,
      String type = 'Casual Leave',
      String? documentName,
      String? documentUrl,
      Uint8List? documentBytes}) async {
    if (reason.trim().isEmpty) {
      throw Exception('Please enter a reason for leave.');
    }

    try {
      final backendLeaveType = _mapLeaveTypeToBackend(type);
      final start = _formatDateForBackend(fromDate);
      final end = _formatDateForBackend(toDate);

      if (documentBytes != null && documentBytes.isNotEmpty) {
        final fields = <String, dynamic>{
          'leaveType': backendLeaveType,
          'startDate': start,
          'endDate': end,
          'reason': reason.trim(),
        };
        if (documentName != null && documentName.isNotEmpty) {
          fields['documentName'] = documentName;
        }
        final response = await _api.postMultipart(
          ApiConfig.leaves,
          fields: fields,
          fileFieldName: 'file',
          fileBytes: documentBytes,
          fileName: documentName ??
              (backendLeaveType == 'SICK'
                  ? 'medical_proof.pdf'
                  : 'medical_certificate.pdf'),
        );
        if (response['success'] == true) {
          await fetchStaffLeaves();
        }
      } else {
        final body = <String, dynamic>{
          'leaveType': backendLeaveType,
          'startDate': start,
          'endDate': end,
          'reason': reason.trim(),
        };
        if (documentName != null) body['documentName'] = documentName;
        if (documentUrl != null) body['documentUrl'] = documentUrl;

        final response = await _api.post(ApiConfig.leaves, body: body);
        if (response['success'] == true) {
          await fetchStaffLeaves();
        }
      }
    } catch (e) {
      debugPrint('requestLeave error: $e');
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadDocument(String documentUrlOrId) async {
    String endpoint;
    final trimmed = documentUrlOrId.trim();
    if (trimmed.startsWith('/') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      endpoint = trimmed;
    } else {
      endpoint = ApiConfig.staffDocumentDownload(trimmed);
    }
    return await _api.getBytes(endpoint);
  }

  @override
  Future<void> deleteLeaveRequest(String requestId) async {
    try {
      final response = await _api.delete(ApiConfig.leaveById(requestId));
      if (response['success'] == true) {
        await fetchStaffLeaves();
      }
    } catch (e) {
      debugPrint('deleteLeaveRequest error: $e');
      rethrow;
    }
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
  Future<void> fetchDailyUpdates() async {
    try {
      final response = await _api.get(ApiConfig.dailyUpdates);
      if (response is Map && response['success'] == false) {
        throw FormatException(
            response['message']?.toString() ?? 'Failed to load daily updates.');
      }
      final raw = response is Map ? response['data'] : response;
      if (raw is! List) {
        throw const FormatException('Malformed daily updates response.');
      }
      dailyUpdatesList.value = raw.map((item) {
        if (item is! Map) {
          throw const FormatException('Malformed daily update item.');
        }
        return DailyUpdate.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } on ApiException catch (e) {
      debugPrint('fetchDailyUpdates error: $e');
      rethrow;
    } catch (e) {
      debugPrint('fetchDailyUpdates unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<DailyUpdate> submitDailyUpdate(
    String title,
    String text,
  ) async {
    final trimmedTitle = title.trim();
    final trimmedText = text.trim();
    if (trimmedTitle.isEmpty) {
      throw Exception('Please enter a title for the update.');
    }
    if (trimmedText.isEmpty) {
      throw Exception('Please enter details for the update.');
    }

    try {
      final response = await _api.post(
        ApiConfig.dailyUpdates,
        body: {
          'title': trimmedTitle,
          'updateText': trimmedText,
        },
      );

      if (response is Map && response['success'] == false) {
        throw Exception(response['message']?.toString() ??
            'Failed to submit daily update.');
      }

      final rawData = response is Map && response.containsKey('data')
          ? response['data']
          : response;
      if (rawData is! Map) {
        throw const FormatException('Malformed daily update response.');
      }

      final update = DailyUpdate.fromJson(Map<String, dynamic>.from(rawData));
      if (update.id.isEmpty ||
          update.title.isEmpty ||
          update.updateText.isEmpty) {
        throw const FormatException(
            'Daily update response is missing persisted update fields.');
      }
      dailyUpdatesList.value = [update, ...dailyUpdatesList.value];
      return update;
    } on ApiException catch (e) {
      debugPrint('submitDailyUpdate ApiException: $e');
      rethrow;
    } catch (e) {
      debugPrint('submitDailyUpdate error: $e');
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  @override
  Future<List<StaffChatMessage>> fetchDepartmentMessages({
    String? departmentKey,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final endpoint = departmentKey != null && departmentKey.isNotEmpty
          ? ApiConfig.staffDepartmentMessages(
              canonicalDepartmentKey(departmentKey))
          : ApiConfig.staffChatMessages;
      final response = await _api.get(
        endpoint,
        queryParams: {'page': page, 'limit': limit},
      );

      dynamic rawData = response;
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        rawData = response['data'];
      }

      final List<StaffChatMessage> messages = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) {
            messages.add(
              StaffChatMessage.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      // Sort chronological (oldest to newest)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Reconcile with existing messages to avoid dropping in-flight socket messages
      final existingMap = {
        for (final m in departmentChatMessages.value)
          if (m.id.isNotEmpty) m.id: m
      };
      for (final m in messages) {
        if (m.id.isNotEmpty) {
          existingMap[m.id] = m;
        }
      }
      final merged = existingMap.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      departmentChatMessages.value = merged;
      return merged;
    } on ApiException catch (e) {
      debugPrint('fetchDepartmentMessages ApiException: $e');
      rethrow;
    } catch (e) {
      debugPrint('fetchDepartmentMessages error: $e');
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  @override
  Future<StaffChatMessage> sendDepartmentMessage(
    String text, {
    String? departmentKey,
    String? clientMessageId,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final effectiveClientMessageId =
        clientMessageId ?? 'client_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final endpoint = departmentKey != null && departmentKey.isNotEmpty
          ? ApiConfig.staffDepartmentMessages(
              canonicalDepartmentKey(departmentKey))
          : ApiConfig.staffChatMessages;

      final body = <String, dynamic>{
        'text': trimmedText,
        'clientMessageId': effectiveClientMessageId,
      };

      final response = await _api.post(endpoint, body: body);

      dynamic rawData = response;
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        rawData = response['data'];
      }

      if (rawData is! Map) {
        throw Exception('Invalid message response received from backend');
      }

      final savedMessage = StaffChatMessage.fromJson(
        Map<String, dynamic>.from(rawData),
      );

      // Reconcile local departmentChatMessages
      final currentList =
          List<StaffChatMessage>.from(departmentChatMessages.value);
      final existingIndex = currentList.indexWhere((m) =>
          (m.id.isNotEmpty && m.id == savedMessage.id) ||
          (m.clientMessageId != null &&
              m.clientMessageId == savedMessage.clientMessageId));

      if (existingIndex >= 0) {
        currentList[existingIndex] = savedMessage;
      } else {
        currentList.add(savedMessage);
      }
      currentList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      departmentChatMessages.value = currentList;

      return savedMessage;
    } on ApiException catch (e) {
      debugPrint('sendDepartmentMessage ApiException: $e');
      rethrow;
    } catch (e) {
      debugPrint('sendDepartmentMessage error: $e');
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> deleteDepartmentMessageForMe(String messageId) async {
    try {
      await _api.patch(ApiConfig.staffChatMessageDeleteForMe(messageId));
      departmentChatMessages.value =
          departmentChatMessages.value.where((m) => m.id != messageId).toList();
    } catch (e) {
      debugPrint('deleteDepartmentMessageForMe error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDepartmentMessageForEveryone(String messageId) async {
    try {
      await _api.delete(ApiConfig.staffChatMessageDelete(messageId));
      departmentChatMessages.value =
          departmentChatMessages.value.where((m) => m.id != messageId).toList();
    } catch (e) {
      debugPrint('deleteDepartmentMessageForEveryone error: $e');
      rethrow;
    }
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
    departmentChatMessages.dispose();
  }
}
