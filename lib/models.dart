// ─── models.dart ──────────────────────────────────────────────────────────────
// Converted from Kotlin data classes in com.example.data.model

class Staff {
  const Staff({
    this.id = '',
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
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
  final String address;
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
    String? address,
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
      address: address ?? this.address,
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
  static int allowanceSecondsFor(String breakType) =>
      breakType == 'lunch' ? 30 * 60 : 15 * 60;
  int get allowanceSeconds => allowanceSecondsFor(breakType);
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
    this.minutesLate,
    this.scheduleSnapshot,
    this.department,
    this.checkInAt,
    this.checkOutAt,
    this.breakStartedAt,
    this.totalBreakSeconds = 0,
    this.breaks = const [],
    this.status = 'PRESENT',
  });

  final String id;
  final String staffId;
  final String date;
  final String checkInTime;
  final String? checkOutTime;
  final String workedDuration;
  final String breakDuration;
  final bool isLate;
  final int? minutesLate;
  final Map<String, dynamic>? scheduleSnapshot;
  final String? department;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? breakStartedAt;
  final int totalBreakSeconds;
  final List<AttendanceBreak> breaks;
  final String status;

  bool get isOnBreak => breakStartedAt != null || breaks.any((b) => b.isActive);

  static String _formatTimeOfDay(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  static String _formatIsoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  bool get isToday {
    final now = DateTime.now();
    if (checkInAt != null) {
      return checkInAt!.year == now.year &&
          checkInAt!.month == now.month &&
          checkInAt!.day == now.day;
    }
    final todayIso = _formatIsoDate(now);
    return date.startsWith(todayIso);
  }

  factory Attendance.fromJson(Map<String, dynamic> json, {String? staffId}) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final rawEmployeeId = json['employee'] is Map
        ? (json['employee'] as Map)['_id'] ??
            (json['employee'] as Map)['id'] ??
            (json['employee'] as Map)['employeeId']
        : json['employee'];
    final resolvedStaffId = staffId ??
        rawEmployeeId?.toString() ??
        json['staffId']?.toString() ??
        '';

    DateTime? inAt;
    final rawCheckIn = json['checkIn'] ?? json['checkInAt'] ?? json['checkInTimestamp'];
    if (rawCheckIn != null && rawCheckIn.toString().isNotEmpty) {
      inAt = DateTime.tryParse(rawCheckIn.toString())?.toLocal();
    }

    DateTime? outAt;
    final rawCheckOut = json['checkOut'] ?? json['checkOutAt'] ?? json['checkOutTimestamp'];
    if (rawCheckOut != null && rawCheckOut.toString().isNotEmpty) {
      outAt = DateTime.tryParse(rawCheckOut.toString())?.toLocal();
    }

    String dateVal = '';
    if (json['date'] != null && json['date'].toString().isNotEmpty) {
      final parsedDate = DateTime.tryParse(json['date'].toString())?.toLocal();
      if (parsedDate != null) {
        dateVal = _formatIsoDate(parsedDate);
      } else {
        dateVal = json['date'].toString();
      }
    } else if (inAt != null) {
      dateVal = _formatIsoDate(inAt);
    } else {
      dateVal = _formatIsoDate(DateTime.now());
    }

    String inTime = '';
    if (json['checkInTime'] != null && json['checkInTime'].toString().isNotEmpty) {
      inTime = json['checkInTime'].toString();
    } else if (inAt != null) {
      inTime = _formatTimeOfDay(inAt);
    }

    String? outTime;
    if (json['checkOutTime'] != null && json['checkOutTime'].toString().isNotEmpty) {
      outTime = json['checkOutTime'].toString();
    } else if (outAt != null) {
      outTime = _formatTimeOfDay(outAt);
    }

    String worked = json['workedDuration']?.toString() ?? '';
    if (json['workingHours'] != null) {
      final wh = json['workingHours'] is num
          ? (json['workingHours'] as num).toDouble()
          : double.tryParse(json['workingHours'].toString()) ?? 0.0;
      if (wh > 0) {
        final totalMins = (wh * 60).round();
        worked = '${totalMins ~/ 60}h ${(totalMins % 60).toString().padLeft(2, '0')}m';
      }
    }

    final rawBreaks = json['breaks'];
    final List<AttendanceBreak> parsedBreaks = [];
    if (rawBreaks is List) {
      for (final b in rawBreaks) {
        if (b is Map) {
          final bm = Map<String, dynamic>.from(b);
          final bStart = DateTime.tryParse(bm['startTime']?.toString() ?? '') ?? DateTime.now();
          final bEnd = DateTime.tryParse(bm['endTime']?.toString() ?? '');
          parsedBreaks.add(AttendanceBreak(
            id: bm['id']?.toString() ?? bm['_id']?.toString() ?? '',
            attendanceId: bm['attendanceId']?.toString() ?? id,
            breakType: bm['breakType']?.toString() ?? 'lunch',
            startTime: bStart,
            endTime: bEnd,
            durationSeconds: (bm['durationSeconds'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }

    final rawBreakStartedAt = json['breakStartedAt'];
    DateTime? bStartedAt;
    if (rawBreakStartedAt != null && rawBreakStartedAt.toString().isNotEmpty) {
      bStartedAt = DateTime.tryParse(rawBreakStartedAt.toString())?.toLocal();
    }

    final rawSchedule = json['scheduleSnapshot'] ?? json['schedule'];
    final rawEmployee = json['employee'];
    final rawDepartment = json['department'] ??
        (rawEmployee is Map ? rawEmployee['department'] : null);
    final rawMinutesLate = json['minutesLate'];
    return Attendance(
      id: id,
      staffId: resolvedStaffId,
      date: dateVal,
      checkInTime: inTime,
      checkOutTime: outTime,
      workedDuration: worked,
      breakDuration: json['breakDuration']?.toString() ?? '',
      isLate: json['isLate'] == true || json['late'] == true ||
          (json['status']?.toString().toUpperCase() == 'LATE'),
      minutesLate: rawMinutesLate is num
          ? rawMinutesLate.toInt()
          : int.tryParse(rawMinutesLate?.toString() ?? ''),
      scheduleSnapshot: rawSchedule is Map
          ? Map<String, dynamic>.from(rawSchedule)
          : null,
      department: rawDepartment is Map
          ? (rawDepartment['name'] ?? rawDepartment['_id'])?.toString()
          : rawDepartment?.toString(),
      checkInAt: inAt,
      checkOutAt: outAt,
      breakStartedAt: bStartedAt,
      totalBreakSeconds: (json['totalBreakSeconds'] as num?)?.toInt() ?? 0,
      breaks: parsedBreaks,
      status: json['status']?.toString() ?? 'PRESENT',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'staffId': staffId,
    'date': date,
    'checkInTime': checkInTime,
    'checkOutTime': checkOutTime,
    'workedDuration': workedDuration,
    'breakDuration': breakDuration,
    'isLate': isLate,
    'minutesLate': minutesLate,
    'scheduleSnapshot': scheduleSnapshot,
    'department': department,
    'checkInAt': checkInAt?.toIso8601String(),
    'checkOutAt': checkOutAt?.toIso8601String(),
    'breakStartedAt': breakStartedAt?.toIso8601String(),
    'totalBreakSeconds': totalBreakSeconds,
    'status': status,
    'breaks': breaks.map((b) => {
      'id': b.id,
      'attendanceId': b.attendanceId,
      'breakType': b.breakType,
      'startTime': b.startTime.toIso8601String(),
      'endTime': b.endTime?.toIso8601String(),
      'durationSeconds': b.durationSeconds,
    }).toList(),
  };

  Attendance copyWith({
    String? id,
    String? staffId,
    String? date,
    String? checkInTime,
    String? checkOutTime,
    String? workedDuration,
    String? breakDuration,
    bool? isLate,
    int? minutesLate,
    Map<String, dynamic>? scheduleSnapshot,
    String? department,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    DateTime? breakStartedAt,
    bool clearBreakStartedAt = false,
    int? totalBreakSeconds,
    List<AttendanceBreak>? breaks,
    String? status,
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
      minutesLate: minutesLate ?? this.minutesLate,
      scheduleSnapshot: scheduleSnapshot ?? this.scheduleSnapshot,
      department: department ?? this.department,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      breakStartedAt:
          clearBreakStartedAt ? null : (breakStartedAt ?? this.breakStartedAt),
      totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
      breaks: breaks ?? this.breaks,
      status: status ?? this.status,
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
    this.documentId,
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
  final String? documentId;
  final String status;
  final DateTime createdAt;

  LeaveRequest copyWith({
    String? status,
    String? documentName,
    String? documentUrl,
    String? documentId,
  }) => LeaveRequest(
        id: id,
        staffId: staffId,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        type: type,
        documentName: documentName ?? this.documentName,
        documentUrl: documentUrl ?? this.documentUrl,
        documentId: documentId ?? this.documentId,
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
    this.title = '',
    this.updateText = '',
    this.createdAt,
  });

  final String id;
  final String staffId;
  final String date;
  final String title;
  final String updateText;
  final DateTime? createdAt;

  factory DailyUpdate.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final staffId = json['employee']?.toString() ??
        json['staffId']?.toString() ??
        '';
    final rawDate = json['date'] ?? json['createdAt'];
    String date = '';
    DateTime? createdAt;
    if (rawDate != null && rawDate.toString().isNotEmpty) {
      createdAt = DateTime.tryParse(rawDate.toString())?.toLocal();
      date = createdAt != null
          ? '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
          : rawDate.toString();
    }
    return DailyUpdate(
      id: id,
      staffId: staffId,
      date: date,
      title: json['title']?.toString() ?? '',
      updateText: json['updateText']?.toString() ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'staffId': staffId,
    'date': date,
    'title': title,
    'updateText': updateText,
    'createdAt': createdAt?.toIso8601String(),
  };

  DailyUpdate copyWith({
    String? id,
    String? staffId,
    String? date,
    String? title,
    String? updateText,
    DateTime? createdAt,
  }) {
    return DailyUpdate(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      title: title ?? this.title,
      updateText: updateText ?? this.updateText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
