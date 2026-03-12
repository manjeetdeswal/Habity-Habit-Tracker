import 'package:hive/hive.dart';

part 'todo.g.dart';

@HiveType(typeId: 1)
class Todo extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  bool isCompleted;

  @HiveField(2)
  DateTime createdAt;

  // --- NEW PRO FEATURES ---
  @HiveField(3)
  String description;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5, defaultValue: 0)
  int priority; // 0: None, 1: Low (Blue), 2: Medium (Orange), 3: High (Red)

  Todo({
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.description = '',
    this.dueDate,
    this.priority = 0,
  });
}