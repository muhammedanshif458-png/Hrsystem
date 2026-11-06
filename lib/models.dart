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
    this.schedule,
    this.shift,
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
  final Map<String, dynamic>? schedule;
  final String? shift;

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
    Map<String, dynamic>? schedule,
    String? shift,
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
      schedule: schedule ?? this.schedule,
      shift: shift ?? this.shift,
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
  static const List<String> types = ['tea_break_1', 'lunch', 'tea_break_2'];
  static const List<String> names = [
    'Tea Break 1',
    'Lunch Break',
    'Tea Break 2'
  ];
  static const List<int> durationsMinutes = [15, 30, 15];

  // Breaks may start at any time during an active shift.
  static bool canStart(DateTime now, int index) =>
      index >= 0 && index < types.length;

  static String nameForType(String type) {
    if (type == 'morning') return names[0];
    if (type == 'afternoon') return names[2];
    final index = types.indexOf(type);
    return index < 0 ? 'Break' : names[index];
  }

  static int durationMinutesFor(String breakType) {
    if (breakType == 'lunch') return 30;
    if (breakType == 'tea_break_1' || breakType == 'morning') return 15;
    if (breakType == 'tea_break_2' || breakType == 'afternoon') return 15;
    final index = types.indexOf(breakType);
    return index >= 0 ? durationsMinutes[index] : 15;
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
    this.durationMinutes,
    this.remarks = '',
    this.isActiveServer,
    this.isCompletedServer,
  });

  final String id;
  final String attendanceId;
  final String breakType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final int? durationMinutes;
  final String remarks;
  final bool? isActiveServer;
  final bool? isCompletedServer;
  bool get isActive => isActiveServer ?? (endTime == null);
  bool get isCompleted => isCompletedServer ?? (endTime != null);
  static int allowanceSecondsFor(String breakType) =>
      AttendanceBreakSchedule.durationMinutesFor(breakType) * 60;
  int get allowanceSeconds => allowanceSecondsFor(breakType);

  int durationAt(DateTime now) {
    if (endTime != null) return durationSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    return elapsed.clamp(0, 1 << 31);
  }

  int remainingSecondsAt(DateTime now) {
    if (endTime != null) return 0;
    final elapsed = now.difference(startTime).inSeconds;
    final remaining = allowanceSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  static String formatRemainingDuration(int seconds) {
    final clamped = seconds < 0 ? 0 : seconds;
    final hours = clamped ~/ 3600;
    final minutes = (clamped % 3600) ~/ 60;
    final secs = clamped % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String remainingTimeFormatted(DateTime now) =>
      formatRemainingDuration(remainingSecondsAt(now));

  String remainingTimeText(DateTime now) =>
      'Remaining time: ${remainingTimeFormatted(now)}';
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
    this.scheduledCheckIn,
    this.scheduledCheckOut,
    this.scheduleStatus,
    this.scheduleConfigured,
    this.workMode,
    this.sessionStatus,
    this.totalBreakMinutes,
    this.numberOfBreaks,
    this.gracePeriodMinutes,
    this.activeBreak,
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
  final String? scheduledCheckIn;
  final String? scheduledCheckOut;
  final String? scheduleStatus;
  final bool? scheduleConfigured;
  final String? workMode;
  final String? sessionStatus;
  final int? totalBreakMinutes;
  final int? numberOfBreaks;
  final int? gracePeriodMinutes;
  final Map<String, dynamic>? activeBreak;

  bool get isCompleted =>
      sessionStatus == 'COMPLETED' ||
      checkOutAt != null ||
      (checkOutTime != null &&
          checkOutTime!.isNotEmpty &&
          checkOutTime != 'Pending');

  bool get isOngoing =>
      !isCompleted &&
      (sessionStatus == 'IN_PROGRESS' ||
          checkInAt != null ||
          checkInTime.isNotEmpty);

  String get displayStatus {
    if (isLate || status.toUpperCase() == 'LATE') return 'Late';
    if (status.toUpperCase() == 'PRESENT') return 'Present';
    if (status.toUpperCase() == 'HALF_DAY') return 'Half Day';
    if (status.toUpperCase() == 'ABSENT') return 'Absent';
    return status.isNotEmpty ? status : 'Present';
  }

  String get sessionStatusLabel =>
      isOngoing ? 'In Progress' : (isCompleted ? 'Completed' : 'Pending');

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
    final rawCheckIn =
        json['checkIn'] ?? json['checkInAt'] ?? json['checkInTimestamp'];
    if (rawCheckIn != null && rawCheckIn.toString().isNotEmpty) {
      inAt = DateTime.tryParse(rawCheckIn.toString())?.toLocal();
    }

    DateTime? outAt;
    final rawCheckOut =
        json['checkOut'] ?? json['checkOutAt'] ?? json['checkOutTimestamp'];
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
    if (json['checkInTime'] != null &&
        json['checkInTime'].toString().isNotEmpty) {
      inTime = formatShiftTime(json['checkInTime'].toString());
    } else if (inAt != null) {
      inTime = _formatTimeOfDay(inAt);
    }

    String? outTime;
    if (json['checkOutTime'] != null &&
        json['checkOutTime'].toString().isNotEmpty) {
      final rawOut = json['checkOutTime'].toString();
      if (rawOut.toLowerCase() == 'pending') {
        outTime = 'Pending';
      } else {
        outTime = formatShiftTime(rawOut);
      }
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
        worked =
            '${totalMins ~/ 60}h ${(totalMins % 60).toString().padLeft(2, '0')}m';
      }
    }

    final rawBreaks = json['breaks'];
    final List<AttendanceBreak> parsedBreaks = [];
    if (rawBreaks is List) {
      for (final b in rawBreaks) {
        if (b is Map) {
          final bm = Map<String, dynamic>.from(b);
          final bStart =
              DateTime.tryParse(bm['startTime']?.toString() ?? '')?.toLocal() ??
                  DateTime.now();
          final bEnd =
              DateTime.tryParse(bm['endTime']?.toString() ?? '')?.toLocal();
          final bMinutes = bm['durationMinutes'] is num
              ? (bm['durationMinutes'] as num).toInt()
              : int.tryParse(bm['durationMinutes']?.toString() ?? '');
          parsedBreaks.add(AttendanceBreak(
            id: bm['id']?.toString() ?? bm['_id']?.toString() ?? '',
            attendanceId: bm['attendanceId']?.toString() ?? id,
            breakType: bm['breakType']?.toString() ?? bm['type']?.toString() ?? 'lunch',
            startTime: bStart,
            endTime: bEnd,
            durationSeconds: bm['durationSeconds'] is num
                ? (bm['durationSeconds'] as num).toInt()
                : (bEnd == null
                    ? 0
                    : bEnd.difference(bStart).inSeconds.clamp(0, 1 << 31)),
            durationMinutes: bMinutes,
            remarks: bm['remarks']?.toString() ?? '',
            isActiveServer: bm['isActive'] as bool?,
            isCompletedServer: bm['isCompleted'] as bool?,
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
    final rawScheduledCheckIn = json['scheduledCheckIn']?.toString();
    final rawScheduledCheckOut = json['scheduledCheckOut']?.toString();
    final rawScheduleStatus = json['scheduleStatus']?.toString();
    final rawScheduleConfigured = json['scheduleConfigured'] as bool?;

    Map<String, dynamic>? resolvedScheduleSnapshot;
    if (rawSchedule is Map) {
      resolvedScheduleSnapshot = Map<String, dynamic>.from(rawSchedule);
    } else if (rawScheduledCheckIn != null || rawScheduledCheckOut != null) {
      resolvedScheduleSnapshot = {
        if (rawScheduledCheckIn != null)
          'scheduledCheckIn': rawScheduledCheckIn,
        if (rawScheduledCheckOut != null)
          'scheduledCheckOut': rawScheduledCheckOut,
        if (json['scheduleTimeZone'] != null)
          'timezone': json['scheduleTimeZone'],
        if (json['timezone'] != null) 'timezone': json['timezone'],
        if (json['gracePeriodMinutes'] != null)
          'gracePeriodMinutes': json['gracePeriodMinutes'],
      };
    }

    final rawEmployee = json['employee'];
    final rawDepartment = json['department'] ??
        (rawEmployee is Map ? rawEmployee['department'] : null);
    final rawMinutesLate = json['minutesLate'];
    final rawWorkMode = json['workMode']?.toString();
    final rawSessionStatus = json['sessionStatus']?.toString();
    final rawTotalBreakMins = json['totalBreakMinutes'] is num
        ? (json['totalBreakMinutes'] as num).toInt()
        : int.tryParse(json['totalBreakMinutes']?.toString() ?? '');
    final rawNumBreaks = json['numberOfBreaks'] is num
        ? (json['numberOfBreaks'] as num).toInt()
        : int.tryParse(json['numberOfBreaks']?.toString() ?? '');
    final rawGrace = json['gracePeriodMinutes'] is num
        ? (json['gracePeriodMinutes'] as num).toInt()
        : int.tryParse(json['gracePeriodMinutes']?.toString() ?? '');
    final rawActiveBreak = json['activeBreak'] is Map
        ? Map<String, dynamic>.from(json['activeBreak'] as Map)
        : null;

    return Attendance(
      id: id,
      staffId: resolvedStaffId,
      date: dateVal,
      checkInTime: inTime,
      checkOutTime: outTime,
      workedDuration: worked,
      breakDuration: json['breakDuration']?.toString() ?? '',
      isLate: json['isLate'] == true ||
          json['late'] == true ||
          (json['status']?.toString().toUpperCase() == 'LATE'),
      minutesLate: rawMinutesLate is num
          ? rawMinutesLate.toInt()
          : int.tryParse(rawMinutesLate?.toString() ?? ''),
      scheduleSnapshot: resolvedScheduleSnapshot,
      department: rawDepartment is Map
          ? (rawDepartment['name'] ?? rawDepartment['_id'])?.toString()
          : rawDepartment?.toString(),
      checkInAt: inAt,
      checkOutAt: outAt,
      breakStartedAt: bStartedAt,
      totalBreakSeconds: (json['totalBreakSeconds'] as num?)?.toInt() ?? 0,
      breaks: parsedBreaks,
      status: json['status']?.toString() ?? 'PRESENT',
      scheduledCheckIn: rawScheduledCheckIn ??
          resolvedScheduleSnapshot?['scheduledCheckIn']?.toString() ??
          resolvedScheduleSnapshot?['checkInTime']?.toString(),
      scheduledCheckOut: rawScheduledCheckOut ??
          resolvedScheduleSnapshot?['scheduledCheckOut']?.toString() ??
          resolvedScheduleSnapshot?['checkOutTime']?.toString(),
      scheduleStatus: rawScheduleStatus ??
          resolvedScheduleSnapshot?['scheduleStatus']?.toString(),
      scheduleConfigured: rawScheduleConfigured ??
          (resolvedScheduleSnapshot?['scheduleConfigured'] as bool?),
      workMode: rawWorkMode,
      sessionStatus: rawSessionStatus,
      totalBreakMinutes: rawTotalBreakMins,
      numberOfBreaks: rawNumBreaks,
      gracePeriodMinutes: rawGrace,
      activeBreak: rawActiveBreak,
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
        if (scheduledCheckIn != null) 'scheduledCheckIn': scheduledCheckIn,
        if (scheduledCheckOut != null) 'scheduledCheckOut': scheduledCheckOut,
        if (scheduleStatus != null) 'scheduleStatus': scheduleStatus,
        if (scheduleConfigured != null)
          'scheduleConfigured': scheduleConfigured,
        if (workMode != null) 'workMode': workMode,
        if (sessionStatus != null) 'sessionStatus': sessionStatus,
        if (totalBreakMinutes != null) 'totalBreakMinutes': totalBreakMinutes,
        if (numberOfBreaks != null) 'numberOfBreaks': numberOfBreaks,
        if (gracePeriodMinutes != null)
          'gracePeriodMinutes': gracePeriodMinutes,
        if (activeBreak != null) 'activeBreak': activeBreak,
        'breaks': breaks
            .map((b) => {
                  'id': b.id,
                  'attendanceId': b.attendanceId,
                  'breakType': b.breakType,
                  'startTime': b.startTime.toIso8601String(),
                  'endTime': b.endTime?.toIso8601String(),
                  'durationSeconds': b.durationSeconds,
                  if (b.durationMinutes != null)
                    'durationMinutes': b.durationMinutes,
                  if (b.remarks.isNotEmpty) 'remarks': b.remarks,
                })
            .toList(),
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
    String? scheduledCheckIn,
    String? scheduledCheckOut,
    String? scheduleStatus,
    bool? scheduleConfigured,
    String? workMode,
    String? sessionStatus,
    int? totalBreakMinutes,
    int? numberOfBreaks,
    int? gracePeriodMinutes,
    Map<String, dynamic>? activeBreak,
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
      scheduledCheckIn: scheduledCheckIn ?? this.scheduledCheckIn,
      scheduledCheckOut: scheduledCheckOut ?? this.scheduledCheckOut,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
      scheduleConfigured: scheduleConfigured ?? this.scheduleConfigured,
      workMode: workMode ?? this.workMode,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      totalBreakMinutes: totalBreakMinutes ?? this.totalBreakMinutes,
      numberOfBreaks: numberOfBreaks ?? this.numberOfBreaks,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      activeBreak: activeBreak ?? this.activeBreak,
    );
  }
}

/// Formats a 24-hour time string (e.g. '10:00', '18:00', '09:00', '9:00 AM') or ISO timestamp (e.g. '2026-11-06T05:24:39.985Z') into standard 12-hour format with leading zero ('10:00 AM', '06:00 PM', '09:00 AM').
String formatShiftTime(String timeStr) {
  final trimmed = timeStr.trim();
  if (trimmed.isEmpty) return '';

  // Handle ISO 8601 or date-time strings (e.g. 2026-11-06T05:24:39.985Z or 2026-11-06 05:24:39)
  if (trimmed.contains('T') || (trimmed.contains('-') && trimmed.contains(':'))) {
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final local = parsed.toLocal();
      final h = local.hour;
      final m = local.minute;
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    }
  }

  final upper = trimmed.toUpperCase();
  if (upper.contains('AM') || upper.contains('PM')) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(trimmed);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!;
      final period = match.group(3)!.toUpperCase();
      return '$h:$m $period';
    }
    return trimmed;
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(trimmed);
  if (match != null) {
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
  return trimmed;
}

/// Formats start and end times into a shift range: '10:00 AM – 06:00 PM'.
String formatShiftRange(String start, String end) {
  final s = formatShiftTime(start);
  final e = formatShiftTime(end);
  if (s.isEmpty && e.isEmpty) return 'Not Scheduled';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s \u2013 $e';
}

/// Normalizes any existing shift string (handling '-' or '–' separators and casing).
String normalizeShiftRange(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty ||
      trimmed.toLowerCase() == 'not scheduled' ||
      trimmed.toLowerCase() == 'unconfigured') {
    return 'Not Scheduled';
  }
  const separators = ['\u2013', '\u2014', '-'];
  for (final sep in separators) {
    if (trimmed.contains(sep)) {
      final parts = trimmed.split(sep);
      if (parts.length == 2) {
        final start = parts[0].trim();
        final end = parts[1].trim();
        if (start.isNotEmpty && end.isNotEmpty) {
          return formatShiftRange(start, end);
        }
      }
    }
  }
  return trimmed;
}

/// Extracts a formatted shift range from a schedule map.
String? extractShiftFromMap(Map<String, dynamic> map) {
  if (map['scheduleStatus']?.toString().toUpperCase() == 'UNCONFIGURED' ||
      map['scheduleConfigured'] == false ||
      map['configured'] == false) {
    return 'Not Scheduled';
  }
  if (map['shift'] != null && map['shift'].toString().trim().isNotEmpty) {
    return normalizeShiftRange(map['shift'].toString().trim());
  }
  if (map['shiftHours'] != null &&
      map['shiftHours'].toString().trim().isNotEmpty) {
    return normalizeShiftRange(map['shiftHours'].toString().trim());
  }
  final checkIn = (map['scheduledCheckIn'] ??
          map['checkInTime'] ??
          map['startTime'] ??
          map['checkIn'])
      ?.toString()
      .trim();
  final checkOut = (map['scheduledCheckOut'] ??
          map['checkOutTime'] ??
          map['endTime'] ??
          map['checkOut'])
      ?.toString()
      .trim();
  if (checkIn != null && checkIn.isNotEmpty) {
    return formatShiftRange(
        checkIn, checkOut?.isNotEmpty == true ? checkOut! : '18:00');
  }
  return null;
}

/// Resolves the effective shift for an authenticated staff member.
/// Priority:
/// 1. Unconfigured attendance flag -> 'Not Scheduled'
/// 2. Employee-specific schedule override on [staff] (never inferred from department)
/// 3. Backend attendance schedule snapshot or fields
/// 4. Authenticated employee's department configured schedule:
///    - Tech: '10:00 AM – 06:00 PM'
///    - Telecalling: '09:00 AM – 06:00 PM'
/// 5. Missing / unconfigured schedule -> 'Not Scheduled'
String resolveEffectiveShift({
  Staff? staff,
  Attendance? attendance,
  String? department,
}) {
  // 1. Check if backend attendance explicitly reports schedule as unconfigured
  if (attendance != null) {
    if (attendance.scheduleConfigured == false ||
        attendance.scheduleStatus?.toUpperCase() == 'UNCONFIGURED') {
      return 'Not Scheduled';
    }
  }

  // 2. Employee-specific schedule override on Staff
  if (staff != null) {
    if (staff.shift != null && staff.shift!.trim().isNotEmpty) {
      return normalizeShiftRange(staff.shift!.trim());
    }
    if (staff.schedule != null) {
      final s = extractShiftFromMap(staff.schedule!);
      if (s != null) return s;
    }
  }

  // 3. Attendance schedule snapshot or fields from backend
  if (attendance != null) {
    if (attendance.scheduleSnapshot != null) {
      final s = extractShiftFromMap(attendance.scheduleSnapshot!);
      if (s != null) return s;
    }
    if (attendance.scheduledCheckIn != null &&
        attendance.scheduledCheckIn!.trim().isNotEmpty) {
      final inTime = attendance.scheduledCheckIn!.trim();
      final outTime = attendance.scheduledCheckOut?.trim().isNotEmpty == true
          ? attendance.scheduledCheckOut!.trim()
          : '18:00';
      return formatShiftRange(inTime, outTime);
    }
  }

  // 4. Authenticated employee's actual department schedule
  final effectiveDept = (staff?.department.trim().isNotEmpty == true
          ? staff!.department
          : (attendance?.department?.trim().isNotEmpty == true
              ? attendance!.department!
              : (department ?? '')))
      .trim();

  final deptLower = effectiveDept.toLowerCase();
  if (deptLower == 'tech') {
    return '10:00 AM \u2013 06:00 PM';
  } else if (deptLower == 'telecalling') {
    return '09:00 AM \u2013 06:00 PM';
  }

  // 5. If schedule is missing / unconfigured
  return 'Not Scheduled';
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
  const LocationCapture({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.address,
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
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
  }) =>
      LeaveRequest(
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
    final staffId =
        json['employee']?.toString() ?? json['staffId']?.toString() ?? '';
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

/// Normalizes department key to canonical identifier ('tech', 'telecalling', 'hr', etc.)
/// matching the backend ChatService normalizeDeptKey logic.
String canonicalDepartmentKey(String? dept) {
  if (dept == null || dept.trim().isEmpty) return 'tech';
  final key = dept.trim().toLowerCase();
  if (key.contains('tech') || key.contains('engineer')) return 'tech';
  if (key.contains('tele') || key.contains('call') || key.contains('client'))
    return 'telecalling';
  if (key.contains('human') || key == 'hr') return 'hr';
  return key
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
}

/// Canonical Chat message representation for department chat, matching
/// backend DepartmentChatMessage model and HR-dashboard schema.
class StaffChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String? senderUser;
  final String? senderEmployee;
  final String departmentKey;
  final String? clientMessageId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool deletedForEveryone;
  final Set<String> deletedByIds;

  StaffChatMessage({
    required this.id,
    required this.senderId,
    this.senderName = '',
    this.senderRole = 'STAFF',
    this.senderUser,
    this.senderEmployee,
    this.departmentKey = '',
    this.clientMessageId,
    this.receiverId = '',
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.deletedForEveryone = false,
    Set<String>? deletedByIds,
  }) : deletedByIds = deletedByIds ?? const {};

  /// Whether the message sender is an HR or Admin role
  bool get isHR {
    final role = senderRole.toUpperCase();
    return role == 'HR' ||
        role == 'SUPER_ADMIN' ||
        role == 'ADMIN' ||
        role == 'HR MANAGER';
  }

  /// Whether this message was authored by the current logged-in [user]
  bool isSentBy(Staff? user) {
    if (user == null) return false;
    if (senderId.isNotEmpty && senderId == user.id) return true;
    if (senderEmployee != null && senderEmployee == user.id) return true;
    if (senderUser != null && senderUser == user.id) return true;
    if (!isHR &&
        user.name.isNotEmpty &&
        senderName.trim().toLowerCase() == user.name.trim().toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Checks if message is deleted for everyone or specifically for [userId]
  bool isHiddenFor(String? userId) {
    if (deletedForEveryone) return true;
    if (userId != null && deletedByIds.contains(userId)) return true;
    return false;
  }

  /// 2-letter avatar initials
  String get initials {
    if (senderName.trim().isEmpty) return isHR ? 'HR' : 'ST';
    final parts = senderName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
  }

  /// Formatted time string (e.g. 09:12 AM)
  String get formattedTime {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final standardHour = hour % 12 == 0 ? 12 : hour % 12;
    final hourStr = standardHour.toString().padLeft(2, '0');
    return '$hourStr:$minute $period';
  }

  StaffChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderUser,
    String? senderEmployee,
    String? departmentKey,
    String? clientMessageId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    bool? deletedForEveryone,
    Set<String>? deletedByIds,
  }) {
    return StaffChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderUser: senderUser ?? this.senderUser,
      senderEmployee: senderEmployee ?? this.senderEmployee,
      departmentKey: departmentKey ?? this.departmentKey,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedByIds: deletedByIds ?? this.deletedByIds,
    );
  }

  factory StaffChatMessage.fromJson(Map<String, dynamic> json) {
    Set<String> deletedBy = {};
    final rawDeleted = json['deletedByIds'];
    if (rawDeleted is List) {
      deletedBy = rawDeleted.map((e) => e.toString()).toSet();
    }

    DateTime parsedTime;
    if (json['timestamp'] != null) {
      parsedTime =
          DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      parsedTime =
          DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return StaffChatMessage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'STAFF',
      senderUser: json['senderUser']?.toString(),
      senderEmployee: json['senderEmployee']?.toString(),
      departmentKey: json['departmentKey']?.toString() ?? '',
      clientMessageId: json['clientMessageId']?.toString(),
      receiverId: json['receiverId']?.toString() ?? '',
      text: json['text']?.toString() ?? json['message']?.toString() ?? '',
      timestamp: parsedTime,
      isRead: json['isRead'] == true,
      deletedForEveryone: json['deletedForEveryone'] == true,
      deletedByIds: deletedBy,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        if (senderUser != null) 'senderUser': senderUser,
        if (senderEmployee != null) 'senderEmployee': senderEmployee,
        'departmentKey': departmentKey,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        'receiverId': receiverId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'deletedForEveryone': deletedForEveryone,
        'deletedByIds': deletedByIds.toList(),
      };
}
