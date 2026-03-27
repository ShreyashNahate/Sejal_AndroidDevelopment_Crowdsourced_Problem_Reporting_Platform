import 'package:flutter/material.dart';

/// Central color palette for SmartCity app
class AppColors {
  AppColors._();

  // Primary brand color - civic/government blue
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF0D47A1);

  // Accent - energetic orange for CTAs
  static const Color accent = Color(0xFFFF6F00);
  static const Color accentLight = Color(0xFFFFA000);

  // Status colors
  static const Color emergency = Color(0xFFD32F2F); // Red for emergencies
  static const Color success = Color(0xFF388E3C); // Green for resolved
  static const Color warning = Color(0xFFF57C00); // Orange for pending
  static const Color info = Color(0xFF0288D1); // Blue for info

  // Issue category colors
  static const Color garbage = Color(0xFF795548);
  static const Color water = Color(0xFF0288D1);
  static const Color road = Color(0xFF455A64);
  static const Color electricity = Color(0xFFF9A825);
  static const Color other = Color(0xFF9E9E9E);

  // Background & surface
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Map marker colors
  static const Color markerNormal = Color(0xFFD32F2F);
  static const Color markerEmergency = Color(0xFFFF1744);
  static const Color markerResolved = Color(0xFF388E3C);
}
