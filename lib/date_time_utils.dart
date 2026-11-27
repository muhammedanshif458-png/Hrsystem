// ─── date_time_utils.dart ──────────────────────────────────────────────────────
// Converted from Kotlin object DateTimeUtils in com.example.util

import 'package:intl/intl.dart';

abstract class DateTimeUtils {
  static final _isoFmt = DateFormat('yyyy-MM-dd');
  static final _timeFmt = DateFormat('hh:mm a');
  static final _displayFmt = DateFormat('EEEE, d MMMM yyyy');
  static final _shortFmt = DateFormat('MMM d, yyyy');

  static String getTodayIsoDate() => _isoFmt.format(DateTime.now());

  static String getCurrentTime() => _timeFmt.format(DateTime.now());

  static String getTodayFormatted() => _displayFmt.format(DateTime.now());

  static String formatIsoToReadable(String isoDate) {
    try {
      final parsed = _isoFmt.parse(isoDate);
      return _shortFmt.format(parsed);
    } catch (_) {
      return isoDate;
    }
  }

  /// Returns true if [timeStr] (e.g. "09:42 AM") is after cutoff (default 09:30).
  static bool isTimeLate(
    String timeStr, {
    int cutoffHour = 9,
    int cutoffMinute = 30,
  }) {
    try {
      final parsed = _timeFmt.parse(timeStr);
      final hour = parsed.hour;
      final minute = parsed.minute;
      return hour > cutoffHour || (hour == cutoffHour && minute > cutoffMinute);
    } catch (_) {
      return false;
    }
  }

  /// Returns true if [dateStr] (ISO) falls within the last 30 days.
  static bool isWithinLast30Days(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    try {
      final parsed = _isoFmt.parse(dateStr);
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      return parsed.isAfter(thirtyDaysAgo) && parsed.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  /// Returns a time-based greeting based on current local time:
  /// - 12:00 AM – 11:59 AM (`hour < 12`): 'Good Morning'
  /// - 12:00 PM – 4:59 PM (`hour >= 12 && hour < 17`): 'Good Afternoon'
  /// - 5:00 PM – 11:59 PM (`hour >= 17`): 'Good Evening'
  static String getTimeBasedGreeting([DateTime? now]) =>
      getTimeBasedGreetingFunction(now);
}

/// Computes the time-based greeting for StaffHub:
/// - 12:00 AM – 11:59 AM (`hour < 12`): 'Good Morning'
/// - 12:00 PM – 4:59 PM (`hour >= 12 && hour < 17`): 'Good Afternoon'
/// - 5:00 PM – 11:59 PM (`hour >= 17`): 'Good Evening'
String getTimeBasedGreeting([DateTime? now]) {
  final current = now ?? DateTime.now();
  if (current.hour < 12) {
    return 'Good Morning';
  } else if (current.hour < 17) {
    return 'Good Afternoon';
  } else {
    return 'Good Evening';
  }
}

String getTimeBasedGreetingFunction([DateTime? now]) =>
    getTimeBasedGreeting(now);
