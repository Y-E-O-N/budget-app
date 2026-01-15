// =============================================================================
// recurring_expense_provider.dart - 반복 지출 전용 Provider
// =============================================================================
// BudgetProvider에서 반복 지출 관련 로직을 분리
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_expense.dart';
import '../models/expense.dart';

/// 반복 지출 관리 Provider
class RecurringExpenseProvider extends ChangeNotifier {
  late Box<RecurringExpense> _recurringBox;
  late Box<Expense> _expenseBox;
  final _uuid = const Uuid();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ===========================================================================
  // 초기화
  // ===========================================================================

  /// Provider 초기화 (Hive Box 열기)
  Future<void> init() async {
    _recurringBox = await Hive.openBox<RecurringExpense>('recurringExpenses');
    _expenseBox = await Hive.openBox<Expense>('expenses');
    _isInitialized = true;
    notifyListeners();
  }

  /// 외부에서 Box 주입 (테스트 또는 공유 Box 사용 시)
  void initWithBoxes(Box<RecurringExpense> recurringBox, Box<Expense> expenseBox) {
    _recurringBox = recurringBox;
    _expenseBox = expenseBox;
    _isInitialized = true;
    notifyListeners();
  }

  // ===========================================================================
  // Getter
  // ===========================================================================

  /// 전체 반복 지출 목록
  List<RecurringExpense> get recurringExpenses {
    if (!_isInitialized) return [];
    return _recurringBox.values.toList();
  }

  /// 활성화된 반복 지출 목록
  List<RecurringExpense> get activeRecurringExpenses {
    if (!_isInitialized) return [];
    return _recurringBox.values.where((r) => r.isActive).toList();
  }

  /// 비활성화된 반복 지출 목록
  List<RecurringExpense> get inactiveRecurringExpenses {
    if (!_isInitialized) return [];
    return _recurringBox.values.where((r) => !r.isActive).toList();
  }

  /// 특정 예산의 반복 지출 목록
  List<RecurringExpense> getByBudgetId(String budgetId) {
    if (!_isInitialized) return [];
    return _recurringBox.values.where((r) => r.budgetId == budgetId).toList();
  }

  /// ID로 반복 지출 가져오기
  RecurringExpense? getById(String id) {
    if (!_isInitialized) return null;
    return _recurringBox.get(id);
  }

  // ===========================================================================
  // CRUD 작업
  // ===========================================================================

  /// 반복 지출 추가
  Future<RecurringExpense> add({
    required String budgetId,
    String? subBudgetId,
    required int amount,
    String? memo,
    required RepeatType repeatType,
    int? dayOfWeek,
    int? dayOfMonth,
  }) async {
    final recurring = RecurringExpense(
      id: _uuid.v4(),
      budgetId: budgetId,
      subBudgetId: subBudgetId,
      amount: amount,
      memo: memo,
      repeatType: repeatType,
      dayOfWeek: dayOfWeek,
      dayOfMonth: dayOfMonth,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _recurringBox.put(recurring.id, recurring);
    notifyListeners();
    return recurring;
  }

  /// 반복 지출 수정
  Future<void> update(RecurringExpense recurring) async {
    await _recurringBox.put(recurring.id, recurring);
    notifyListeners();
  }

  /// 반복 지출 삭제
  Future<void> delete(String id) async {
    await _recurringBox.delete(id);
    notifyListeners();
  }

  /// 예산 ID에 해당하는 모든 반복 지출 삭제
  Future<void> deleteByBudgetId(String budgetId) async {
    final toDelete = _recurringBox.values
        .where((r) => r.budgetId == budgetId)
        .map((r) => r.id)
        .toList();

    for (final id in toDelete) {
      await _recurringBox.delete(id);
    }

    if (toDelete.isNotEmpty) {
      notifyListeners();
    }
  }

  // ===========================================================================
  // 활성화/비활성화
  // ===========================================================================

  /// 반복 지출 활성화/비활성화 토글
  Future<void> toggle(String id) async {
    final recurring = _recurringBox.get(id);
    if (recurring != null) {
      recurring.isActive = !recurring.isActive;
      await _recurringBox.put(id, recurring);
      notifyListeners();
    }
  }

  /// 활성화 설정
  Future<void> setActive(String id, bool isActive) async {
    final recurring = _recurringBox.get(id);
    if (recurring != null && recurring.isActive != isActive) {
      recurring.isActive = isActive;
      await _recurringBox.put(id, recurring);
      notifyListeners();
    }
  }

  /// 모든 반복 지출 비활성화
  Future<void> deactivateAll() async {
    for (final recurring in _recurringBox.values) {
      if (recurring.isActive) {
        recurring.isActive = false;
        await _recurringBox.put(recurring.id, recurring);
      }
    }
    notifyListeners();
  }

  // ===========================================================================
  // 자동 지출 생성
  // ===========================================================================

  /// 오늘 날짜에 해당하는 반복 지출 자동 생성
  /// @return 생성된 지출 수
  Future<int> generateTodayExpenses() async {
    int generatedCount = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final recurring in _recurringBox.values) {
      if (!recurring.isActive) continue;

      if (recurring.shouldGenerateToday()) {
        // 지출 생성
        final expense = Expense(
          id: _uuid.v4(),
          budgetId: recurring.budgetId,
          subBudgetId: recurring.subBudgetId,
          amount: recurring.amount,
          date: today,
          memo: recurring.memo,
        );
        await _expenseBox.put(expense.id, expense);

        // 마지막 생성일 업데이트
        recurring.lastGeneratedDate = today;
        await _recurringBox.put(recurring.id, recurring);

        generatedCount++;
      }
    }

    if (generatedCount > 0) {
      notifyListeners();
    }

    return generatedCount;
  }

  /// 특정 날짜에 해당하는 반복 지출 생성
  /// @param date 생성할 날짜
  /// @return 생성된 지출 수
  Future<int> generateExpensesForDate(DateTime date) async {
    int generatedCount = 0;
    final targetDate = DateTime(date.year, date.month, date.day);

    for (final recurring in _recurringBox.values) {
      if (!recurring.isActive) continue;

      final shouldGenerate = _shouldGenerateForDate(recurring, targetDate);
      if (shouldGenerate) {
        final expense = Expense(
          id: _uuid.v4(),
          budgetId: recurring.budgetId,
          subBudgetId: recurring.subBudgetId,
          amount: recurring.amount,
          date: targetDate,
          memo: recurring.memo,
        );
        await _expenseBox.put(expense.id, expense);
        generatedCount++;
      }
    }

    if (generatedCount > 0) {
      notifyListeners();
    }

    return generatedCount;
  }

  /// 특정 날짜에 반복 지출을 생성해야 하는지 확인
  bool _shouldGenerateForDate(RecurringExpense recurring, DateTime date) {
    switch (recurring.repeatType) {
      case RepeatType.weekly:
        // DateTime.weekday: 1=월, 7=일 -> 0=월, 6=일로 변환
        final dateWeekday = date.weekday - 1;
        return dateWeekday == recurring.dayOfWeek;

      case RepeatType.monthly:
        // 월말 처리 (31일이 없는 달 등)
        final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
        final targetDay = recurring.dayOfMonth ?? 1;
        final effectiveDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;
        return date.day == effectiveDay;
    }
  }

  // ===========================================================================
  // 통계
  // ===========================================================================

  /// 활성화된 반복 지출의 월간 예상 총액
  int get estimatedMonthlyTotal {
    int total = 0;

    for (final recurring in activeRecurringExpenses) {
      switch (recurring.repeatType) {
        case RepeatType.weekly:
          total += recurring.amount * 4; // 약 4주
          break;
        case RepeatType.monthly:
          total += recurring.amount;
          break;
      }
    }

    return total;
  }

  /// 반복 유형별 개수
  Map<RepeatType, int> get countByRepeatType {
    final result = <RepeatType, int>{
      RepeatType.weekly: 0,
      RepeatType.monthly: 0,
    };

    for (final recurring in activeRecurringExpenses) {
      result[recurring.repeatType] = (result[recurring.repeatType] ?? 0) + 1;
    }

    return result;
  }
}
