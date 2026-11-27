// ═════════════════════════════════════════════════════════════════════════════
//  API LIST — STAFF APP
//
//  BASE URL
//    Live (release build) : https://hrsystembackend-4xzs.onrender.com
//    Local (flutter run)  : http://127.0.0.1:5000
//    Override             : --dart-define=API_BASE_URL=...
//
//  Every backend API used by the Staff app, separated by category.
//  Full URL = ApiList.baseUrl + path   →   ApiList.url(AttendanceApis.checkIn)
//  `:id` style parameters are functions, e.g. LeaveApis.byId(id).
// ═════════════════════════════════════════════════════════════════════════════

import 'config/api_config.dart';

/// Base URL of the backend (live on Render in release builds).
class ApiList {
  ApiList._();

  /// e.g. https://hrsystembackend-4xzs.onrender.com
  static String get baseUrl => ApiConfig.socketUrl;

  /// e.g. https://hrsystembackend-4xzs.onrender.com/api
  static String get apiUrl => ApiConfig.baseUrl;

  /// Builds a full URL from a path in this file.
  static String url(String path) => '$baseUrl$path';

  /// Builds a full Uri, with optional query parameters.
  static Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse(url(path)).replace(queryParameters: query);
}

// ─── 1. AUTHENTICATION ───────────────────────────────────────────────────────
class AuthApis {
  AuthApis._();

  /// POST — staff login. Body: { email, password, workMode: OFFICE | WORK_FROM_HOME }
  static const String login = '/api/auth/login';
}

// ─── 2. PROFILE ──────────────────────────────────────────────────────────────
class ProfileApis {
  ProfileApis._();

  /// GET — my profile | PUT — update my profile
  static const String profile = '/api/staff/profile';

  /// GET — today's birthdays
  static const String birthdaysToday = '/api/birthdays/today';
}

// ─── 3. ATTENDANCE ───────────────────────────────────────────────────────────
class AttendanceApis {
  AttendanceApis._();

  /// POST — check in
  static const String checkIn = '/api/staff/attendance/check-in';

  /// POST — check out
  static const String checkOut = '/api/staff/attendance/check-out';

  /// POST — start break
  static String breakStart(String attendanceId) => '/api/staff/attendance/$attendanceId/breaks/start';

  /// POST — end break
  static String breakEnd(String attendanceId) => '/api/staff/attendance/$attendanceId/breaks/end';

  /// GET — my attendance history
  static const String attendance = '/api/staff/attendance';

  /// GET — attendance details
  static String byId(String attendanceId) => '/api/staff/attendance/$attendanceId';

  /// DELETE — clear my history (hidden for me only, kept in DB for HR)
  static const String clearHistory = '/api/staff/attendance/history';

  /// POST — clear my history (fallback)
  static const String clearHistoryPost = '/api/staff/attendance/clear-history';
}

// ─── 4. LEAVES ───────────────────────────────────────────────────────────────
class LeaveApis {
  LeaveApis._();

  /// GET — my leave requests | POST — apply leave (optional attachment, multipart)
  static const String leaves = '/api/staff/leaves';

  /// DELETE — cancel leave
  static String byId(String id) => '/api/staff/leaves/$id';

  /// GET — download leave / medical document
  static String documentDownload(String docId) => '/api/staff/documents/$docId/download';
}

// ─── 5. DAILY UPDATES ────────────────────────────────────────────────────────
class DailyUpdateApis {
  DailyUpdateApis._();

  /// GET — my daily updates | POST — submit daily update
  static const String dailyUpdates = '/api/staff/daily-updates';
}

// ─── 6. DEPARTMENT CHAT ──────────────────────────────────────────────────────
class ChatApis {
  ChatApis._();

  /// GET — department messages | POST — send message
  static String messages(String deptKey) => '/api/staff/departments/$deptKey/messages';

  /// GET — search messages
  static String search(String deptKey) => '/api/staff/departments/$deptKey/messages/search';

  /// POST — clear chat
  static String clear(String deptKey) => '/api/staff/departments/$deptKey/messages/clear';

  /// DELETE — delete for everyone
  static String message(String deptKey, String messageId) =>
      '/api/staff/departments/$deptKey/messages/$messageId';

  /// PATCH — delete for me
  static String deleteForMe(String deptKey, String messageId) =>
      '/api/staff/departments/$deptKey/messages/$messageId/delete-for-me';
}
