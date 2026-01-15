// =============================================================================
// date_utils.dart - 날짜 유틸리티 함수
// =============================================================================

class AppDateUtils {
  AppDateUtils._();

  /// 이전 월 계산
  static ({int year, int month}) getPreviousMonth(int year, int month) {
    if (month == 1) {
      return (year: year - 1, month: 12);
    }
    return (year: year, month: month - 1);
  }

  /// 다음 월 계산
  static ({int year, int month}) getNextMonth(int year, int month) {
    if (month == 12) {
      return (year: year + 1, month: 1);
    }
    return (year: year, month: month + 1);
  }

  /// N개월 전 날짜 목록 반환 (현재 월 포함, 오래된 순)
  static List<({int year, int month})> getMonthsBack(int year, int month, int count) {
    final result = <({int year, int month})>[];
    int y = year;
    int m = month;

    for (int i = 0; i < count; i++) {
      result.add((year: y, month: m));
      final prev = getPreviousMonth(y, m);
      y = prev.year;
      m = prev.month;
    }

    return result.reversed.toList();
  }

  /// 해당 월의 첫째 날
  static DateTime getFirstDayOfMonth(int year, int month) {
    return DateTime(year, month, 1);
  }

  /// 해당 월의 마지막 날
  static DateTime getLastDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0);
  }

  /// 같은 날인지 확인 (시간 무시)
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 같은 월인지 확인
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
