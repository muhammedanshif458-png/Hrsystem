// ─── lib/storage/token_storage.dart ──────────────────────────────────────────
// Handles saving, loading, and clearing the auth token from SharedPreferences.
// The ApiService reads the token from here to attach it to requests.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey        = 'staffhub.auth.token';
  static const String _refreshTokenKey = 'staffhub.auth.refresh_token';

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
  }

  // ── Quick check ───────────────────────────────────────────────────────────
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
