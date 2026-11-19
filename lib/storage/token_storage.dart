// ─── lib/storage/token_storage.dart ──────────────────────────────────────────
// Handles saving, loading, and clearing the auth token from SharedPreferences.
// The ApiService reads the token from here to attach it to requests.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'staffhub.auth.token';
  static const String _refreshTokenKey = 'staffhub.auth.refresh_token';
  static const String _workModeKey = 'staffhub.auth.work_mode';
  static const String _themeModeKey = 'staffhub.theme_mode';

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  static Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey);
  }

  static Future<void> saveWorkMode(String workMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workModeKey, workMode);
  }

  static Future<String?> getWorkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workModeKey);
  }

  // ── Hidden Leave Request IDs per staff member ─────────────────────────────
  static String _hiddenLeavesKey(String staffId) => 'staffhub.hidden_leaves.$staffId';

  static Future<Set<String>> getHiddenLeaveIds(String staffId) async {
    if (staffId.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_hiddenLeavesKey(staffId));
    return list?.toSet() ?? {};
  }

  static Future<void> addHiddenLeaveId(String staffId, String leaveId) async {
    if (staffId.isEmpty || leaveId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _hiddenLeavesKey(staffId);
    final set = (prefs.getStringList(key) ?? []).toSet();
    set.add(leaveId);
    await prefs.setStringList(key, set.toList());
  }

  static Future<void> removeHiddenLeaveId(String staffId, String leaveId) async {
    if (staffId.isEmpty || leaveId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _hiddenLeavesKey(staffId);
    final set = (prefs.getStringList(key) ?? []).toSet();
    set.remove(leaveId);
    await prefs.setStringList(key, set.toList());
  }

  // ── Save tokens ───────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  static Future<void> saveTokens({
    required String token,
    String? refreshToken,
  }) async {
    await saveToken(token);
    if (refreshToken != null) await saveRefreshToken(refreshToken);
  }

  // ── Read tokens ───────────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // ── Clear tokens (call on logout) ─────────────────────────────────────────
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_workModeKey);
  }

  // ── Quick check ───────────────────────────────────────────────────────────
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
