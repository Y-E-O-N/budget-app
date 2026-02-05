// =============================================================================
// app_constants.dart - 앱 전역 상수
// =============================================================================

class AppConstants {
  AppConstants._();

  // API 설정
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://budget-log.duckdns.org',
  );
  static const Duration apiTimeout = Duration(seconds: 60);

  // 데이터 제한
  static const int maxAnalysisHistory = 20;
  static const int trendMonthsDefault = 6;
  static const int categoryComparisonMonths = 3;

  // UI 설정
  static const double chartHeight = 250.0;
  static const double pieChartRadius = 80.0;
  static const double pieChartRadiusTouched = 90.0;
  static const double pieChartCenterRadius = 30.0;

  // 페이지네이션
  static const int defaultPageSize = 20;

  // 애니메이션
  static const Duration animationDuration = Duration(milliseconds: 300);

  // 포맷
  static const String dateFormat = 'yyyy. M. d';
  static const String monthFormat = 'yyyy. MM';
}
