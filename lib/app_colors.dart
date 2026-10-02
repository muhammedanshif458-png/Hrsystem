// ─── app_colors.dart ───────────────────────────────────────────────────────────
// Converted from Kotlin Color.kt in com.example.ui.theme

import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Neutral SaaS Base ──────────────────────────────────────────────────────
  static const canvasBg       = Color(0xFFF9FAFB);
  static const surfaceWhite   = Color(0xFFFFFFFF);
  static const surfaceSubtle  = Color(0xFFF3F4F6);
  static const borderSubtle   = Color(0xFFE5E7EB);
  static const borderMedium   = Color(0xFFD1D5DB);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary     = Color(0xFF111827);
  static const textSecondary   = Color(0xFF4B5563);
  static const textMuted       = Color(0xFF6B7280);
  static const textPlaceholder = Color(0xFF9CA3AF);

  // ── Department: Telecalling (Pink / Magenta) ───────────────────────────────
  static const telecallingPrimary  = Color(0xFFD946EF);
  static const telecallingDark     = Color(0xFF86198F);
  static const telecallingLightBg  = Color(0xFFFDF4FF);
  static const telecallingBorder   = Color(0xFFF5D0FE);

  // ── Department: Tech (Teal / Aqua) ────────────────────────────────────────
  static const techPrimary  = Color(0xFF0D9488);
  static const techDark     = Color(0xFF115E59);
  static const techLightBg  = Color(0xFFF0FDFA);
  static const techBorder   = Color(0xFFCCFBF1);

  // ── Status: Green (on time / active) ──────────────────────────────────────
  static const statusGreen       = Color(0xFF16A34A);
  static const statusGreenBg     = Color(0xFFDCFCE7);
  static const statusGreenText   = Color(0xFF166534);
  static const statusGreenBorder = Color(0xFFBBF7D0);

  // ── Status: Amber (late) ──────────────────────────────────────────────────
  static const statusAmber       = Color(0xFFD97706);
  static const statusAmberBg     = Color(0xFFFEF3C7);
  static const statusAmberText   = Color(0xFF92400E);
  static const statusAmberBorder = Color(0xFFFDE68A);

  // ── Status: Gray (resigned / on leave / inactive) ─────────────────────────
  static const statusGray       = Color(0xFF6B7280);
  static const statusGrayBg     = Color(0xFFF3F4F6);
  static const statusGrayText   = Color(0xFF374151);
  static const statusGrayBorder = Color(0xFFE5E7EB);

  // ── Brand Accent ──────────────────────────────────────────────────────────
  static const brandSlate       = Color(0xFF1E293B);
  static const brandNavy        = Color(0xFF0F172A);
  static const brandBlue        = Color(0xFF2563EB);
  static const brandBlueBg      = Color(0xFFEFF6FF);
  static const brandBlueBorder  = Color(0xFFBFDBFE);
  static const errorRed         = Color(0xFFDC2626);
}
