// =============================================================================
// recurring_expense.dart - 반복 지출 데이터 모델
// =============================================================================
import 'package:hive/hive.dart';

part 'recurring_expense.g.dart';

// 반복 주기 타입
@HiveType(typeId: 4)
enum RepeatType {
  @HiveField(0)
  weekly,   // 매주
  @HiveField(1)
  monthly,  // 매월
}

// =============================================================================
// RecurringExpense 클래스 - 반복 지출 데이터
// =============================================================================
@HiveType(typeId: 3)
class RecurringExpense extends HiveObject {
  // 고유 식별자
  @HiveField(0)
  String id;

  // 상위 예산 ID
  @HiveField(1)
  String budgetId;

  // 세부예산 ID (선택)
  @HiveField(2)
  String? subBudgetId;

  // 지출 금액
  @HiveField(3)
  int amount;

  // 메모
  @HiveField(4)
  String? memo;

  // 반복 주기 (weekly/monthly)
  @HiveField(5)
  RepeatType repeatType;

  // 요일 (0=월, 1=화, ..., 6=일) - weekly일 때 사용
  @HiveField(6)
  int? dayOfWeek;

  // 일자 (1-31) - monthly일 때 사용
  @HiveField(7)
  int? dayOfMonth;

  // 활성화 여부
  @HiveField(8)
  bool isActive;

  // 생성일
  @HiveField(9)
  DateTime createdAt;

  // 마지막 지출 생성일 (중복 방지용)
  @HiveField(10)
  DateTime? lastGeneratedDate;

  RecurringExpense({
    required this.id,
    required this.budgetId,
    this.subBudgetId,
    required this.amount,
    this.memo,
    required this.repeatType,
    this.dayOfWeek,
    this.dayOfMonth,
    this.isActive = true,
    required this.createdAt,
    this.lastGeneratedDate,
  });

  // 복사 메서드
  RecurringExpense copyWith({
    String? id,
    String? budgetId,
    String? subBudgetId,
    int? amount,
    String? memo,
    RepeatType? repeatType,
    int? dayOfWeek,
    int? dayOfMonth,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastGeneratedDate,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      subBudgetId: subBudgetId ?? this.subBudgetId,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      repeatType: repeatType ?? this.repeatType,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
    );
  }

  // 오늘이 지출 생성 날인지 확인
  bool shouldGenerateToday() {
    if (!isActive) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 이미 오늘 생성됐으면 스킵
    if (lastGeneratedDate != null) {
      final lastDate = DateTime(
        lastGeneratedDate!.year,
        lastGeneratedDate!.month,
        lastGeneratedDate!.day,
      );
      if (lastDate == today) return false;
    }

    if (repeatType == RepeatType.weekly) {
      // 오늘 요일이 설정된 요일과 같은지 (DateTime.weekday: 1=월, 7=일)
      final todayWeekday = now.weekday - 1; // 0=월, 6=일로 변환
      return todayWeekday == dayOfWeek;
    } else {
      // 매월: 오늘 일자가 설정된 일자와 같은지
      // dayOfMonth가 null이면 생성하지 않음
      if (dayOfMonth == null) return false;
      // 월말 처리: 설정일이 현재 월의 마지막 일보다 크면 마지막 일에 생성
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
      final targetDay = (dayOfMonth! > lastDayOfMonth) ? lastDayOfMonth : dayOfMonth!;
      return now.day == targetDay;
    }
  }
}
