// =============================================================================
// sub_budget.dart - 세부예산 데이터 모델
// =============================================================================
// 이 파일은 '세부예산' 데이터의 구조를 정의합니다.
// 
// 세부예산이란?
// - 상위 예산(Budget)을 더 세분화한 항목입니다
// - 예: 식비(Budget) → 점심 15만원, 저녁 10만원, 간식 5만원 (SubBudget들)
// =============================================================================

// Hive 데이터베이스 패키지
import 'package:hive/hive.dart';

// 자동 생성될 어댑터 파일과 연결
part 'sub_budget.g.dart';

// =============================================================================
// SubBudget 클래스 - 세부예산 데이터를 담는 그릇
// =============================================================================
// typeId: 1 (Budget은 0, Expense는 2)
@HiveType(typeId: 1)
class SubBudget extends HiveObject {

  // ---------------------------------------------------------------------------
  // 필드 정의
  // ---------------------------------------------------------------------------

  // 고유 식별자 (ID)
  // - 각 세부예산을 구분하기 위한 고유한 문자열
  @HiveField(0)
  String id;

  // 상위 예산 ID
  // - 이 세부예산이 어떤 예산(Budget)에 속하는지를 나타냅니다
  // - 예: 식비 예산의 ID가 "abc123"이면, 그 아래의 점심/저녁/간식은
  //       모두 budgetId가 "abc123"입니다
  @HiveField(1)
  String budgetId;

  // 세부예산 이름
  // - 예: "점심", "저녁", "간식" 등
  @HiveField(2)
  String name;

  // 세부예산 금액 (원 단위)
  // - 예: 150000 (15만원)
  @HiveField(3)
  int amount;

  // 연도
  // - 이 세부예산이 속한 연도
  @HiveField(4)
  int year;

  // 월
  // - 이 세부예산이 속한 월 (1~12)
  @HiveField(5)
  int month;

  // 매달 적용 여부
  // - true: 상위 예산이 다음 달로 복사될 때 이 세부예산도 함께 복사됨
  // - false: 이번 달에만 적용
  @HiveField(6)
  bool isRecurring;

  // ---------------------------------------------------------------------------
  // 생성자
  // ---------------------------------------------------------------------------
  SubBudget({
    required this.id,
    required this.budgetId,  // 상위 예산 ID는 필수!
    required this.name,
    required this.amount,
    required this.year,
    required this.month,
    this.isRecurring = false,  // 기본값: 매달 적용 안 함
  });

  // ---------------------------------------------------------------------------
  // copyWith() 메서드 - 복사 후 일부 값 변경
  // ---------------------------------------------------------------------------
  SubBudget copyWith({
    String? id,
    String? budgetId,
    String? name,
    int? amount,
    int? year,
    int? month,
    bool? isRecurring,
  }) {
    return SubBudget(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      year: year ?? this.year,
      month: month ?? this.month,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }
}
