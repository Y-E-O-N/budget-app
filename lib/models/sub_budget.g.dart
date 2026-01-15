// =============================================================================
// sub_budget.g.dart - SubBudget 클래스의 Hive 어댑터 (자동 생성 파일)
// =============================================================================
// SubBudget 객체를 Hive 데이터베이스에 저장하고 불러오기 위한 변환기입니다.
// =============================================================================

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sub_budget.dart';

// =============================================================================
// SubBudgetAdapter 클래스
// =============================================================================
class SubBudgetAdapter extends TypeAdapter<SubBudget> {
  
  // typeId: 1 (SubBudget의 고유 번호)
  @override
  final int typeId = 1;

  // ---------------------------------------------------------------------------
  // read() - 저장된 데이터를 SubBudget 객체로 변환
  // ---------------------------------------------------------------------------
  @override
  SubBudget read(BinaryReader reader) {
    // 필드 개수 읽기
    final numOfFields = reader.readByte();
    
    // 모든 필드를 Map으로 읽기
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) 
        reader.readByte(): reader.read(),
    };
    
    // SubBudget 객체 생성 및 반환
    return SubBudget(
      id: fields[0] as String,         // 필드 0: 고유 ID
      budgetId: fields[1] as String,   // 필드 1: 상위 예산 ID
      name: fields[2] as String,       // 필드 2: 세부예산명
      amount: fields[3] as int,        // 필드 3: 금액
      year: fields[4] as int,          // 필드 4: 연도
      month: fields[5] as int,         // 필드 5: 월
      isRecurring: fields[6] as bool,  // 필드 6: 매달 적용 여부
    );
  }

  // ---------------------------------------------------------------------------
  // write() - SubBudget 객체를 바이너리로 저장
  // ---------------------------------------------------------------------------
  @override
  void write(BinaryWriter writer, SubBudget obj) {
    writer
      ..writeByte(7)           // 총 필드 개수: 7개 (Budget보다 1개 많음 - budgetId)
      ..writeByte(0)           // 필드 0번
      ..write(obj.id)          // id 저장
      ..writeByte(1)           // 필드 1번
      ..write(obj.budgetId)    // budgetId 저장 (상위 예산 참조)
      ..writeByte(2)           // 필드 2번
      ..write(obj.name)        // name 저장
      ..writeByte(3)           // 필드 3번
      ..write(obj.amount)      // amount 저장
      ..writeByte(4)           // 필드 4번
      ..write(obj.year)        // year 저장
      ..writeByte(5)           // 필드 5번
      ..write(obj.month)       // month 저장
      ..writeByte(6)           // 필드 6번
      ..write(obj.isRecurring); // isRecurring 저장
  }

  // 해시 코드
  @override
  int get hashCode => typeId.hashCode;

  // 동등성 비교
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubBudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
