import 'package:hive/hive.dart';

part 'focus_session.g.dart';

@HiveType(typeId: 3)
class FocusSession extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  int durationInMinutes;

  @HiveField(2)
  String mode;

  // --- NEW: Optional Task Name ---
  @HiveField(3)
  String? taskName;

  FocusSession({
    required this.date,
    required this.durationInMinutes,
    required this.mode,
    this.taskName,
  });
}