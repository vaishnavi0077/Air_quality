// lib/constants/colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2E7D32); // Professional green
  static const Color primaryVariant = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF60AD5E);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF2196F3); // Professional blue
  static const Color secondaryVariant = Color(0xFF0D47A1);
  static const Color secondaryLight = Color(0xFF64B5F6);
  
  // Neutral & UI Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);
  
  // AQI-Specific Status Colors (Optional)
  static const Color aqiGood = Color(0xFF4CAF50);
  static const Color aqiModerate = Color(0xFFFFC107);
  static const Color aqiUnhealthy = Color(0xFFFF9800);
  static const Color aqiVeryUnhealthy = Color(0xFFF44336);
  static const Color aqiHazardous = Color(0xFF880E4F);
}