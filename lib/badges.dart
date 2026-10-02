// ─── badges.dart ───────────────────────────────────────────────────────────────
// Converted from Kotlin Badges.kt in com.example.ui.components

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'models.dart';

class DepartmentBadge extends StatelessWidget {
  const DepartmentBadge({super.key, required this.department});

  final String department;

  @override
  Widget build(BuildContext context) {
    final isTelecalling =
        department.toLowerCase() == Department.telecalling.toLowerCase();
    final bg     = isTelecalling ? AppColors.telecallingLightBg : AppColors.techLightBg;
    final border = isTelecalling ? AppColors.telecallingBorder   : AppColors.techBorder;
    final text   = isTelecalling ? AppColors.telecallingDark     : AppColors.techDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        isTelecalling ? 'Telecalling' : 'Tech',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: text,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final _BadgeStyle style = _resolveStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: style.text,
        ),
      ),
    );
  }

  static _BadgeStyle _resolveStyle(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _BadgeStyle(AppColors.statusGreenBg, AppColors.statusGreenBorder, AppColors.statusGreenText, 'Active');
      case 'on time':
        return _BadgeStyle(AppColors.statusGreenBg, AppColors.statusGreenBorder, AppColors.statusGreenText, 'On time');
      case 'late':
        return _BadgeStyle(AppColors.statusAmberBg, AppColors.statusAmberBorder, AppColors.statusAmberText, 'Late');
      case 'resigned':
        return _BadgeStyle(AppColors.statusGrayBg, AppColors.statusGrayBorder, AppColors.statusGrayText, 'Resigned');
      case 'on leave':
      case 'inactive':
        return _BadgeStyle(AppColors.statusGrayBg, AppColors.statusGrayBorder, AppColors.statusGrayText, 'On leave');
      case 'pending':
        return _BadgeStyle(const Color(0xFFFEF9C3), const Color(0xFFFEF08A), const Color(0xFF854D0E), 'Pending');
      case 'in progress':
        return _BadgeStyle(AppColors.brandBlueBg, AppColors.brandBlueBorder, const Color(0xFF1D4ED8), 'In progress');
      case 'done':
        return _BadgeStyle(AppColors.statusGreenBg, AppColors.statusGreenBorder, AppColors.statusGreenText, 'Done');
      default:
        return _BadgeStyle(AppColors.statusGrayBg, AppColors.statusGrayBorder, AppColors.statusGrayText, status);
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle(this.bg, this.border, this.text, this.label);
  final Color bg;
  final Color border;
  final Color text;
  final String label;
}
