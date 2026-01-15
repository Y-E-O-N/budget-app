// =============================================================================
// recurring_expense.g.dart - RecurringExpense 클래스의 Hive 어댑터
// =============================================================================
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_expense.dart';

// =============================================================================
// RepeatTypeAdapter - 반복 주기 enum 어댑터
// =============================================================================
class RepeatTypeAdapter extends TypeAdapter<RepeatType> {
  @override
  final int typeId = 4;

  @override
  RepeatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatType.weekly;
      case 1:
        return RepeatType.monthly;
      default:
        return RepeatType.monthly;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatType obj) {
    switch (obj) {
      case RepeatType.weekly:
        writer.writeByte(0);
        break;
      case RepeatType.monthly:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// =============================================================================
// RecurringExpenseAdapter - 반복 지출 어댑터
// =============================================================================
class RecurringExpenseAdapter extends TypeAdapter<RecurringExpense> {
  @override
  final int typeId = 3;

  @override
  RecurringExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringExpense(
      id: fields[0] as String,
      budgetId: fields[1] as String,
      subBudgetId: fields[2] as String?,
      amount: fields[3] as int,
      memo: fields[4] as String?,
      repeatType: fields[5] as RepeatType,
      dayOfWeek: fields[6] as int?,
      dayOfMonth: fields[7] as int?,
      isActive: fields[8] as bool,
      createdAt: fields[9] as DateTime,
      lastGeneratedDate: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringExpense obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.budgetId)
      ..writeByte(2)
      ..write(obj.subBudgetId)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.memo)
      ..writeByte(5)
      ..write(obj.repeatType)
      ..writeByte(6)
      ..write(obj.dayOfWeek)
      ..writeByte(7)
      ..write(obj.dayOfMonth)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.lastGeneratedDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
