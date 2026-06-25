import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF051424);
  static const surfaceContainer = Color(0xFF122131);
  static const surfaceContainerLow = Color(0xFF0D1C2D);
  static const surfaceContainerHighest = Color(0xFF273647);
  static const onSurface = Color(0xFFD4E4FA);
  static const onSurfaceVariant = Color(0xFFBCC8D0);
  static const outline = Color(0xFF86929A);
  static const outlineVariant = Color(0xFF3D484F);
  static const primary = Color(0xFF89D9FF);
  static const primaryContainer = Color(0xFF00C1F9);
  static const onPrimaryFixed = Color(0xFF001F2A);
}

String formatCurrency(double value) {
  return 'S/ ${value.toStringAsFixed(2)}';
}

String maskDocument(String document) {
  final digits = document.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) {
    return '***$digits';
  }
  return '***${digits.substring(digits.length - 4)}';
}

String monthAbbreviation(DateTime date) {
  const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  return months[date.month - 1];
}
