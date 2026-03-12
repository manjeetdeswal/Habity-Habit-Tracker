import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 2)
class Note extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String content;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  bool isPinned;

  @HiveField(4)
  DateTime updatedAt;

  Note({
    required this.title,
    required this.content,
    required this.colorValue,
    this.isPinned = false,
    required this.updatedAt,
  });
}