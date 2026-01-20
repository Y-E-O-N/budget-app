// =============================================================================
// budget.g.dart - Budget 클래스의 Hive 어댑터 (자동 생성 파일)
// =============================================================================
// 이 파일은 원래 build_runner가 자동으로 생성하는 파일입니다.
// 명령어: flutter pub run build_runner build
// 
// 여기서는 미리 작성해두어 build_runner 없이도 바로 사용할 수 있게 했습니다.
// 
// 어댑터(Adapter)란?
// - Budget 객체 ↔ Hive가 이해하는 바이너리 데이터 간의 변환기
// - 저장할 때: Budget → 바이너리 데이터 (write)
// - 불러올 때: 바이너리 데이터 → Budget (read)
// =============================================================================

// 주의: 이 파일을 직접 수정하지 마세요!
// GENERATED CODE - DO NOT MODIFY BY HAND

// part of: 이 파일이 budget.dart의 일부임을 선언
// - budget.dart의 'part' 지시문과 짝을 이룹니다
part of 'budget.dart';

// =============================================================================
// BudgetAdapter 클래스 - Budget을 Hive에 저장/불러오는 어댑터
// =============================================================================
// TypeAdapter<Budget>: Budget 타입 전용 어댑터임을 명시
class BudgetAdapter extends TypeAdapter<Budget> {
  
  // ---------------------------------------------------------------------------
  // typeId - 이 어댑터의 고유 식별 번호
  // ---------------------------------------------------------------------------
  // - Budget 클래스의 @HiveType(typeId: 0)과 일치해야 합니다
  // - 다른 어댑터와 중복되면 안 됩니다
  @override
  final int typeId = 0;

  // ---------------------------------------------------------------------------
  // read() 메서드 - 저장된 데이터를 Budget 객체로 변환
  // ---------------------------------------------------------------------------
  // BinaryReader: Hive가 저장한 바이너리 데이터를 읽는 도구
  // 반환값: 읽어온 데이터로 만든 Budget 객체
  @override
  Budget read(BinaryReader reader) {
    // 필드 개수 읽기
    // - 저장할 때 몇 개의 필드를 저장했는지 먼저 기록해둡니다
    final numOfFields = reader.readByte();
    
    // 필드들을 Map으로 읽어오기
    // - 키: 필드 번호 (0, 1, 2, ...)
    // - 값: 해당 필드의 데이터
    final fields = <int, dynamic>{
      // for 루프로 모든 필드를 읽어서 Map에 저장
      for (int i = 0; i < numOfFields; i++) 
        reader.readByte(): reader.read(),
        // readByte(): 필드 번호 읽기
        // read(): 필드 값 읽기
    };
    
    // 읽어온 데이터로 Budget 객체 생성
    return Budget(
      id: fields[0] as String,         // 필드 0번 = id
      name: fields[1] as String,       // 필드 1번 = name
      amount: fields[2] as int,        // 필드 2번 = amount
      year: fields[3] as int,          // 필드 3번 = year
      month: fields[4] as int,         // 필드 4번 = month
      isRecurring: fields[5] as bool,  // 필드 5번 = isRecurring
      order: (fields[6] as int?) ?? 0, // 필드 6번 = order (#3: 순서, 기존 데이터 호환)
    );
  }

  // ---------------------------------------------------------------------------
  // write() 메서드 - Budget 객체를 바이너리 데이터로 저장
  // ---------------------------------------------------------------------------
  // BinaryWriter: 바이너리 데이터를 쓰는 도구
  // obj: 저장할 Budget 객체
  @override
  void write(BinaryWriter writer, Budget obj) {
    // 캐스케이드 연산자 (..) 사용
    // - 같은 객체에 여러 메서드를 연속으로 호출할 때 사용
    // - writer.writeByte(6); writer.writeByte(0); ... 와 같은 의미
    writer
      ..writeByte(7)        // 총 필드 개수: 7개 (#3: order 추가)
      ..writeByte(0)        // 필드 0번 표시
      ..write(obj.id)       // id 값 저장
      ..writeByte(1)        // 필드 1번 표시
      ..write(obj.name)     // name 값 저장
      ..writeByte(2)        // 필드 2번 표시
      ..write(obj.amount)   // amount 값 저장
      ..writeByte(3)        // 필드 3번 표시
      ..write(obj.year)     // year 값 저장
      ..writeByte(4)        // 필드 4번 표시
      ..write(obj.month)    // month 값 저장
      ..writeByte(5)        // 필드 5번 표시
      ..write(obj.isRecurring)  // isRecurring 값 저장
      ..writeByte(6)        // 필드 6번 표시 (#3: 순서)
      ..write(obj.order);   // order 값 저장
  }

  // ---------------------------------------------------------------------------
  // hashCode - 객체의 해시 코드 (고유 숫자값)
  // ---------------------------------------------------------------------------
  // - typeId를 기반으로 해시 코드 생성
  // - Map이나 Set에서 객체를 빠르게 찾을 때 사용됩니다
  @override
  int get hashCode => typeId.hashCode;

  // ---------------------------------------------------------------------------
  // == 연산자 - 두 어댑터가 같은지 비교
  // ---------------------------------------------------------------------------
  // identical: 메모리상 같은 객체인지 확인
  // runtimeType: 실행 시점의 타입 확인
  // typeId: 어댑터 번호가 같은지 확인
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||  // 완전히 같은 객체이거나
      other is BudgetAdapter &&  // 다른 객체가 BudgetAdapter이고
          runtimeType == other.runtimeType &&  // 타입이 같고
          typeId == other.typeId;  // typeId가 같으면 동일하다고 판단
}
