// =============================================================================
// format_utils.dart - 포맷 유틸리티 함수
// =============================================================================
import 'package:intl/intl.dart';

class FormatUtils {
  FormatUtils._();

  static final _numberFormat = NumberFormat('#,###', 'en_US');

  /// 숫자를 천 단위 구분자로 포맷
  static String formatNumber(int number) {
    return _numberFormat.format(number);
  }

  /// 금액을 축약 형태로 포맷 (만원 단위)
  static String formatAmountShort(int amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(1)}억';
    }
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(0)}만';
    }
    return _numberFormat.format(amount);
  }

  /// 퍼센트 포맷
  static String formatPercent(double percent, {int decimals = 1}) {
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(decimals)}%';
  }

  /// 날짜 포맷 (yyyy. M. d)
  static String formatDate(DateTime date) {
    return DateFormat('yyyy. M. d').format(date);
  }

  /// 월 포맷 (M월)
  static String formatMonth(int month) {
    return '$month월';
  }

  /// 연월 포맷 (yyyy. MM)
  static String formatYearMonth(int year, int month) {
    return '$year. $month';
  }
}
