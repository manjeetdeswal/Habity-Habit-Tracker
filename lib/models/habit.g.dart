// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      name: fields[0] as String,
      completedDays: (fields[1] as List).cast<DateTime>(),
      currentStreak: fields[2] as int,
      longestStreak: fields[3] == null ? 0 : fields[3] as int,
      description: fields[4] == null ? '' : fields[4] as String,
      colorValue: fields[5] == null ? 4284955319 : fields[5] as int,
      iconCodePoint: fields[6] == null ? 57520 : fields[6] as int,
      isArchived: fields[7] == null ? false : fields[7] as bool,
      goalFrequency: fields[8] == null ? 1 : fields[8] as int,
      goalPeriod: fields[9] == null ? 'daily' : fields[9] as String,
      completionsPerDay: fields[10] == null ? 1 : fields[10] as int,
      reminderTimes: (fields[11] as List).cast<DateTime>(),
      categories: fields[12] == null ? [] : (fields[12] as List).cast<String>(),
      streakGoalInterval: fields[13] == null ? 'None' : fields[13] as String,
      allowExceeding: fields[14] == null ? false : fields[14] as bool,
      reminderDays: fields[15] == null
          ? [1, 2, 3, 4, 5, 6, 7]
          : (fields[15] as List).cast<int>(),
      scheduledStartTime: fields[16] as DateTime?,
      scheduledEndTime: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.completedDays)
      ..writeByte(2)
      ..write(obj.currentStreak)
      ..writeByte(3)
      ..write(obj.longestStreak)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.iconCodePoint)
      ..writeByte(7)
      ..write(obj.isArchived)
      ..writeByte(8)
      ..write(obj.goalFrequency)
      ..writeByte(9)
      ..write(obj.goalPeriod)
      ..writeByte(10)
      ..write(obj.completionsPerDay)
      ..writeByte(11)
      ..write(obj.reminderTimes)
      ..writeByte(12)
      ..write(obj.categories)
      ..writeByte(13)
      ..write(obj.streakGoalInterval)
      ..writeByte(14)
      ..write(obj.allowExceeding)
      ..writeByte(15)
      ..write(obj.reminderDays)
      ..writeByte(16)
      ..write(obj.scheduledStartTime)
      ..writeByte(17)
      ..write(obj.scheduledEndTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
