// =============================================================================
// app_colors.dart - 앱 전역 색상 상수
// =============================================================================
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 차트 색상 팔레트 (12색)
  static const List<Color> chartPalette = [
    Color(0xFF6366F1),  // Indigo
    Color(0xFF22C55E),  // Green
    Color(0xFFF59E0B),  // Amber
    Color(0xFFEF4444),  // Red
    Color(0xFF8B5CF6),  // Purple
    Color(0xFF06B6D4),  // Cyan
    Color(0xFFEC4899),  // Pink
    Color(0xFF14B8A6),  // Teal
    Color(0xFFF97316),  // Orange
    Color(0xFF3B82F6),  // Blue
    Color(0xFF84CC16),  // Lime
    Color(0xFFD946EF),  // Fuchsia
  ];

  // 인덱스에 따른 차트 색상 반환 (순환)
  static Color getChartColor(int index) {
    return chartPalette[index % chartPalette.length];
  }

  // 트렌드 색상
  static const Color trendUp = Color(0xFFEF4444);      // 빨강 (증가)
  static const Color trendDown = Color(0xFF22C55E);   // 초록 (감소)
  static const Color trendFlat = Color(0xFF6B7280);   // 회색 (유지)

  // 상태 색상
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
