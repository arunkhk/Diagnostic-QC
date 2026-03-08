import 'package:flutter/material.dart';

/// Central palette for the application.
class AppColors {
  AppColors._();

  // Basic Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFE0E0E0);
  static const Color greyDark = Color(0xFF616161);
  
  // Standard Colors
  static const Color red = Color(0xFFF44336);
  static const Color green = Color(0xFF4CAF50);
  static const Color blue = Color(0xFF2196F3);
  static const Color yellow = Color(0xFFFFEB3B);
  static const Color pink = Color(0xFFE91E63);
  static const Color violet = Color(0xFF9C27B0);
  static const Color magenta = Color(0xFFFF00FF); // RGB(255, 0, 255) - Red + Blue

  // Primary Colors
  static const Color primary = Color(0xFF7B2CF5);
  static const Color primaryDark = Color(0xFF5A0FC8);
  static const Color primaryLight = Color(0xFFB79FED);
  static const Color accent = Color(0xFFB79FED);

  // Background & Surface
  static const Color background = Color(0xFFFDFBFF);
  static const Color surface = Color(0xFFF8F4FF);
  static const Color surfaceVariant = Color(0xFFEDE4FF);
  static const Color card = Color(0xFFFFFFFF);

  // Text Colors
  static const Color text = Color(0xFF1B1037);
  static const Color textSecondary = Color(0xFF6A6385);
  static const Color textTertiary = Color(0xFF9B94B0);
  static const Color textDisabled = Color(0xFFC4BED8);
  static const Color subtitle = Color(0xFF6A6385);

  // Border & Divider
  static const Color border = Color(0xFFE0D2FF);
  static const Color divider = Color(0xFFE8E0F5);
  static const Color outline = Color(0xFFD4C7F0);

  // Status Colors (for diagnosis results)
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF388E3C);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF1976D2);

  // Disabled States
  static const Color disabled = Color(0xFFC4BED8);
  static const Color disabledBackground = Color(0xFFF5F0FF);
  static const Color disabledText = Color(0xFF9B94B0);

  // Interactive States
  static const Color hover = Color(0xFFF0E8FF);
  static const Color pressed = Color(0xFFE0D2FF);
  static const Color focus = Color(0xFF7B2CF5);

  // Shadow Colors
  static const Color shadowLight = Color(0x145A0FC8);
  static const Color shadowMedium = Color(0x285A0FC8);
  static const Color shadowDark = Color(0x3D5A0FC8);

  // Sensor/Diagnosis Specific Colors
  static const Color sensorActive = Color(0xFF4CAF50);
  static const Color sensorInactive = Color(0xFF9E9E9E);
  static const Color sensorError = Color(0xFFE53935);
  static const Color sensorWarning = Color(0xFFFF9800);

  // Overlay & Modal
  static const Color overlay = Color(0x80000000);
  static const Color modalBackground = Color(0xFFFFFFFF);
  static const Color backdrop = Color(0x66000000);
}

