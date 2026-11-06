// ─── lib/config/api_config.dart ───────────────────────────────────────────────
// Central configuration for all backend API settings.
// Configured to point to the local HR system backend (default: http://127.0.0.1:5000/api).
// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  // ── BASE URL ──────────────────────────────────────────────────────────────
  static const String _defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000/api',
  );

  static String? _overrideUrl;

  /// Override the API base URL dynamically (e.g. for testing or staging)
  static void setBaseUrl(String? url) {
    _overrideUrl = url != null ? normalizeBaseUrl(url) : null;
  }

  /// Reset the API base URL back to default
  static void resetBaseUrl() {
    _overrideUrl = null;
  }

  /// Get the active API base URL
  static String get baseUrl => _overrideUrl ?? normalizeBaseUrl(_defaultUrl);

  /// Get the active Socket.IO server URL (derived by stripping /api from baseUrl)
  static String get socketUrl {
    final base = baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  /// Normalizes base URL: strips trailing slashes, ensures /api suffix
  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return 'http://127.0.0.1:5000/api';
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.endsWith('/api')) {
      trimmed = '$trimmed/api';
    }
    return trimmed;
  }

  // ── TIMEOUTS ──────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── DEFAULT HEADERS ───────────────────────────────────────────────────────
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── AUTH ENDPOINTS ────────────────────────────────────────────────────────
  static const String login          = '/auth/login';
  static const String logout         = '/auth/logout';
  static const String refreshToken   = '/auth/refresh-token';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword  = '/auth/reset-password';

  // ── STAFF ENDPOINTS ───────────────────────────────────────────────────────
  static const String staffDashboard = '/staff/dashboard';
  static const String staffProfile   = '/staff/profile';

  // ── ATTENDANCE ENDPOINTS ──────────────────────────────────────────────────
  static const String attendanceCheckIn  = '/staff/attendance/check-in';
  static const String attendanceCheckOut = '/staff/attendance/check-out';
  static const String attendance         = '/staff/attendance';
  static String attendanceDetail(String attendanceId) =>
      '/staff/attendance/$attendanceId';
  static const String attendanceClearHistory = '/staff/attendance/history';
  static const String attendanceClearHistoryPost = '/staff/attendance/clear-history';
  static String attendanceBreakStart(String attendanceId) =>
      '/staff/attendance/$attendanceId/breaks/start';
  static String attendanceBreakEnd(String attendanceId) =>
      '/staff/attendance/$attendanceId/breaks/end';

  // ── LEAVE ENDPOINTS ───────────────────────────────────────────────────────
  static const String leaves = '/staff/leaves';

  // Helper for dynamic routes like /staff/leaves/:id
  static String leaveById(String id) => '/staff/leaves/$id';

  // ── STAFF DOCUMENT ENDPOINTS ──────────────────────────────────────────────
  static const String staffDocuments = '/staff/documents';
  static String staffDocumentById(String id) => '/staff/documents/$id';
  static String staffDocumentDownload(String id) => '/staff/documents/$id/download';

  // ── DAILY UPDATE ENDPOINTS ────────────────────────────────────────────────
  static const String dailyUpdates = '/staff/daily-updates';

  // ── CHAT ENDPOINTS ────────────────────────────────────────────────────────
  static const String staffChatMessages = '/staff/chat/messages';
  static String staffDepartmentMessages(String deptKey) => '/staff/departments/$deptKey/messages';
  static String staffChatMessageDelete(String messageId) => '/staff/chat/messages/$messageId';
  static String staffChatMessageDeleteForMe(String messageId) => '/staff/chat/messages/$messageId/delete-for-me';
}

