import 'package:flutter/foundation.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/hr_repository.dart';

class MockHRRepository implements HRRepository {
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
  final isFirebaseConnected = ValueNotifier<bool>(true);

  @override
  Future<Staff> signIn(String email, String password) async {
    return Staff(
        id: '1',
        name: 'Mock',
        email: email,
        department: 'Tech',
        role: Role.staff,
        status: Status.active);
  }

  @override
  Future<void> recordStaffSignIn(StaffSignInRecord record) async {}

  @override
  Future<void> switchUserDirect(Staff staff) async {}

  @override
  void signOut() {}

  @override
  Future<String> sendPasswordReset(String email) async => 'Sent';

  @override
  Future<Staff> addStaff(
      {required String name,
      required String email,
      required String phoneNumber,
      required String department,
      required String role,
      required String joinDate}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStaff(Staff staff) async {}

  @override
  Future<void> markStaffResigned(String staffId, String resignedDate) async {}

  @override
  Future<Staff> fetchProfile() async {
    return Staff(
        id: '1',
        name: 'Mock',
        email: 'mock@example.com',
        department: 'Tech',
        role: Role.staff,
        status: Status.active);
  }

  @override
  Future<void> updateProfile({String? phone, String? address}) async {}

  @override
  Future<void> fetchStaffAttendance() async {}

  @override
  Future<Attendance> checkIn(String staffId) async {
    final att = Attendance(
        id: 'att1',
        staffId: staffId,
        date: DateTime.now().toIso8601String(),
        checkInTime: DateTime.now().toIso8601String(),
        breaks: []);
    attendanceList.value = [att, ...attendanceList.value];
    return att;
  }

  @override
  Future<void> checkOut(String attendanceId) async {
    final idx = attendanceList.value.indexWhere((a) => a.id == attendanceId);
    if (idx != -1) {
      final a = attendanceList.value[idx];
      attendanceList.value[idx] =
          a.copyWith(checkOutTime: DateTime.now().toIso8601String());
      attendanceList.value = List.from(attendanceList.value);
    }
  }

  @override
  Future<void> toggleBreak(String attendanceId, {String? breakType}) async {
    final idx = attendanceList.value.indexWhere((a) => a.id == attendanceId);
    if (idx != -1) {
      final a = attendanceList.value[idx];
      if (a.isOnBreak) {
        final b = a.breaks.last;
        final updatedBreaks = List<AttendanceBreak>.from(a.breaks);
        const duration = 15 * 60;
        updatedBreaks.last = AttendanceBreak(
          id: b.id,
          attendanceId: b.attendanceId,
          breakType: b.breakType,
          startTime: b.startTime,
          endTime: DateTime.now(),
          durationSeconds: duration,
        );
        attendanceList.value[idx] = a.copyWith(
          breaks: updatedBreaks,
          clearBreakStartedAt: true,
          totalBreakSeconds: a.totalBreakSeconds + duration,
        );
      } else {
        final type = breakType ?? 'lunch';
        final b = AttendanceBreak(
          id: 'b1',
          attendanceId: attendanceId,
          breakType: type,
          startTime: DateTime.now(),
        );
        attendanceList.value[idx] = a.copyWith(
          breaks: [...a.breaks, b],
          breakStartedAt: DateTime.now(),
        );
      }
      attendanceList.value = List.from(attendanceList.value);
    }
  }

  @override
  Future<void> endExpiredBreak(String attendanceId) async {
    final idx = attendanceList.value.indexWhere((a) => a.id == attendanceId);
    if (idx != -1) {
      final a = attendanceList.value[idx];
      if (a.isOnBreak) {
        final b = a.breaks.last;
        final updatedBreaks = List<AttendanceBreak>.from(a.breaks);
        const duration = 15 * 60;
        updatedBreaks.last = AttendanceBreak(
          id: b.id,
          attendanceId: b.attendanceId,
          breakType: b.breakType,
          startTime: b.startTime,
          endTime: b.startTime.add(const Duration(minutes: 15)),
          durationSeconds: duration,
        );
        attendanceList.value[idx] = a.copyWith(
          breaks: updatedBreaks,
          breakStartedAt: null,
          totalBreakSeconds: a.totalBreakSeconds + duration,
        );
      }
      attendanceList.value = List.from(attendanceList.value);
    }
  }

  @override
  Future<void> requestLeave({
    required String staffId,
    required String fromDate,
    required String toDate,
    required String reason,
    String type = 'Casual Leave',
    String? documentName,
    String? documentUrl,
    Uint8List? documentBytes,
  }) async {
    leaveRequests.value = [
      LeaveRequest(
        id: 'l1',
        staffId: staffId,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        type: type,
        documentName: documentName,
        documentUrl: documentUrl,
        createdAt: DateTime.now(),
      ),
      ...leaveRequests.value
    ];
  }

  @override
  Future<Uint8List> downloadDocument(String documentUrlOrId) async {
    return Uint8List(0);
  }

  @override
  Future<void> reviewLeave(String requestId, bool approved) async {
    leaveRequests.value = leaveRequests.value
        .map((r) => r.id == requestId
            ? r.copyWith(
                status: approved ? LeaveStatus.approved : LeaveStatus.rejected)
            : r)
        .toList();
  }

  @override
  Future<void> fetchStaffLeaves() async {}

  @override
  Future<void> deleteLeaveRequest(String requestId) async {
    leaveRequests.value =
        leaveRequests.value.where((l) => l.id != requestId).toList();
  }

  @override
  Future<void> requestResignation(
      {required String staffId,
      required String lastWorkingDate,
      required String reason}) async {}

  @override
  Future<void> reviewResignation(String requestId, bool approved) async {}

  @override
  Future<TaskItem> assignTask(
      {required String staffId,
      required String department,
      required String description,
      required String dueDate}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTaskStatus(String taskId, String status) async {}

  @override
  Future<void> fetchDailyUpdates() async {
    // Mock: no-op; tests set dailyUpdatesList.value directly
  }

  @override
  Future<DailyUpdate> submitDailyUpdate(String title, String text) async {
    if (title.trim().isEmpty)
      throw Exception('Please enter a title for the update.');
    if (text.trim().isEmpty)
      throw Exception('Please enter details for the update.');
    final update = DailyUpdate(
      id: 'mock_upd_${DateTime.now().millisecondsSinceEpoch}',
      staffId: currentUser.value?.id ?? '',
      title: title.trim(),
      updateText: text.trim(),
      date: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now(),
    );
    dailyUpdatesList.value = [update, ...dailyUpdatesList.value];
    return update;
  }
}
