// =============================================================================
// trend_data.dart - 트렌드 분석용 데이터 클래스
// =============================================================================

/// 월별 지출/예산 데이터
class MonthlyTrendData {
  final int year;
  final int month;
  final int expense;
  final int budget;

  const MonthlyTrendData({
    required this.year,
    required this.month,
    required this.expense,
    required this.budget,
  });

  /// 예산 대비 지출 비율 (%)
  double get usageRate => budget > 0 ? (expense / budget * 100) : 0;

  /// 잔액
  int get remaining => budget - expense;
}

/// 예산별 월간 지출 데이터
class BudgetTrendData {
  final String budgetName;
  final List<int> monthlyExpenses;

  const BudgetTrendData({
    required this.budgetName,
    required this.monthlyExpenses,
  });

  /// 총 지출
  int get totalExpense => monthlyExpenses.fold(0, (sum, e) => sum + e);

  /// 평균 지출
  double get averageExpense =>
      monthlyExpenses.isEmpty ? 0 : totalExpense / monthlyExpenses.length;
}

/// 전월 대비 변화 데이터
class MonthOverMonthData {
  final int currentExpense;
  final int previousExpense;
  final double changePercent;

  const MonthOverMonthData({
    required this.currentExpense,
    required this.previousExpense,
    required this.changePercent,
  });

  /// 증가 여부
  bool get isIncrease => changePercent > 0;

  /// 감소 여부
  bool get isDecrease => changePercent < 0;

  /// 변화 없음 여부
  bool get isFlat => changePercent == 0;

  /// 변화 금액
  int get changeAmount => currentExpense - previousExpense;
}
