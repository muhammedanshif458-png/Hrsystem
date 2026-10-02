// ─── cards.dart ────────────────────────────────────────────────────────────────
// Converted from Kotlin Cards.kt in com.example.ui.components

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// General-purpose card matching Kotlin's SaaSCard composable.
class SaaSCard extends StatelessWidget {
  const SaaSCard({
    super.key,
    required this.child,
    this.borderColor = AppColors.borderSubtle,
    this.backgroundColor = AppColors.surfaceWhite,
  });

  final Widget child;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// Stat metric card matching Kotlin's SaaSStatCard composable.
class SaaSStatCard extends StatelessWidget {
  const SaaSStatCard({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.subtitle,
    this.icon,
    this.iconTint = AppColors.brandSlate,
    this.accentColor,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final String? subtitle;
  final IconData? icon;
  final Color iconTint;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accentColor ?? AppColors.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
