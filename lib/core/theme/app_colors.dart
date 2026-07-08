import 'package:flutter/material.dart';

abstract final class AppColors {
  // Core brand — deep navy with a refined gold accent.
  static const primary = Color(0xFF14303D);
  static const primaryLight = Color(0xFF2C5364);
  static const primaryDark = Color(0xFF0C202A);
  static const accent = Color(0xFFC9A227);
  static const accentSoft = Color(0xFFF6EAC2);

  // Surfaces — cool, premium neutrals.
  static const surface = Color(0xFFF3F5F8);
  static const card = Colors.white;
  static const border = Color(0xFFE3E7EC);

  // Text.
  static const textPrimary = Color(0xFF141B22);
  static const textSecondary = Color(0xFF64727E);
  static const textMuted = Color(0xFF94A0AB);

  // Semantic.
  static const success = Color(0xFF0F766E);
  static const successSoft = Color(0xFFD8F1EC);
  static const error = Color(0xFFB3261E);
  static const errorSoft = Color(0xFFF9E0DE);
  static const warning = Color(0xFF9A6A15);
  static const info = Color(0xFF1E4E8C);

  // Restrained, desaturated palette for module tiles — corporate, not rainbow.
  static const dashboardTiles = [
    Color(0xFF1B3A4B), // navy
    Color(0xFF2E6E65), // muted teal
    Color(0xFF4A6572), // slate
    Color(0xFF9A6A15), // bronze/gold
    Color(0xFF7C4A3F), // muted terracotta
    Color(0xFF34567A), // steel blue
  ];
}
