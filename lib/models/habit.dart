import 'package:hive/hive.dart';
part 'habit.g.dart';

@HiveType(typeId: 0)
class Habit extends HiveObject {

  @HiveField(0) String name;

  @HiveField(1) List<DateTime> completedDays;

  @HiveField(2) int currentStreak;

  @HiveField(3, defaultValue: 0) int longestStreak;

  @HiveField(4, defaultValue: '') String description;

  @HiveField(5, defaultValue: 0xFF673AB7) int colorValue;

  @HiveField(6, defaultValue: 0xe0b0) int iconCodePoint;

  @HiveField(7, defaultValue: false) bool isArchived;

  @HiveField(8, defaultValue: 1) int goalFrequency;

  @HiveField(9, defaultValue: 'daily') String goalPeriod;

  @HiveField(10, defaultValue: 1) int completionsPerDay;

  @HiveField(11) List<DateTime> reminderTimes = [];

  @HiveField(12, defaultValue: [])

  List<String> categories;

  @HiveField(13, defaultValue: 'None')
  String streakGoalInterval;

  @HiveField(14, defaultValue: false)
  bool allowExceeding;

  @HiveField(15, defaultValue: [1, 2, 3, 4, 5, 6, 7]) // 1=Mon, 7=Sun
  List<int> reminderDays;

  @HiveField(16)
  DateTime? scheduledStartTime;

  @HiveField(17)
  DateTime? scheduledEndTime;


  Habit({
    required this.name,
    required this.completedDays,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.description = '',
    this.colorValue = 0xFF673AB7,
    this.iconCodePoint = 0xe0b0,
    this.isArchived = false,
    this.goalFrequency = 1,
    this.goalPeriod = 'daily',
    this.completionsPerDay = 1,
    this.reminderTimes = const[],
    this.categories = const [],
    this.streakGoalInterval = 'None',
    this.allowExceeding = false,
    this.reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduledStartTime ,
    this.scheduledEndTime ,

  });
}