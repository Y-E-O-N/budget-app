// =============================================================================
// expense.dart - 지출 데이터 모델
// =============================================================================
// 이 파일은 '지출' 데이터의 구조를 정의합니다.
// 
// 지출이란?
// - 실제로 돈을 쓴 내역입니다
// - 예: 1월 5일 점심 김밥 8,000원
// - 각 지출은 하나의 예산(Budget)에 속하고,
//   선택적으로 세부예산(SubBudget)에도 속할 수 있습니다
// =============================================================================

// Hive 데이터베이스 패키지
import 'package:hive/hive.dart';

// 자동 생성될 어댑터 파일과 연결
part 'expense.g.dart';

// =============================================================================
// Expense 클래스 - 지출 데이터를 담는 그릇
// =============================================================================
// typeId: 2 (Budget은 0, SubBudget은 1)
@HiveType(typeId: 2)
class Expense extends HiveObject {

  // ---------------------------------------------------------------------------
  // 필드 정의
  // ---------------------------------------------------------------------------

  // 고유 식별자 (ID)
  @HiveField(0)
  String id;

  // 상위 예산 ID (필수)
  // - 이 지출이 어떤 예산에서 발생했는지를 나타냅니다
  // - 예: 식비 예산의 ID
  @HiveField(1)
  String budgetId;

  // 세부예산 ID (선택)
  // - 이 지출이 어떤 세부예산에 해당하는지를 나타냅니다
  // - null이면 세부예산 없이 예산에만 연결됩니다
  // - String? : null일 수 있는 문자열 타입
  @HiveField(2)
  String? subBudgetId;

  // 지출 금액 (원 단위)
  @HiveField(3)
  int amount;

  // 지출 날짜
  // - DateTime: 날짜와 시간을 함께 저장하는 타입
  // - 예: 2025년 1월 5일 12시 30분
  @HiveField(4)
  DateTime date;

  // 메모 (선택)
  // - 지출에 대한 간단한 설명
  // - 예: "점심 김밥", "버스비" 등
  // - null이면 메모 없음
  @HiveField(5)
  String? memo;

  // ---------------------------------------------------------------------------
  // 생성자
  // ---------------------------------------------------------------------------
  Expense({
    required this.id,
    required this.budgetId,
    this.subBudgetId,      // 선택 사항 (required 없음)
    required this.amount,
    required this.date,
    this.memo,             // 선택 사항 (required 없음)
  });

  // ---------------------------------------------------------------------------
  // copyWith() 메서드 - 복사 후 일부 값 변경
  // ---------------------------------------------------------------------------
  Expense copyWith({
    String? id,
    String? budgetId,
    String? subBudgetId,
    int? amount,
    DateTime? date,
    String? memo,
  }) {
    return Expense(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      subBudgetId: subBudgetId ?? this.subBudgetId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      memo: memo ?? this.memo,
    );
  }
}
