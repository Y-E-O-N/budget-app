// =============================================================================
// budget_provider.dart - 예산 데이터 상태 관리
// =============================================================================
// 이 파일은 앱의 모든 예산 관련 데이터를 관리합니다.
// 
// Provider란?
// - Flutter에서 상태 관리를 위한 패턴/패키지입니다
// - 데이터가 변경되면 관련된 UI가 자동으로 업데이트됩니다
// 
// ChangeNotifier란?
// - 데이터 변경을 알려주는(notify) 기능을 가진 클래스입니다
// - notifyListeners()를 호출하면 이 데이터를 구독하는 모든 위젯이
//   다시 빌드(rebuild)됩니다
// =============================================================================

// 상태 관리의 핵심 패키지
import 'package:flutter/foundation.dart';

// Hive 데이터베이스 (Flutter 전용)
import 'package:hive_flutter/hive_flutter.dart';

// UUID 생성 패키지 - 고유 ID를 만들 때 사용
import 'package:uuid/uuid.dart';

// 우리가 만든 데이터 모델들
import '../models/budget.dart';
import '../models/sub_budget.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import '../models/trend_data.dart';

// 유틸리티 함수
import '../utils/date_utils.dart';

// =============================================================================
// BudgetProvider 클래스 - 예산 데이터의 중앙 관리자
// =============================================================================
// ChangeNotifier를 상속받아 데이터 변경을 UI에 알릴 수 있습니다
class BudgetProvider extends ChangeNotifier {
  
  // ---------------------------------------------------------------------------
  // Hive Box 선언
  // ---------------------------------------------------------------------------
  // Box란? Hive에서 데이터를 저장하는 컨테이너 (테이블과 비슷)
  // late 키워드: 나중에 값이 할당될 것임을 명시 (init()에서 초기화)
  
  late Box<Budget> _budgetBox;        // 예산 저장소
  late Box<SubBudget> _subBudgetBox;  // 세부예산 저장소
  late Box<Expense> _expenseBox;      // 지출 저장소
  late Box<RecurringExpense> _recurringBox;  // 반복 지출 저장소

  // ---------------------------------------------------------------------------
  // 현재 보고 있는 연/월
  // ---------------------------------------------------------------------------
  // _ (언더스코어)로 시작하는 변수는 private (이 클래스 내에서만 접근 가능)
  int _currentYear = DateTime.now().year;    // 현재 연도로 초기화
  int _currentMonth = DateTime.now().month;  // 현재 월로 초기화

  // 마지막 선택된 세부예산 ID (지출 추가 시 자동 선택용)
  String? _lastSelectedSubBudgetId;

  // ---------------------------------------------------------------------------
  // UUID 생성기
  // ---------------------------------------------------------------------------
  // const: 컴파일 타임에 생성되어 재사용됨 (성능 최적화)
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Getter 메서드들 - 외부에서 private 변수에 접근할 수 있게 해줌
  // ---------------------------------------------------------------------------
  // get 키워드: 읽기 전용 속성을 정의
  int get currentYear => _currentYear;    // 현재 연도 반환
  int get currentMonth => _currentMonth;  // 현재 월 반환
  String? get lastSelectedSubBudgetId => _lastSelectedSubBudgetId;
  void setLastSelectedSubBudgetId(String? id) {
    _lastSelectedSubBudgetId = id;
  }

  // ===========================================================================
  // 초기화 메서드
  // ===========================================================================
  // Future<void>: 비동기 함수이며 반환값이 없음
  // async: 함수 내에서 await를 사용할 수 있게 해줌
  Future<void> init() async {
    // Hive Box 열기 (없으면 생성됨)
    // await: Box가 열릴 때까지 기다림
    _budgetBox = await Hive.openBox<Budget>('budgets');
    _subBudgetBox = await Hive.openBox<SubBudget>('subBudgets');
    _expenseBox = await Hive.openBox<Expense>('expenses');
    _recurringBox = await Hive.openBox<RecurringExpense>('recurringExpenses');

    // 반복 지출 자동 생성
    await generateRecurringExpenses();

    // 초기화 완료 후 UI 업데이트
    notifyListeners();
  }

  // ===========================================================================
  // 월 이동 메서드
  // ===========================================================================
  
  /// 이전 달로 이동
  void previousMonth() {
    // AppDateUtils를 사용한 월 이동
    final prev = AppDateUtils.getPreviousMonth(_currentYear, _currentMonth);
    _currentYear = prev.year;
    _currentMonth = prev.month;

    // 매달 적용 예산 처리 (이전 달의 반복 예산을 현재 달로 복사)
    _applyRecurringBudgets();

    // UI 업데이트
    notifyListeners();
  }

  /// 다음 달로 이동
  void nextMonth() {
    // AppDateUtils를 사용한 월 이동
    final next = AppDateUtils.getNextMonth(_currentYear, _currentMonth);
    _currentYear = next.year;
    _currentMonth = next.month;

    // 매달 적용 예산 처리
    _applyRecurringBudgets();

    // UI 업데이트
    notifyListeners();
  }

  /// 특정 연도/월로 직접 이동 (#10)
  void setYearMonth(int year, int month) {
    _currentYear = year;
    _currentMonth = month;

    // 매달 적용 예산 처리
    _applyRecurringBudgets();

    // UI 업데이트
    notifyListeners();
  }

  // ===========================================================================
  // 예산(Budget) 관련 메서드
  // ===========================================================================

  /// 현재 월의 예산 목록을 가져옴 (순서대로 정렬)
  /// List<Budget>: Budget 객체들의 리스트를 반환
  List<Budget> get currentBudgets {
    // _budgetBox.values: 저장된 모든 예산을 Iterable로 반환
    // .where(): 조건에 맞는 항목만 필터링
    // .toList(): Iterable을 List로 변환
    // #3: order 필드로 정렬
    return _budgetBox.values
        .where((b) => b.year == _currentYear && b.month == _currentMonth)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order)); // 순서대로 정렬
  }

  /// 현재 월의 모든 세부예산 목록
  List<SubBudget> get currentSubBudgets {
    return _subBudgetBox.values
        .where((s) => s.year == _currentYear && s.month == _currentMonth)
        .toList();
  }

  /// 현재 월의 모든 지출 목록
  List<Expense> get currentExpenses {
    return _expenseBox.values
        .where((e) => e.date.year == _currentYear && e.date.month == _currentMonth)
        .toList();
  }

  /// 현재 월의 총 예산 합계
  int get totalBudget {
    // .fold(): 리스트의 모든 항목을 하나의 값으로 합침
    // 0: 초기값
    // (sum, b) => sum + b.amount: 각 예산의 금액을 누적 합산
    return currentBudgets.fold(0, (sum, b) => sum + b.amount);
  }

  /// 새 예산 추가
  /// @param name 예산 이름
  /// @param amount 예산 금액
  /// @param isRecurring 매달 적용 여부
  Future<void> addBudget(String name, int amount, bool isRecurring) async {
    // #3: 현재 월의 최대 순서 값 구하기
    final maxOrder = currentBudgets.isEmpty
        ? 0
        : currentBudgets.map((b) => b.order).reduce((a, b) => a > b ? a : b) + 1;

    // 새 Budget 객체 생성
    final budget = Budget(
      id: _uuid.v4(),              // v4: 랜덤 UUID 생성
      name: name,
      amount: amount,
      year: _currentYear,
      month: _currentMonth,
      isRecurring: isRecurring,
      order: maxOrder,             // #3: 맨 뒤에 추가
    );

    // Box에 저장 (id를 키로 사용)
    await _budgetBox.put(budget.id, budget);

    // UI 업데이트
    notifyListeners();
  }

  /// 예산 수정
  Future<void> updateBudget(Budget budget) async {
    // 같은 id로 덮어쓰기
    await _budgetBox.put(budget.id, budget);
    notifyListeners();
  }

  /// 예산 삭제
  /// 예산을 삭제하면 관련된 세부예산과 지출도 함께 삭제됩니다
  Future<void> deleteBudget(String id) async {
    // 관련 ID 수집 후 배치 삭제
    final subIds = _subBudgetBox.values
        .where((s) => s.budgetId == id).map((s) => s.id).toList();
    final expIds = _expenseBox.values
        .where((e) => e.budgetId == id).map((e) => e.id).toList();

    await _budgetBox.delete(id);
    await _subBudgetBox.deleteAll(subIds);
    await _expenseBox.deleteAll(expIds);

    notifyListeners();
  }

  // ===========================================================================
  // #3: 예산 순서 변경 메서드
  // ===========================================================================

  /// 예산 순서 변경 (위로 이동)
  Future<void> moveBudgetUp(String id) async {
    final budgets = currentBudgets; // 이미 order로 정렬됨
    final index = budgets.indexWhere((b) => b.id == id);
    if (index <= 0) return; // 첫 번째면 이동 불가

    // 위 예산과 order 값 교환
    final current = budgets[index];
    final above = budgets[index - 1];
    final tempOrder = current.order;
    await _budgetBox.put(current.id, current.copyWith(order: above.order));
    await _budgetBox.put(above.id, above.copyWith(order: tempOrder));
    notifyListeners();
  }

  /// 예산 순서 변경 (아래로 이동)
  Future<void> moveBudgetDown(String id) async {
    final budgets = currentBudgets; // 이미 order로 정렬됨
    final index = budgets.indexWhere((b) => b.id == id);
    if (index < 0 || index >= budgets.length - 1) return; // 마지막이면 이동 불가

    // 아래 예산과 order 값 교환
    final current = budgets[index];
    final below = budgets[index + 1];
    final tempOrder = current.order;
    await _budgetBox.put(current.id, current.copyWith(order: below.order));
    await _budgetBox.put(below.id, below.copyWith(order: tempOrder));
    notifyListeners();
  }

  /// 드래그 앤 드롭으로 예산 순서 변경
  Future<void> reorderBudgets(int oldIndex, int newIndex) async {
    final budgets = currentBudgets.toList(); // 복사본 생성
    if (oldIndex < newIndex) {
      newIndex -= 1; // 드래그 방향 보정
    }
    final item = budgets.removeAt(oldIndex);
    budgets.insert(newIndex, item);

    // 순서 재할당
    for (var i = 0; i < budgets.length; i++) {
      await _budgetBox.put(budgets[i].id, budgets[i].copyWith(order: i));
    }
    notifyListeners();
  }

  // ===========================================================================
  // 세부예산(SubBudget) 관련 메서드
  // ===========================================================================

  /// 특정 예산의 세부예산 목록 가져오기
  List<SubBudget> getSubBudgets(String budgetId) {
    return _subBudgetBox.values
        .where((s) =>
            s.budgetId == budgetId &&          // 해당 예산에 속하고
            s.year == _currentYear &&          // 현재 연도이고
            s.month == _currentMonth)          // 현재 월인 것만
        .toList();
  }

  /// 새 세부예산 추가
  Future<void> addSubBudget(
      String budgetId, String name, int amount, bool isRecurring) async {
    final subBudget = SubBudget(
      id: _uuid.v4(),
      budgetId: budgetId,          // 상위 예산 ID 연결
      name: name,
      amount: amount,
      year: _currentYear,
      month: _currentMonth,
      isRecurring: isRecurring,
    );
    await _subBudgetBox.put(subBudget.id, subBudget);
    notifyListeners();
  }

  /// 세부예산 수정
  Future<void> updateSubBudget(SubBudget subBudget) async {
    await _subBudgetBox.put(subBudget.id, subBudget);
    notifyListeners();
  }

  /// 세부예산 삭제
  Future<void> deleteSubBudget(String id) async {
    await _subBudgetBox.delete(id);
    notifyListeners();
  }

  // ===========================================================================
  // 지출(Expense) 관련 메서드
  // ===========================================================================

  /// 특정 예산의 지출 목록 가져오기 (날짜 내림차순 정렬)
  List<Expense> getExpenses(String budgetId) {
    return _expenseBox.values
        .where((e) =>
            e.budgetId == budgetId &&
            e.date.year == _currentYear &&
            e.date.month == _currentMonth)
        .toList()
      // ..sort(): 캐스케이드 연산자로 정렬 후 리스트 반환
      // b.date.compareTo(a.date): 내림차순 (최신순)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 특정 예산의 총 지출 금액 계산
  int getTotalExpense(String budgetId) {
    return getExpenses(budgetId).fold(0, (sum, e) => sum + e.amount);
  }
/// 특정 세부예산의 지출 합계 계산
  int getSubBudgetExpense(String subBudgetId) {
    return _expenseBox.values
        .where((e) => e.subBudgetId == subBudgetId)
        .fold(0, (sum, e) => sum + e.amount);
  }

  /// 새 지출 추가
  Future<void> addExpense(
      String budgetId, String? subBudgetId, int amount, DateTime date,
      {String? memo}  // 중괄호 안의 매개변수는 선택적 이름 매개변수
      ) async {
    final expense = Expense(
      id: _uuid.v4(),
      budgetId: budgetId,
      subBudgetId: subBudgetId,  // null 가능
      amount: amount,
      date: date,
      memo: memo,  // null 가능
    );
    await _expenseBox.put(expense.id, expense);
    notifyListeners();
  }

  /// 지출 수정
  Future<void> updateExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense);
    notifyListeners();
  }

  /// 지출 삭제
  Future<void> deleteExpense(String id) async {
    await _expenseBox.delete(id);
    notifyListeners();
  }

  // ===========================================================================
  // 매달 적용(Recurring) 예산 처리
  // ===========================================================================
  
  /// 이전 달의 반복 예산을 현재 달로 복사
  /// private 메서드 (외부에서 호출 불가)
  void _applyRecurringBudgets() {
    // AppDateUtils를 사용한 이전 달 계산
    final prev = AppDateUtils.getPreviousMonth(_currentYear, _currentMonth);
    final prevYear = prev.year;
    final prevMonth = prev.month;

    // 현재 달에 이미 예산이 있는지 확인
    final currentMonthBudgets = _budgetBox.values
        .where((b) => b.year == _currentYear && b.month == _currentMonth)
        .toList();

    // 현재 달에 예산이 없으면 이전 달의 반복 예산을 복사
    if (currentMonthBudgets.isEmpty) {
      // 이전 달의 반복 예산 찾기
      final recurringBudgets = _budgetBox.values
          .where((b) => 
              b.year == prevYear && 
              b.month == prevMonth && 
              b.isRecurring)  // 매달 적용 체크된 것만
          .toList();

      // 각 반복 예산을 현재 달로 복사
      for (var budget in recurringBudgets) {
        // 새 예산 생성 (ID는 새로 생성)
        final newBudget = Budget(
          id: _uuid.v4(),
          name: budget.name,
          amount: budget.amount,
          year: _currentYear,
          month: _currentMonth,
          isRecurring: true,  // 복사된 예산도 반복 유지
          order: budget.order, // #3: 순서도 복사
        );
        _budgetBox.put(newBudget.id, newBudget);

        // 해당 예산의 반복 세부예산도 복사
        final recurringSubBudgets = _subBudgetBox.values
            .where((s) =>
                s.budgetId == budget.id &&  // 원본 예산에 속한
                s.year == prevYear &&
                s.month == prevMonth &&
                s.isRecurring)              // 매달 적용 체크된 것만
            .toList();

        for (var sub in recurringSubBudgets) {
          final newSubBudget = SubBudget(
            id: _uuid.v4(),
            budgetId: newBudget.id,  // 새 예산의 ID로 연결
            name: sub.name,
            amount: sub.amount,
            year: _currentYear,
            month: _currentMonth,
            isRecurring: true,
          );
          _subBudgetBox.put(newSubBudget.id, newSubBudget);
        }
      }
    }
  }

  // ===========================================================================
  // 유틸리티 메서드
  // ===========================================================================

  /// ID로 예산 가져오기
  Budget? getBudgetById(String id) {
    try {
      return _budgetBox.get(id);
    } catch (e) {
      // 에러 발생 시 null 반환
      return null;
    }
  }

  /// ID로 세부예산 가져오기
  SubBudget? getSubBudgetById(String id) {
    try {
      return _subBudgetBox.get(id);
    } catch (e) {
      return null;
    }
  }

  /// 대상 월에서 같은 이름의 예산을 찾거나, 없으면 자동 생성
  Future<String> findOrCreateBudgetForMonth(Budget sourceBudget, int targetYear, int targetMonth) async {
    // 같은 이름의 예산이 대상 월에 있는지 탐색
    final existing = _budgetBox.values.cast<Budget?>().firstWhere(
      (b) => b!.name == sourceBudget.name && b.year == targetYear && b.month == targetMonth,
      orElse: () => null,
    );
    if (existing != null) return existing.id;

    // 없으면 자동 생성
    final newBudget = Budget(
      id: _uuid.v4(),
      name: sourceBudget.name,
      amount: sourceBudget.amount,
      year: targetYear,
      month: targetMonth,
      isRecurring: sourceBudget.isRecurring,
      order: sourceBudget.order,
    );
    await _budgetBox.put(newBudget.id, newBudget);
    return newBudget.id;
  }

  /// 대상 월 예산 내에서 같은 이름의 세부예산을 찾거나, 없으면 자동 생성
  Future<String?> findOrCreateSubBudgetForMonth(String? sourceSubBudgetId, String targetBudgetId, int targetYear, int targetMonth) async {
    if (sourceSubBudgetId == null) return null;
    final sourceSub = _subBudgetBox.get(sourceSubBudgetId);
    if (sourceSub == null) return null;

    // 대상 예산 내에서 같은 이름의 세부예산 탐색
    final existing = _subBudgetBox.values.cast<SubBudget?>().firstWhere(
      (s) => s!.budgetId == targetBudgetId && s.name == sourceSub.name && s.year == targetYear && s.month == targetMonth,
      orElse: () => null,
    );
    if (existing != null) return existing.id;

    // 없으면 자동 생성
    final newSub = SubBudget(
      id: _uuid.v4(),
      budgetId: targetBudgetId,
      name: sourceSub.name,
      amount: sourceSub.amount,
      year: targetYear,
      month: targetMonth,
      isRecurring: sourceSub.isRecurring,
    );
    await _subBudgetBox.put(newSub.id, newSub);
    return newSub.id;
  }

  /// 전체 지출 목록 (모든 기간)
  List<Expense> get allExpenses => _expenseBox.values.toList();

  /// 전체 예산 목록 (모든 기간)
  List<Budget> get allBudgets => _budgetBox.values.toList();

  /// 전체 세부예산 목록 (모든 기간)
  List<SubBudget> get allSubBudgets => _subBudgetBox.values.toList();

  // ===========================================================================
  // 트렌드 분석 메서드
  // ===========================================================================

  /// 특정 월의 총 지출 계산
  int getTotalExpenseForMonth(int year, int month) {
    return _expenseBox.values
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0, (sum, e) => sum + e.amount);
  }

  /// 특정 월의 총 예산 계산
  int getTotalBudgetForMonth(int year, int month) {
    return _budgetBox.values
        .where((b) => b.year == year && b.month == month)
        .fold(0, (sum, b) => sum + b.amount);
  }

  /// 최근 N개월 월별 지출/예산 데이터 (타입 안전 버전)
  List<MonthlyTrendData> getMonthlyTrend(int months) {
    // AppDateUtils를 사용해 월 목록 생성 (오래된 순)
    final monthList = AppDateUtils.getMonthsBack(_currentYear, _currentMonth, months);

    // 각 월의 데이터를 MonthlyTrendData로 변환
    return monthList.map((m) => MonthlyTrendData(
      year: m.year,
      month: m.month,
      expense: getTotalExpenseForMonth(m.year, m.month),
      budget: getTotalBudgetForMonth(m.year, m.month),
    )).toList();
  }

  /// 예산별 최근 N개월 지출 데이터 (타입 안전 버전)
  List<BudgetTrendData> getBudgetTrendByMonth(int months) {
    final budgets = currentBudgets;
    final monthList = AppDateUtils.getMonthsBack(_currentYear, _currentMonth, months);

    // Map 사전 구축: "이름\x00년\x00월" → Budget (null 문자로 키 충돌 방지)
    final budgetLookup = <String, Budget>{};
    for (final b in _budgetBox.values) {
      budgetLookup['${b.name}\x00${b.year}\x00${b.month}'] = b;
    }

    // Map 사전 구축: "budgetId\x00년\x00월" → 지출 합계
    final expenseSumLookup = <String, int>{};
    for (final e in _expenseBox.values) {
      final key = '${e.budgetId}\x00${e.date.year}\x00${e.date.month}';
      expenseSumLookup[key] = (expenseSumLookup[key] ?? 0) + e.amount;
    }

    return budgets.map((budget) {
      final monthlyData = monthList.map((m) {
        final matchingBudget = budgetLookup['${budget.name}\x00${m.year}\x00${m.month}'];
        if (matchingBudget == null) return 0;
        return expenseSumLookup['${matchingBudget.id}\x00${m.year}\x00${m.month}'] ?? 0;
      }).toList();

      return BudgetTrendData(
        budgetName: budget.name,
        monthlyExpenses: monthlyData,
      );
    }).toList();
  }

  /// 전월 대비 증감률 (%)
  double getMonthOverMonthChange() {
    return getMonthOverMonthData().changePercent;
  }

  /// 전월 지출 금액
  int getPreviousMonthExpense() {
    final prev = AppDateUtils.getPreviousMonth(_currentYear, _currentMonth);
    return getTotalExpenseForMonth(prev.year, prev.month);
  }

  /// 전월 대비 변화 데이터 (타입 안전 버전)
  MonthOverMonthData getMonthOverMonthData() {
    // 현재 월 지출
    final currentExpense = getTotalExpenseForMonth(_currentYear, _currentMonth);

    // AppDateUtils로 이전 월 계산
    final prev = AppDateUtils.getPreviousMonth(_currentYear, _currentMonth);
    final prevExpense = getTotalExpenseForMonth(prev.year, prev.month);

    // 증감률 계산
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
  // 반복 지출 관리
  // ===========================================================================

  /// 전체 반복 지출 목록
  List<RecurringExpense> get recurringExpenses => _recurringBox.values.toList();

  /// 활성화된 반복 지출 목록
  List<RecurringExpense> get activeRecurringExpenses =>
      _recurringBox.values.where((r) => r.isActive).toList();

  /// 반복 지출 추가
  Future<void> addRecurringExpense({
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
  }

  /// 반복 지출 수정
  Future<void> updateRecurringExpense(RecurringExpense recurring) async {
    await _recurringBox.put(recurring.id, recurring);
    notifyListeners();
  }

  /// 반복 지출 삭제
  Future<void> deleteRecurringExpense(String id) async {
    await _recurringBox.delete(id);
    notifyListeners();
  }

  /// 반복 지출 활성화/비활성화 토글
  Future<void> toggleRecurringExpense(String id) async {
    final recurring = _recurringBox.get(id);
    if (recurring != null) {
      recurring.isActive = !recurring.isActive;
      await _recurringBox.put(id, recurring);
      notifyListeners();
    }
  }

  /// 오늘 날짜에 해당하는 반복 지출 자동 생성
  Future<int> generateRecurringExpenses() async {
    int generatedCount = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final recurring in _recurringBox.values) {
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

  // ===========================================================================
  // 데이터 불러오기 (Import)
  // ===========================================================================

  /// 엑셀에서 불러온 데이터를 현재 월에 추가
  /// @param budgetData 불러온 예산 목록 (name, amount)
  /// @param subBudgetData 불러온 세부예산 목록 (budgetName, name, amount)
  /// @param expenseData 불러온 지출 목록 (date, budgetName, subBudgetName, memo, amount)
  /// @param targetYear 대상 연도 (지출 데이터의 날짜에서 추출하거나 현재 연도)
  /// @param targetMonth 대상 월 (지출 데이터의 날짜에서 추출하거나 현재 월)
  Future<int> importData({
    required List<Map<String, dynamic>> budgetData,
    required List<Map<String, dynamic>> subBudgetData,
    required List<Map<String, dynamic>> expenseData,
    int? targetYear,
    int? targetMonth,
  }) async {
    int importedCount = 0;
    final year = targetYear ?? _currentYear;
    final month = targetMonth ?? _currentMonth;

    // 예산명 -> ID 매핑
    final budgetIdMap = <String, String>{};
    // 세부예산 (예산명 + 세부예산명) -> ID 매핑
    final subBudgetIdMap = <String, String>{};

    // 1. 예산 추가 (이름이 중복되면 기존 예산 사용)
    for (final data in budgetData) {
      final name = data['name'] as String;
      final amount = data['amount'] as int;

      // 현재 월에 같은 이름의 예산이 있는지 확인
      final existing = _budgetBox.values.firstWhere(
        (b) => b.name == name && b.year == year && b.month == month,
        orElse: () => Budget(id: '', name: '', amount: 0, year: 0, month: 0),
      );

      if (existing.id.isNotEmpty) {
        // 기존 예산 사용
        budgetIdMap[name] = existing.id;
      } else {
        // 새 예산 생성
        final newBudget = Budget(
          id: _uuid.v4(),
          name: name,
          amount: amount,
          year: year,
          month: month,
          isRecurring: false,
        );
        await _budgetBox.put(newBudget.id, newBudget);
        budgetIdMap[name] = newBudget.id;
        importedCount++;
      }
    }

    // 2. 세부예산 추가
    for (final data in subBudgetData) {
      final budgetName = data['budgetName'] as String;
      final name = data['name'] as String;
      final amount = data['amount'] as int;
      final budgetId = budgetIdMap[budgetName];

      if (budgetId == null) continue;

      final mapKey = '$budgetName::$name';

      // 같은 세부예산이 있는지 확인
      final existing = _subBudgetBox.values.firstWhere(
        (s) => s.budgetId == budgetId && s.name == name && s.year == year && s.month == month,
        orElse: () => SubBudget(id: '', budgetId: '', name: '', amount: 0, year: 0, month: 0),
      );

      if (existing.id.isNotEmpty) {
        subBudgetIdMap[mapKey] = existing.id;
      } else {
        final newSubBudget = SubBudget(
          id: _uuid.v4(),
          budgetId: budgetId,
          name: name,
          amount: amount,
          year: year,
          month: month,
          isRecurring: false,
        );
        await _subBudgetBox.put(newSubBudget.id, newSubBudget);
        subBudgetIdMap[mapKey] = newSubBudget.id;
      }
    }

    // 3. 지출 추가
    for (final data in expenseData) {
      final date = data['date'] as DateTime;
      final budgetName = data['budgetName'] as String;
      final subBudgetName = data['subBudgetName'] as String?;
      final memo = data['memo'] as String?;
      final amount = data['amount'] as int;

      final budgetId = budgetIdMap[budgetName];
      if (budgetId == null) continue;

      String? subBudgetId;
      if (subBudgetName != null) {
        final mapKey = '$budgetName::$subBudgetName';
        subBudgetId = subBudgetIdMap[mapKey];
      }

      final expense = Expense(
        id: _uuid.v4(),
        budgetId: budgetId,
        subBudgetId: subBudgetId,
        amount: amount,
        date: date,
        memo: memo,
      );
      await _expenseBox.put(expense.id, expense);
      importedCount++;
    }

    // 해당 월로 이동
    _currentYear = year;
    _currentMonth = month;

    notifyListeners();
    return importedCount;
  }
}
