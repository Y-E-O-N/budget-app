// =============================================================================
// trend_provider.dart - 트렌드 분석 전용 Provider
// =============================================================================
// BudgetProvider에서 트렌드 관련 로직을 분리하여 관심사 분리 원칙 적용
// =============================================================================

import 'package:flutter/foundation.dart';
import '../models/trend_data.dart';
import '../utils/date_utils.dart';
import 'budget_provider.dart';

/// 트렌드 분석 Provider
/// BudgetProvider의 데이터를 기반으로 트렌드 분석 기능 제공
class TrendProvider extends ChangeNotifier {
  final BudgetProvider _budgetProvider;

  TrendProvider(this._budgetProvider) {
    // BudgetProvider 변경 시 자동 업데이트
    _budgetProvider.addListener(_onBudgetProviderChanged);
  }

  @override
  void dispose() {
    _budgetProvider.removeListener(_onBudgetProviderChanged);
    super.dispose();
  }

  void _onBudgetProviderChanged() {
    notifyListeners();
  }

  // ===========================================================================
  // 현재 월 데이터 접근 (BudgetProvider 위임)
  // ===========================================================================

  int get currentYear => _budgetProvider.currentYear;
  int get currentMonth => _budgetProvider.currentMonth;

  // ===========================================================================
  // 월별 트렌드 분석
  // ===========================================================================

  /// 특정 월의 총 지출 계산
  int getTotalExpenseForMonth(int year, int month) {
    return _budgetProvider.getTotalExpenseForMonth(year, month);
  }

  /// 특정 월의 총 예산 계산
  int getTotalBudgetForMonth(int year, int month) {
    return _budgetProvider.getTotalBudgetForMonth(year, month);
  }

  /// 최근 N개월 월별 지출/예산 데이터
  List<MonthlyTrendData> getMonthlyTrend(int months) {
    final monthList = AppDateUtils.getMonthsBack(currentYear, currentMonth, months);

    return monthList.map((m) => MonthlyTrendData(
      year: m.year,
      month: m.month,
      expense: getTotalExpenseForMonth(m.year, m.month),
      budget: getTotalBudgetForMonth(m.year, m.month),
    )).toList();
  }

  /// 예산별 최근 N개월 지출 데이터
  List<BudgetTrendData> getBudgetTrendByMonth(int months) {
    final budgets = _budgetProvider.currentBudgets;
    final monthList = AppDateUtils.getMonthsBack(currentYear, currentMonth, months);

    return budgets.map((budget) {
      final monthlyData = monthList.map((m) {
        // 해당 월에 같은 이름의 예산 찾기
        final matchingBudget = _budgetProvider.allBudgets.firstWhere(
          (b) => b.name == budget.name && b.year == m.year && b.month == m.month,
          orElse: () => budget.copyWith(id: '', amount: 0),
        );

        if (matchingBudget.id.isEmpty) return 0;

        // 해당 예산의 지출 합계
        return _budgetProvider.allExpenses
            .where((e) =>
                e.budgetId == matchingBudget.id &&
                e.date.year == m.year &&
                e.date.month == m.month)
            .fold(0, (sum, e) => sum + e.amount);
      }).toList();

      return BudgetTrendData(
        budgetName: budget.name,
        monthlyExpenses: monthlyData,
      );
    }).toList();
  }

  // ===========================================================================
  // 전월 대비 분석
  // ===========================================================================

  /// 전월 대비 증감률 (%)
  double getMonthOverMonthChange() {
    return getMonthOverMonthData().changePercent;
  }

  /// 전월 지출 금액
  int getPreviousMonthExpense() {
    final prev = AppDateUtils.getPreviousMonth(currentYear, currentMonth);
    return getTotalExpenseForMonth(prev.year, prev.month);
  }

  /// 전월 대비 변화 데이터
  MonthOverMonthData getMonthOverMonthData() {
    final currentExpense = getTotalExpenseForMonth(currentYear, currentMonth);
    final prev = AppDateUtils.getPreviousMonth(currentYear, currentMonth);
    final prevExpense = getTotalExpenseForMonth(prev.year, prev.month);

    double changePercent;
    if (prevExpense == 0) {
      changePercent = currentExpense > 0 ? 100.0 : 0.0;
    } else {
      changePercent = ((currentExpense - prevExpense) / prevExpense) * 100;
    }

    return MonthOverMonthData(
      currentExpense: currentExpense,
      previousExpense: prevExpense,
      changePercent: changePercent,
    );
  }

  // ===========================================================================
  // 추가 분석 메서드
  // ===========================================================================

  /// 예산 대비 지출률 계산
  double getBudgetUsageRate() {
    final totalBudget = _budgetProvider.totalBudget;
    if (totalBudget == 0) return 0;

    final totalExpense = _budgetProvider.currentExpenses
        .fold(0, (sum, e) => sum + e.amount);
    return (totalExpense / totalBudget) * 100;
  }

  /// 가장 많이 지출한 예산 카테고리
  String? getTopSpendingCategory() {
    final budgets = _budgetProvider.currentBudgets;
    if (budgets.isEmpty) return null;

    String? topCategory;
    int maxExpense = 0;

    for (final budget in budgets) {
      final expense = _budgetProvider.getTotalExpense(budget.id);
      if (expense > maxExpense) {
        maxExpense = expense;
        topCategory = budget.name;
      }
    }

    return topCategory;
  }

  /// 예산 초과 카테고리 목록
  List<String> getOverBudgetCategories() {
    final result = <String>[];
    final budgets = _budgetProvider.currentBudgets;

    for (final budget in budgets) {
      final expense = _budgetProvider.getTotalExpense(budget.id);
      if (expense > budget.amount) {
        result.add(budget.name);
      }
    }

    return result;
  }

  /// 월별 평균 지출 (최근 N개월)
  double getAverageMonthlyExpense(int months) {
    final trendData = getMonthlyTrend(months);
    if (trendData.isEmpty) return 0;

    final total = trendData.fold(0, (sum, d) => sum + d.expense);
    return total / trendData.length;
  }
}
