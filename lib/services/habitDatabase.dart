// habit_database.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import '../models/habit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';

class HabitDatabase {
  final _myBox = Hive.box<Habit>('habitsBox');

  List<Habit> loadHabits() => _myBox.values.toList();

  void addHabit(String habitName) {
    final newHabit = Habit(name: habitName, completedDays: []);
    _myBox.add(newHabit);
  }


  static Future<void> syncWidgetState(Habit habit) async {


    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    bool isDoneToday = habit.completedDays.any((d) => d.year == today.year && d.month == today.month && d.day == today.day);

    await HomeWidget.saveWidgetData<bool>('habit_${habit.key}_day_0', isDoneToday);

    Map<DateTime, int> dataset = { for (var date in habit.completedDays) DateTime(date.year, date.month, date.day): 1 };


    Widget heatmapWidget = Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 550,
        height: 150,
        padding: const EdgeInsets.all(8.0),
        color: const Color(0xFF1E1E2C),
        alignment: Alignment.center,
        child: HeatMap(
          datasets: dataset,
          colorMode: ColorMode.opacity,
          showText: false,
          scrollable: false,
          size: 10,
          showColorTip: false,
          margin: const EdgeInsets.all(2),
          startDate: today.subtract(const Duration(days: 180)),
          endDate: today,
          colorsets: {1: Color(habit.colorValue)},
          defaultColor: const Color(0xFF2A2D43),
          textColor: Colors.white54,
        ),
      ),
    );

    // --- THE FIX: Use the reliable Screenshot package instead of renderFlutterWidget ---
    try {

      ScreenshotController screenshotController = ScreenshotController();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/habit_${habit.key}_heatmap.png';


      final capturedImage = await screenshotController.captureFromWidget(
        heatmapWidget,
        delay: const Duration(milliseconds: 100),
        targetSize: const Size(550, 150),
      );


      File file = File(imagePath);
      await file.writeAsBytes(capturedImage);


      await HomeWidget.saveWidgetData<String>('habit_${habit.key}_heatmap', imagePath);


    } catch (e) {

    }

    // Tell Android to update
    await HomeWidget.updateWidget(name: 'FitdyWidgetProvider');

  }

  Future<void> updateAndroidWidget() async {
    final box = Hive.box<Habit>('habitsBox');
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);


    List<Habit> pendingHabits = box.values.where((h) => !h.completedDays.contains(today)).toList();


    for (int i = 0; i < 3; i++) {
      if (i < pendingHabits.length) {
        await HomeWidget.saveWidgetData<String>('habit_${i}_text', pendingHabits[i].name);
        await HomeWidget.saveWidgetData<int>('habit_${i}_id', pendingHabits[i].key);
        await HomeWidget.saveWidgetData<bool>('habit_${i}_visible', true);
      } else {
        await HomeWidget.saveWidgetData<bool>('habit_${i}_visible', false); // Hide unused slots
      }
    }


    await HomeWidget.updateWidget(name: 'FitdyWidgetProvider');
  }


  void addCustomHabit({
    required String name,
    required String description,
    required int colorValue,
    required int iconCodePoint,
    int completionsPerDay = 1,
    List<DateTime> reminderTimes = const [],
    List<String> categories = const [],
    String streakGoalInterval = 'None',
    bool allowExceeding = false,
    List<int> reminderDays = const [1,2,3,4,5,6,7],
    bool useIndividualGrid = false,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
  }) {
    final newHabit = Habit(
      name: name,
      completedDays: [],
      description: description,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      completionsPerDay: completionsPerDay,
      reminderTimes: reminderTimes,
      categories: categories,
      streakGoalInterval: streakGoalInterval,
      allowExceeding: allowExceeding,
      reminderDays: reminderDays,
      scheduledStartTime: scheduledStartTime,
      scheduledEndTime: scheduledEndTime

    );
    _myBox.add(newHabit);
  }

  void deleteHabit(Habit habit) {
    habit.delete();
  }

  void toggleHabit(Habit habit, bool isCompleted) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (isCompleted) {
      if (!habit.completedDays.contains(today)) {
        habit.completedDays.add(today);
      }
    } else {
      habit.completedDays.remove(today);
    }

    _calculateStreak(habit);
    habit.save();
  }


  // NEW: Toggle a specific date (used for the Compact Week View)
  void toggleHabitForDate(Habit habit, DateTime date, bool isCompleted) {
    if (isCompleted) {
      bool exists = habit.completedDays.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      if (!exists) {
        habit.completedDays.add(DateTime(date.year, date.month, date.day));
      }
    } else {
      habit.completedDays.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
    }

    _calculateStreak(habit);
    habit.save();

    // --- CRUCIAL: Tell the widget to generate the image! ---
    syncWidgetState(habit);
  }

  // Helper function (Make sure this is inside your HabitDatabase class!)

  void _calculateStreak(Habit habit) {
    if (habit.completedDays.isEmpty) {
      habit.currentStreak = 0;
      return;
    }

    habit.completedDays.sort((a, b) => b.compareTo(a));

    int current = 0;
    int maxStreak = 0;
    int tempStreak = 0;

    DateTime checkDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (var date in habit.completedDays) {
      if (date.isAtSameMomentAs(checkDate)) {
        current++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    habit.currentStreak = current;

    if (habit.completedDays.isNotEmpty) {
      tempStreak = 1;
      maxStreak = 1;
      for (int i = 0; i < habit.completedDays.length - 1; i++) {
        final currentDay = habit.completedDays[i];
        final previousDay = habit.completedDays[i + 1];

        if (currentDay.difference(previousDay).inDays == 1) {
          tempStreak++;
        } else {
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          tempStreak = 1;
        }
      }
      if (tempStreak > maxStreak) maxStreak = tempStreak;
    }

    habit.longestStreak = maxStreak;
  }
}