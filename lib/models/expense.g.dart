// =============================================================================
// expense.g.dart - Expense 클래스의 Hive 어댑터 (자동 생성 파일)
// =============================================================================
// Expense 객체를 Hive 데이터베이스에 저장하고 불러오기 위한 변환기입니다.
// =============================================================================

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// =============================================================================
// ExpenseAdapter 클래스
// =============================================================================
class ExpenseAdapter extends TypeAdapter<Expense> {
  
  // typeId: 2 (Expense의 고유 번호)
  @override
  final int typeId = 2;

  // ---------------------------------------------------------------------------
  // read() - 저장된 데이터를 Expense 객체로 변환
  // ---------------------------------------------------------------------------
  @override
  Expense read(BinaryReader reader) {
    // 필드 개수 읽기
    final numOfFields = reader.readByte();
    
    // 모든 필드를 Map으로 읽기
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) 
        reader.readByte(): reader.read(),
    };
    
    // Expense 객체 생성 및 반환
    return Expense(
      id: fields[0] as String,            // 필드 0: 고유 ID
      budgetId: fields[1] as String,      // 필드 1: 상위 예산 ID
      subBudgetId: fields[2] as String?,  // 필드 2: 세부예산 ID (nullable)
      amount: fields[3] as int,           // 필드 3: 지출 금액
      date: fields[4] as DateTime,        // 필드 4: 지출 날짜
      memo: fields[5] as String?,         // 필드 5: 메모 (nullable)
    );
  }

  // ---------------------------------------------------------------------------
  // write() - Expense 객체를 바이너리로 저장
  // ---------------------------------------------------------------------------
  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(6)              // 총 필드 개수: 6개
      ..writeByte(0)              // 필드 0번
      ..write(obj.id)             // id 저장
      ..writeByte(1)              // 필드 1번
      ..write(obj.budgetId)       // budgetId 저장
      ..writeByte(2)              // 필드 2번
      ..write(obj.subBudgetId)    // subBudgetId 저장 (null 가능)
      ..writeByte(3)              // 필드 3번
      ..write(obj.amount)         // amount 저장
      ..writeByte(4)              // 필드 4번
      ..write(obj.date)           // date 저장 (DateTime)
      ..writeByte(5)              // 필드 5번
      ..write(obj.memo);          // memo 저장 (null 가능)
  }

  // 해시 코드
  @override
  int get hashCode => typeId.hashCode;

  // 동등성 비교
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
