// lib/theme.dart

import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceVariant = Color(0xFF0F172A);
  static const border = Color(0xFF334155);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF06B6D4);
  static const red = Color(0xFFEF4444);
  static const pink = Color(0xFFEC4899);
  static const purple = Color(0xFFA855F7);
  static const indigo = Color(0xFF6366F1);
  static const green = Color(0xFF10B981);
  static const emerald = Color(0xFF059669);
  static const yellow = Color(0xFFF59E0B);
  static const amber = Color(0xFFD97706);
  static const orange = Color(0xFFF97316);

  static const Map<String, List<Color>> alertGradients = {
    'SAFE': [Color(0xFF10B981), Color(0xFF059669)],
    'CAUTION': [Color(0xFFF59E0B), Color(0xFFD97706)],
    'WARNING': [Color(0xFFF97316), Color(0xFFEF4444)],
    'CRITICAL': [Color(0xFFDC2626), Color(0xFFE11D48)],
  };

  static const Map<String, Color> alertBorders = {
    'SAFE': Color(0xFF10B981),
    'CAUTION': Color(0xFFF59E0B),
    'WARNING': Color(0xFFF97316),
    'CRITICAL': Color(0xFFDC2626),
  };
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'monospace',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        surface: AppColors.surface,
      ),
    );
  }
}
