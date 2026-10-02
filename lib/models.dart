// ─── models.dart ──────────────────────────────────────────────────────────────
// Converted from Kotlin data classes in com.example.data.model

class Staff {
  const Staff({
    this.id = '',
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.department = Department.tech,
    this.role = Role.staff,
    this.joinDate = '',
    this.status = Status.active,
    this.onLeaveToday = false,
    this.resignedDate,
  });

  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String department;
  final String role;
  final String joinDate;
  final String status;
  final bool onLeaveToday;
  final String? resignedDate;

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? department,
    String? role,
    String? joinDate,
    String? status,
    bool? onLeaveToday,
    String? resignedDate,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      role: role ?? this.role,
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      onLeaveToday: onLeaveToday ?? this.onLeaveToday,
      resignedDate: resignedDate ?? this.resignedDate,
    );
  }
}

class Department {
  static const String all = 'All';
  static const String telecalling = 'Telecalling';
  static const String tech = 'Tech';

  static const List<String> list = [telecalling, tech];
}

class Role {
  static const String staff = 'Staff';
  static const String hrManager = 'HR Manager';

  static const List<String> list = [staff, hrManager];
}

class Status {
  static const String active = 'active';
  static const String resigned = 'resigned';
}

class AttendanceBreakSchedule {
  static const List<String> types = ['morning', 'lunch', 'afternoon'];
  static const List<String> names = [
    'Morning Break',
    'Lunch Break',
    'Afternoon Break',
  ];
  static const List<(int, int)> startTimes = [(11, 30), (13, 30), (16, 0)];

  static DateTime startsAt(DateTime date, int index) {
    final time = startTimes[index];
    return DateTime(date.year, date.month, date.day, time.$1, time.$2);
  }

  static bool canStart(DateTime now, int index) =>
      index >= 0 && index < startTimes.length && !now.isBefore(startsAt(now, index));

  static String nameForType(String type) {
    final index = types.indexOf(type);
    return index < 0 ? 'Break' : names[index];
  }
}

class AttendanceBreak {
  const AttendanceBreak({
    required this.id,
    required this.attendanceId,
    required this.breakType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
  });

  final String id;
  final String attendanceId;
  final String breakType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  bool get isActive => endTime == null;
  int get allowanceSeconds => breakType == 'lunch' ? 30 * 60 : 15 * 60;
  int durationAt(DateTime now) {
    if (endTime != null) return durationSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    return elapsed.clamp(0, allowanceSeconds);
  }
}

class Attendance {
  const Attendance({
    this.id = '',
    this.staffId = '',
    this.date = '', // YYYY-MM-DD
    this.checkInTime = '',
    this.checkOutTime,
    this.workedDuration = '',
    this.breakDuration = '',
    this.isLate = false,
    this.checkInAt,
    this.checkOutAt,
    this.breakStartedAt,
    this.totalBreakSeconds = 0,
    this.breaks = const [],
  });

  final String id;
  final String staffId;
  final String date;
  final String checkInTime;
  final String? checkOutTime;
  final String workedDuration;
  final String breakDuration;
  final bool isLate;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? breakStartedAt;
  final int totalBreakSeconds;
  final List<AttendanceBreak> breaks;

  bool get isOnBreak => breakStartedAt != null;

  Attendance copyWith({
    String? id,
    String? staffId,
    String? date,
    String? checkInTime,
    String? checkOutTime,
    String? workedDuration,
    String? breakDuration,
    bool? isLate,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    DateTime? breakStartedAt,
    bool clearBreakStartedAt = false,
    int? totalBreakSeconds,
    List<AttendanceBreak>? breaks,
  }) {
    return Attendance(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      workedDuration: workedDuration ?? this.workedDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      isLate: isLate ?? this.isLate,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      breakStartedAt:
          clearBreakStartedAt ? null : (breakStartedAt ?? this.breakStartedAt),
      totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
      breaks: breaks ?? this.breaks,
    );
  }
}

/// A staff authentication event, kept separately from shift attendance.
/// This app currently uses an in-memory repository, so these records live for
/// the lifetime of the repository instance.
class StaffSignInRecord {
  const StaffSignInRecord({
    required this.staffId,
    required this.department,
    required this.workMode,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  final String staffId;
  final String department;
  final String workMode;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
}

class LocationCapture {
  const LocationCapture(
      {required this.latitude, required this.longitude, required this.address});
  final double latitude;
  final double longitude;
  final String address;
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.staffId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.type = 'Casual Leave',
    this.documentName,
    this.documentUrl,
    this.status = LeaveStatus.pending,
    required this.createdAt,
  });

  final String id;
  final String staffId;
  final String fromDate;
  final String toDate;
  final String reason;
  final String type;
  final String? documentName;
  final String? documentUrl;
  final String status;
  final DateTime createdAt;

  LeaveRequest copyWith({String? status}) => LeaveRequest(
        id: id,
        staffId: staffId,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        type: type,
        documentName: documentName,
        documentUrl: documentUrl,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

class LeaveStatus {
  static const pending = 'Pending';
  static const approved = 'Approved';
  static const rejected = 'Rejected';
}

class ResignationRequest {
  const ResignationRequest({
    required this.id,
    required this.staffId,
    required this.lastWorkingDate,
    required this.reason,
    this.status = LeaveStatus.pending,
  });

  final String id;
  final String staffId;
  final String lastWorkingDate;
  final String reason;
  final String status;

  ResignationRequest copyWith({String? status}) => ResignationRequest(
        id: id,
        staffId: staffId,
        lastWorkingDate: lastWorkingDate,
        reason: reason,
        status: status ?? this.status,
      );
}

// ─── TaskItem ─────────────────────────────────────────────────────────────────

class TaskItem {
  const TaskItem({
    this.id = '',
    this.staffId = '',
    this.department = '',
    this.description = '',
    this.status = TaskStatus.pending,
    this.date = '',
    this.dueDate = '',
  });

  final String id;
  final String staffId;
  final String department;
  final String description;
  final String status;
  final String date;
  final String dueDate;

  TaskItem copyWith({
    String? id,
    String? staffId,
    String? department,
    String? description,
    String? status,
    String? date,
    String? dueDate,
  }) {
    return TaskItem(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      department: department ?? this.department,
      description: description ?? this.description,
      status: status ?? this.status,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

class TaskStatus {
  static const String pending = 'pending';
  static const String inProgress = 'in progress';
  static const String done = 'done';

  static const List<String> list = [pending, inProgress, done];
}

// ─── DailyUpdate ──────────────────────────────────────────────────────────────

class DailyUpdate {
  const DailyUpdate({
    this.id = '',
    this.staffId = '',
    this.date = '',
    this.updateText = '',
  });

  final String id;
  final String staffId;
  final String date;
  final String updateText;
}
