// =============================================================================
// markdown_export_service.dart - 마크다운 형식 데이터 변환 서비스
// =============================================================================
import 'package:intl/intl.dart';
import '../app_localizations.dart';
import '../models/budget.dart';
import '../models/sub_budget.dart';
import '../models/expense.dart';

class MarkdownExportService {
  final String language;
  final String currency;
  final NumberFormat _numberFormat;

  MarkdownExportService({required this.language, required this.currency})
    : _numberFormat = NumberFormat('#,###', AppLocalizations.localeFor(language));

  // 통화 포맷
  String _formatAmount(int amount) {
    final formatted = _numberFormat.format(amount);
    if (currency == '₩') return '$formatted원';
    if (currency == '¥') return '$formatted$currency';
    return '$currency$formatted';
  }

  // 퍼센트 계산
  String _calcPercent(int used, int total) {
    if (total == 0) return '0%';
    return '${(used / total * 100).toStringAsFixed(1)}%';
  }

  // 마크다운 생성
  String generateMarkdown({
    required List<Budget> budgets,
    required List<SubBudget> subBudgets,
    required List<Expense> expenses,
    required DateTime startDate,
    required DateTime endDate,
    required int Function(String budgetId) getTotalExpense,
    required int Function(String subBudgetId) getSubBudgetExpense,
  }) {
    final sb = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // 헤더
    sb.writeln('## ${_getTitle()} (${dateFormat.format(startDate)} ~ ${dateFormat.format(endDate)})');
    sb.writeln();

    // 예산 요약 테이블
    sb.writeln('### ${_getBudgetSummaryTitle()}');
    sb.writeln('| ${_col('budgetName')} | ${_col('type')} | ${_col('budget')} | ${_col('used')} | ${_col('remaining')} | ${_col('usageRate')} |');
    sb.writeln('|------|------|------|------|------|--------|');

    int totalBudget = 0;
    int totalExpense = 0;

    for (var budget in budgets) {
      final expense = getTotalExpense(budget.id);
      final remaining = budget.amount - expense;
      totalBudget += budget.amount;
      totalExpense += expense;

      // #28: 정기지출 여부 표시 - isRecurring이거나 이름에 '정기', '고정', 'fixed', 'recurring' 포함
      final isFixed = budget.isRecurring || _isFixedExpenseBudget(budget.name);
      final typeLabel = isFixed ? _col('fixedExpense') : _col('variableExpense');

      sb.writeln('| ${budget.name} | $typeLabel | ${_formatAmount(budget.amount)} | ${_formatAmount(expense)} | ${_formatAmount(remaining)} | ${_calcPercent(expense, budget.amount)} |');
    }

    // 합계
    sb.writeln('| **${_col('total')}** | - | **${_formatAmount(totalBudget)}** | **${_formatAmount(totalExpense)}** | **${_formatAmount(totalBudget - totalExpense)}** | **${_calcPercent(totalExpense, totalBudget)}** |');
    sb.writeln();

    // 세부예산 요약
    if (subBudgets.isNotEmpty) {
      sb.writeln('### ${_getSubBudgetSummaryTitle()}');
      sb.writeln('| ${_col('budget')} | ${_col('subBudget')} | ${_col('budget')} | ${_col('used')} | ${_col('remaining')} |');
      sb.writeln('|------|------|------|------|------|');

      for (var budget in budgets) {
        final subs = subBudgets.where((s) => s.budgetId == budget.id).toList();
        for (var sub in subs) {
          final expense = getSubBudgetExpense(sub.id);
          final remaining = sub.amount - expense;
          sb.writeln('| ${budget.name} | ${sub.name} | ${_formatAmount(sub.amount)} | ${_formatAmount(expense)} | ${_formatAmount(remaining)} |');
        }
      }
      sb.writeln();
    }

    // 지출 내역
    if (expenses.isNotEmpty) {
      sb.writeln('### ${_getExpenseHistoryTitle()}');
      sb.writeln('| ${_col('date')} | ${_col('budget')} | ${_col('type')} | ${_col('subBudget')} | ${_col('memo')} | ${_col('amount')} |');
      sb.writeln('|------|------|------|------|------|------|');

      // 날짜순 정렬
      final sortedExpenses = List<Expense>.from(expenses)..sort((a, b) => a.date.compareTo(b.date));

      for (var exp in sortedExpenses) {
        final budget = budgets.where((b) => b.id == exp.budgetId).firstOrNull;
        final subBudget = exp.subBudgetId != null
            ? subBudgets.where((s) => s.id == exp.subBudgetId).firstOrNull
            : null;

        // #28: 지출 유형 표시 (해당 예산이 고정지출인지)
        final isFixed = budget != null && (budget.isRecurring || _isFixedExpenseBudget(budget.name));
        final typeLabel = isFixed ? _col('fixedExpense') : _col('variableExpense');

        sb.writeln('| ${dateFormat.format(exp.date)} | ${budget?.name ?? '-'} | $typeLabel | ${subBudget?.name ?? '-'} | ${exp.memo ?? '-'} | ${_formatAmount(exp.amount)} |');
      }
      sb.writeln();
    }

    // 요약 통계
    sb.writeln('### ${_getSummaryStatsTitle()}');
    sb.writeln('- ${_col('totalBudget')}: ${_formatAmount(totalBudget)}');
    sb.writeln('- ${_col('totalExpense')}: ${_formatAmount(totalExpense)}');
    sb.writeln('- ${_col('totalRemaining')}: ${_formatAmount(totalBudget - totalExpense)}');
    sb.writeln('- ${_col('overallUsageRate')}: ${_calcPercent(totalExpense, totalBudget)}');
    sb.writeln('- ${_col('expenseCount')}: ${expenses.length}${_col('count')}');

    return sb.toString();
  }

  // #28: 정기지출 예산인지 판단 (이름 기반)
  bool _isFixedExpenseBudget(String name) {
    final lowerName = name.toLowerCase();
    // 정기지출, 고정비, 고정지출, 정기, fixed, recurring 등 키워드 확인
    return lowerName.contains('정기') ||
           lowerName.contains('고정') ||
           lowerName.contains('fixed') ||
           lowerName.contains('recurring') ||
           lowerName.contains('subscription') ||
           lowerName.contains('월세') ||
           lowerName.contains('보험') ||
           lowerName.contains('통신') ||
           lowerName.contains('구독');
  }

  // 다국어 컬럼명
  String _col(String key) {
    final Map<String, Map<String, String>> cols = {
      'ko': {
        'budgetName': '예산명', 'budget': '예산', 'used': '사용', 'remaining': '잔액',
        'usageRate': '사용률', 'total': '합계', 'subBudget': '세부예산', 'date': '날짜',
        'memo': '내용', 'amount': '금액', 'totalBudget': '총 예산', 'totalExpense': '총 지출',
        'totalRemaining': '총 잔액', 'overallUsageRate': '전체 사용률', 'expenseCount': '지출 건수', 'count': '건',
        'type': '유형', 'fixedExpense': '고정지출', 'variableExpense': '변동지출',  // #28
      },
      'en': {
        'budgetName': 'Budget', 'budget': 'Budget', 'used': 'Used', 'remaining': 'Left',
        'usageRate': 'Usage%', 'total': 'Total', 'subBudget': 'Sub-budget', 'date': 'Date',
        'memo': 'Memo', 'amount': 'Amount', 'totalBudget': 'Total Budget', 'totalExpense': 'Total Expense',
        'totalRemaining': 'Total Remaining', 'overallUsageRate': 'Overall Usage', 'expenseCount': 'Expense Count', 'count': '',
        'type': 'Type', 'fixedExpense': 'Fixed', 'variableExpense': 'Variable',  // #28
      },
      'ja': {
        'budgetName': '予算名', 'budget': '予算', 'used': '使用', 'remaining': '残額',
        'usageRate': '使用率', 'total': '合計', 'subBudget': 'サブ予算', 'date': '日付',
        'memo': '内容', 'amount': '金額', 'totalBudget': '総予算', 'totalExpense': '総支出',
        'totalRemaining': '総残額', 'overallUsageRate': '全体使用率', 'expenseCount': '支出件数', 'count': '件',
        'type': 'タイプ', 'fixedExpense': '固定費', 'variableExpense': '変動費',  // #28
      },
    };
    return cols[language]?[key] ?? cols['ko']![key]!;
  }

  String _getTitle() {
    switch (language) {
      case 'en': return 'Budget Report';
      case 'ja': return '家計簿レポート';
      default: return '가계부 리포트';
    }
  }

  String _getBudgetSummaryTitle() {
    switch (language) {
      case 'en': return 'Budget Summary';
      case 'ja': return '予算サマリー';
      default: return '예산 요약';
    }
  }

  String _getSubBudgetSummaryTitle() {
    switch (language) {
      case 'en': return 'Sub-budget Summary';
      case 'ja': return 'サブ予算サマリー';
      default: return '세부예산 요약';
    }
  }

  String _getExpenseHistoryTitle() {
    switch (language) {
      case 'en': return 'Expense History';
      case 'ja': return '支出履歴';
      default: return '지출 내역';
    }
  }

  String _getSummaryStatsTitle() {
    switch (language) {
      case 'en': return 'Summary Statistics';
      case 'ja': return '統計サマリー';
      default: return '요약 통계';
    }
  }
}
