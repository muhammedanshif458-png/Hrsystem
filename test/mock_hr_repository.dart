import 'package:flutter/foundation.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/core/api/api_exception.dart';

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
  final departmentChatMessages = ValueNotifier<List<StaffChatMessage>>([
    StaffChatMessage(
      id: 'mock_chat_1',
      senderId: 'staff_anshi',
      senderName: 'Anshi M.',
      senderRole: 'STAFF',
      departmentKey: 'tech',
      conversationType: 'DEPARTMENT',
      text:
          'Good morning team 👋 Hope everyone has a smooth and productive Wednesday.',
      timestamp: DateTime(2026, 9, 24, 9, 12),
      isRead: true,
    ),
    StaffChatMessage(
      id: 'mock_chat_2',
      senderId: 'staff_rahul',
      senderName: 'Rahul K.',
      senderRole: 'STAFF',
      departmentKey: 'tech',
      conversationType: 'DEPARTMENT',
      text: 'Good morning! 🚀 Starting the client installation at Apex Tower.',
      timestamp: DateTime(2026, 9, 24, 9, 18),
      isRead: true,
    ),
    StaffChatMessage(
      id: 'mock_chat_3',
      senderId: 'staff_priya',
      senderName: 'Priya S.',
      senderRole: 'STAFF',
      departmentKey: 'tech',
      conversationType: 'DEPARTMENT',
      text:
          'Wishing you all a great Wednesday. Don’t forget to sync your updates before EOD.',
      timestamp: DateTime(2026, 9, 24, 9, 26),
      isRead: true,
    ),
    StaffChatMessage(
      id: 'mock_chat_4',
      senderId: 'staff_anshi',
      senderName: 'Anshi M.',
      senderRole: 'STAFF',
      departmentKey: 'tech',
      conversationType: 'DEPARTMENT',
      text:
          'Friendly reminder: Please submit your daily work updates before 6 PM today. ✅',
      timestamp: DateTime(2026, 9, 24, 10, 2),
      isRead: true,
    ),
    StaffChatMessage(
      id: 'mock_chat_5',
      senderId: 'hr_admin',
      senderName: 'HR Team',
      senderRole: 'HR',
      departmentKey: 'tech',
      conversationType: 'DEPARTMENT',
      text:
          'Office will start at 9:30 AM tomorrow for scheduled infrastructure maintenance.',
      timestamp: DateTime(2026, 9, 24, 11, 15),
      isRead: true,
    ),
  ]);

  @override
  Future<Staff> signIn(String email, String password,
      {String workMode = 'OFFICE', String? department}) async {
    return Staff(
        id: '1',
        name: 'Mock',
        email: email,
        department: department ?? 'Tech',
        role: Role.staff,
        status: Status.active);
  }

  @override
  Future<void> recordStaffSignIn(StaffSignInRecord record) async {}

  @override
  Future<void> switchUserDirect(Staff staff) async {}

  @override
  void signOut() {
    currentUser.value = null;
  }

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
  Future<Attendance> fetchAttendanceDetail(String attendanceId) async {
    for (final a in attendanceList.value) {
      if (a.id == attendanceId) return a;
    }
    return Attendance(
      id: attendanceId,
      date: '2026-11-06',
      checkInTime: '09:30 AM',
      checkOutTime: '06:00 PM',
      status: 'PRESENT',
      workMode: 'Office',
      department: 'Tech',
    );
  }

  @override
  Future<void> clearAttendanceHistory() async {
    final active = attendanceList.value.where((a) => a.isOngoing).toList();
    attendanceList.value = active;
  }

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
  Future<void> requestLeave({
    required String staffId,
    required String fromDate,
    required String toDate,
    required String reason,
    String type = 'Casual Leave',
    String durationType = 'FULL_DAY',
    String? halfDaySession,
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
    final target =
        leaveRequests.value.where((l) => l.id == requestId).firstOrNull;
    if (target != null && target.status.toLowerCase() != 'pending') {
      throw ApiException(
        statusCode: 400,
        message: 'Cannot cancel leave request that is already ${target.status}',
      );
    }
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
  Future<List<BirthdayEmployee>> fetchTodaysBirthdays() async => const [];

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

  @override
  Future<List<StaffChatMessage>> fetchDepartmentMessages({
    String? departmentKey,
    int page = 1,
    int limit = 50,
  }) async {
    return departmentChatMessages.value;
  }

  @override
  Future<StaffChatSearchPage> searchDepartmentMessages({
    required String departmentKey,
    required String query,
    int page = 1,
    int limit = 30,
  }) async =>
      StaffChatSearchPage(
          messages: departmentChatMessages.value
              .where((message) =>
                  message.text.toLowerCase().contains(query.toLowerCase()))
              .toList(),
          hasMore: false);

  @override
  Future<void> clearDepartmentMessages({required String departmentKey}) async {
    departmentChatMessages.value = [];
  }

  @override
  Future<StaffChatMessage> sendDepartmentMessage(
    String text, {
    String? departmentKey,
    String? clientMessageId,
  }) async {
    final sender = currentUser.value;
    final message = StaffChatMessage(
      id: 'mock_msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: sender?.id ?? 'staff_chat_test',
      senderName:
          sender?.name.isNotEmpty == true ? sender!.name : 'Staff Member',
      senderRole: 'STAFF',
      departmentKey: departmentKey ?? sender?.department ?? '',
      conversationType: 'DEPARTMENT',
      clientMessageId: clientMessageId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
    );
    departmentChatMessages.value = [...departmentChatMessages.value, message];
    return message;
  }

  @override
  Future<void> deleteDepartmentMessageForMe(String messageId,
      {required String departmentKey}) async {
    departmentChatMessages.value =
        departmentChatMessages.value.where((m) => m.id != messageId).toList();
  }

  @override
  Future<void> deleteDepartmentMessageForEveryone(String messageId,
      {required String departmentKey}) async {
    departmentChatMessages.value =
        departmentChatMessages.value.where((m) => m.id != messageId).toList();
  }
}
