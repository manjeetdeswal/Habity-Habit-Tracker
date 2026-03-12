import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:home_widget/home_widget.dart';

import '../models/habit.dart';
import '../services/habitDatabase.dart';
import '../services/notification_service.dart';

import 'create_habit_screen.dart';
import 'global_reminders_screen.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import '../screens/DailyScheduleScreen.dart';
import 'todo_screen.dart';
import 'notes_screen.dart';
import 'focus_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HabitDatabase db = HabitDatabase();
  final _settingsBox = Hive.box('settingsBox');

  late int _viewMode;
  late int _daysToShow;

  // NEW: Track the active tab for the Bottom Navigation Bar
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _viewMode = _settingsBox.get('viewMode', defaultValue: 1);
    int savedDays = _getSavedDurationForView(_viewMode);

    HomeWidget.widgetClicked.listen(_handleWidgetClick);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetClick);

    if (_viewMode == 0 && ![7, 14, 21, 30, 60].contains(savedDays)) savedDays = 30;
    if (_viewMode == 2 && ![5, 7, 14].contains(savedDays)) savedDays = 7;
    if (_viewMode == 1 && ![30, 60, 90, 180, 365, 540].contains(savedDays)) savedDays = 60;

    _daysToShow = savedDays;
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;
    if (uri.host == 'configure') {
      int widgetId = int.parse(uri.queryParameters['widgetId'] ?? '-1');
      if (widgetId != -1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _showWidgetConfigurationSheet(widgetId);
        });
      }
    }
  }

  void _showWidgetConfigurationSheet(int widgetId) {
    final habits = Hive.box<Habit>('habitsBox').values.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
        context: context,
        backgroundColor: isDark ? const Color(0xFF121421) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select a Habit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ...habits.map((habit) => ListTile(
                    leading: Icon(IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'), color: Color(habit.colorValue)),
                    title: Text(habit.name),
                    onTap: () async {
                      await HomeWidget.saveWidgetData<int>('widget_${widgetId}_id', habit.key);
                      await HomeWidget.saveWidgetData<String>('widget_${widgetId}_name', habit.name);
                      await HabitDatabase.syncWidgetState(habit);
                      if (mounted) Navigator.pop(context);
                    }
                ))
              ],
            ),
          );
        }
    );
  }

  void _onReorder(int oldIndex, int newIndex, List<Habit> currentHabits) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Habit item = currentHabits.removeAt(oldIndex);
      currentHabits.insert(newIndex, item);
      List<int> newOrder = currentHabits.map((h) => h.key as int).toList();
      _settingsBox.put('habitOrder', newOrder);
    });
  }

  Widget _dragDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = 1.0 + (0.05 * animValue);
        final double elevation = 12.0 * animValue;
        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: elevation,
            color: Colors.transparent,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  int _getSavedDurationForView(int mode) {
    if (mode == 0) return _settingsBox.get('gridDays', defaultValue: 21);
    if (mode == 2) return _settingsBox.get('compactDays', defaultValue: 5);
    return _settingsBox.get('listDays', defaultValue: 60);
  }

  void _saveViewSettings(int mode, int days) {
    _settingsBox.put('viewMode', mode);
    if (mode == 0) _settingsBox.put('gridDays', days);
    else if (mode == 2) _settingsBox.put('compactDays', days);
    else _settingsBox.put('listDays', days);
  }

  void _showHabitDetails(BuildContext context, Habit habit, Color habitColor, Color textColor, Color cardColor, bool isDark) {
    DateTime focusedDay = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF121421) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'), color: habitColor, size: 30),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      habit.name,
                                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (habit.description.isNotEmpty)
                                      Text(
                                        habit.description,
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.topRight,
                            icon: Icon(Icons.close, color: textColor),
                            onPressed: () => Navigator.pop(context)
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text(habit.streakGoalInterval == 'None' ? 'No Streak Goal' : 'Goal: ${habit.streakGoalInterval}', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [Text('🔥 ', style: TextStyle(color: habitColor)), Text('${habit.currentStreak}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))]),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CreateHabitScreen(existingHabit: habit)));
                          },
                          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.edit, color: textColor, size: 20)),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Share.share('I am tracking "${habit.name}" on Habity! Currently on a ${habit.currentStreak} day streak! 🔥');
                          },
                          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.share, color: textColor, size: 20)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: focusedDay,
                      daysOfWeekHeight: 32.0,
                      onDaySelected: (selectedDay, newFocusedDay) {
                        final allowPast = Hive.box('settingsBox').get('allowPastEdits', defaultValue: true);
                        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                        final normalizedTap = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

                        if (!allowPast && normalizedTap.isBefore(today)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Editing past days is disabled in Settings.')));
                          return;
                        }

                        bool isDone = habit.completedDays.any((d) => d.year == selectedDay.year && d.month == selectedDay.month && d.day == selectedDay.day);
                        db.toggleHabitForDate(habit, selectedDay, !isDone);
                        setModalState(() { focusedDay = newFocusedDay; });
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(color: textColor, fontSize: 16),
                        leftChevronIcon: Icon(Icons.chevron_left, color: textColor), rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: TextStyle(color: Colors.grey.shade600), weekendStyle: TextStyle(color: Colors.grey.shade600)),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: TextStyle(color: textColor), weekendTextStyle: TextStyle(color: textColor),
                        todayDecoration: BoxDecoration(color: habitColor.withOpacity(0.3), shape: BoxShape.circle),
                        todayTextStyle: TextStyle(color: habitColor, fontWeight: FontWeight.bold),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          bool isDone = habit.completedDays.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);
                          if (isDone) {
                            return Container(
                              margin: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            );
                          }
                          return null;
                        },
                        todayBuilder: (context, day, focusedDay) {
                          bool isDone = habit.completedDays.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);
                          if (isDone) {
                            return Container(
                              margin: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildCompactHabitRow(Habit habit, Color habitColor, Color cardColor, Color textColor, bool isDark, List<DateTime> dates) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _showHabitDetails(context, habit, habitColor, textColor, cardColor, isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'), color: habitColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(habit.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: dates.map((date) {
                bool isDone = habit.completedDays.contains(date);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final allowPast = Hive.box('settingsBox').get('allowPastEdits', defaultValue: true);
                      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                      final normalizedTap = DateTime(date.year, date.month, date.day);

                      if (!allowPast && normalizedTap.isBefore(today)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Editing past days is disabled in Settings.')));
                        return;
                      }
                      db.toggleHabitForDate(habit, date, !isDone);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 28,
                      decoration: BoxDecoration(
                          color: isDone ? habitColor : (isDark ? Colors.white10 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6)
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStandardHabitCard(Habit habit, bool isDoneToday, Color habitColor, Color cardColor, Color textColor, bool isDark, Map<DateTime, int> dataset) {
    bool isGrid = _viewMode == 0;
    return Dismissible(
      key: Key(habit.key.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        final String name = habit.name;
        final String desc = habit.description;
        final int colorValue = habit.colorValue;
        final int iconCodePoint = habit.iconCodePoint;
        final List<DateTime> completedDays = habit.completedDays.toList();
        final int completionsPerDay = habit.completionsPerDay;
        final List<DateTime> reminderTimes = habit.reminderTimes.toList();
        final List<String> categories = habit.categories.toList();
        final String streakGoalInterval = habit.streakGoalInterval;
        final bool allowExceeding = habit.allowExceeding;
        final List<int> reminderDays = habit.reminderDays.toList();
        final int oldKey = habit.key;

        NotificationService.cancelHabitReminder(oldKey);
        db.deleteHabit(habit);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$name"'),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFF673AB7),
              onPressed: () {
                final restoredHabit = Habit(
                  name: name,
                  description: desc,
                  colorValue: colorValue,
                  iconCodePoint: iconCodePoint,
                  completedDays: completedDays,
                  completionsPerDay: completionsPerDay,
                  reminderTimes: reminderTimes,
                  categories: categories,
                  streakGoalInterval: streakGoalInterval,
                  allowExceeding: allowExceeding,
                  reminderDays: reminderDays,
                );

                Hive.box<Habit>('habitsBox').add(restoredHabit);

                if (reminderTimes.isNotEmpty) {
                  final List<TimeOfDay> timesOfDay = reminderTimes.map((dt) => TimeOfDay(hour: dt.hour, minute: dt.minute)).toList();
                  NotificationService.scheduleHabitReminder(restoredHabit.key, restoredHabit.name, timesOfDay, reminderDays);
                }
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showHabitDetails(context, habit, habitColor, textColor, cardColor, isDark),
        child: Container(
          margin: isGrid ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(isGrid ? 12 : 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isGrid ? 6 : 10),
                    decoration: BoxDecoration(color: isDark ? habitColor.withOpacity(0.2) : habitColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'), color: habitColor, size: isGrid ? 20 : 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.name, style: TextStyle(fontSize: isGrid ? 15 : 16, fontWeight: FontWeight.bold, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (habit.description.isNotEmpty && !isGrid)
                          Text(habit.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => db.toggleHabit(habit, !isDoneToday),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isDoneToday ? habitColor : (isDark ? Colors.white10 : Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.check, color: isDoneToday ? Colors.white : (isDark ? Colors.white30 : Colors.grey.shade400), size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Builder(
                  builder: (context) {
                    Widget heatMapWidget = FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 45.0, right: 20.0, top: 12.0, bottom: 12.0),
                        child: HeatMap(
                          datasets: dataset,
                          colorMode: ColorMode.opacity,
                          showText: false,
                          scrollable: false,
                          size: isGrid ? 20 : 16,
                          fontSize: 12,
                          showColorTip: !isGrid,
                          margin: const EdgeInsets.all(3),
                          startDate: DateTime.now().subtract(Duration(days: _daysToShow)),
                          endDate: DateTime.now(),
                          colorsets: {1: habitColor},
                          defaultColor: isDark ? const Color(0xFF2A2D43) : Colors.grey.shade200,
                          textColor: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    );
                    return isGrid ? Expanded(child: heatMapWidget) : heatMapWidget;
                  }
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: The Today's Progress widget logic
  Widget _buildTodayProgress(List<Habit> habits, Color textColor, Color cardColor) {
    if (habits.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    int completedCount = habits.where((h) {
      return h.completedDays.any((d) => d.year == now.year && d.month == now.month && d.day == now.day);
    }).length;

    double progress = completedCount / habits.length;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10, top: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Progress", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              Text("$completedCount / ${habits.length}", style: const TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: const Color(0xFF673AB7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDonationURL() async {
    final Uri url = Uri.parse('https://www.patreon.com/cw/UnrealComponent');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open donation link')),
        );
      }
    }
  }

  List<DropdownMenuItem<int>> _getDropdownItems() {
    if (_viewMode == 0) {
      return const [
        DropdownMenuItem(value: 7, child: Text('Last 1 Week')),
        DropdownMenuItem(value: 14, child: Text('Last 2 Weeks')),
        DropdownMenuItem(value: 21, child: Text('Last 3 Weeks')),
        DropdownMenuItem(value: 30, child: Text('Last 1 Month')),
        DropdownMenuItem(value: 60, child: Text('Last 2 Months')),
      ];
    } else if (_viewMode == 2) {
      return const [
        DropdownMenuItem(value: 5, child: Text('Last 5 Days')),
        DropdownMenuItem(value: 7, child: Text('Last 1 Week')),
        DropdownMenuItem(value: 14, child: Text('Last 2 Weeks')),
      ];
    } else {
      return const [
        DropdownMenuItem(value: 30, child: Text('Last 1 Month')),
        DropdownMenuItem(value: 60, child: Text('Last 2 Months')),
        DropdownMenuItem(value: 90, child: Text('Last 3 Months')),
        DropdownMenuItem(value: 180, child: Text('Last 6 Months')),
        DropdownMenuItem(value: 365, child: Text('Last 12 Months')),
        DropdownMenuItem(value: 540, child: Text('Last 18 Months')),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = Theme.of(context).cardColor;

    List<DateTime> compactDates = [];
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (int i = _daysToShow - 1; i >= 0; i--) compactDates.add(today.subtract(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.bar_chart_rounded, color: textColor, size: 28),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatisticsScreen())),
        ),
        title: Text('Habity', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            tooltip: 'Support Habity',
            onPressed: _launchDonationURL,
          ),
          IconButton(icon: Icon(Icons.notifications_none, color: textColor), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GlobalRemindersScreen()))),
          IconButton(icon: Icon(Icons.settings, color: textColor), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())))
        ],
      ),

      // NEW: Bottom Navigation Bar to swap between List and Schedule
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: isFocusFullscreen, // This comes from focus_screen.dart
        builder: (context, isFullscreen, child) {
          if (isFullscreen) return const SizedBox.shrink(); // Hides the bar!

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? const Color(0xFF121421) : Colors.white,
            selectedItemColor: const Color(0xFF673AB7),
            unselectedItemColor: Colors.grey.shade500,
            showUnselectedLabels: false,
            elevation: 10,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.task_alt_rounded), label: 'Habits'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_view_day_rounded), label: 'Schedule'),
              BottomNavigationBarItem(icon: Icon(Icons.checklist_rtl_rounded), label: 'To-Do'),
              BottomNavigationBarItem(icon: Icon(Icons.sticky_note_2_rounded), label: 'Notes'),
              BottomNavigationBarItem(icon: Icon(Icons.hourglass_bottom_rounded), label: 'Focus'),
            ],
          );
        },
      ),

      // NEW: Only show Floating Action Button when on the Habits Tab
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 2 || _currentIndex == 3)
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF673AB7), foregroundColor: Colors.white,
        onPressed: () {
          if (_currentIndex == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateHabitScreen()));
          } else if (_currentIndex == 2) {
            TodoScreenState.showTaskSheet(context);
          } else if (_currentIndex == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NoteEditorScreen()));
          }
        },
        child: const Icon(Icons.add),
      )
          : null,

      // NEW: Indexed Stack lets you switch tabs instantly without losing state
      body: IndexedStack(
        index: _currentIndex,
        children: [

          // TAB 0: Your existing Column holding the Habits View
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: _daysToShow,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                        underline: const SizedBox(),
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down, color: textColor, size: 20),
                        items: _getDropdownItems(),
                        onChanged: (val) {
                          setState(() {
                            _daysToShow = val!;
                            _saveViewSettings(_viewMode, _daysToShow);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SegmentedButton<int>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: isDark ? Colors.transparent : Colors.white,
                        selectedBackgroundColor: const Color(0xFF673AB7).withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      segments: const [
                        ButtonSegment(value: 0, icon: Icon(Icons.grid_view_rounded, size: 18)),
                        ButtonSegment(value: 1, icon: Icon(Icons.view_list_rounded, size: 18)),
                        ButtonSegment(value: 2, icon: Icon(Icons.view_week_rounded, size: 18)),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() {
                          _viewMode = newSelection.first;
                          int savedDays = _getSavedDurationForView(_viewMode);
                          if (_viewMode == 0 && ![7, 14, 21, 30, 60].contains(savedDays)) savedDays = 30;
                          if (_viewMode == 2 && ![5, 7, 14].contains(savedDays)) savedDays = 7;
                          if (_viewMode == 1 && ![30, 60, 90, 180, 365, 540].contains(savedDays)) savedDays = 60;
                          _daysToShow = savedDays;
                          _saveViewSettings(_viewMode, _daysToShow);
                        });
                      },
                    ),
                  ],
                ),
              ),

              if (_viewMode == 2)
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 4),
                      child: Row(
                        children: [
                          const Expanded(flex: 2, child: SizedBox()),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: compactDates.map((d) => Expanded(
                                child: Column(
                                  children: [
                                    Text(DateFormat('E').format(d).substring(0,2), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    Text('${d.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                                  ],
                                ),
                              )).toList(),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: ValueListenableBuilder<Box<Habit>>(
                  valueListenable: Hive.box<Habit>('habitsBox').listenable(),
                  builder: (context, box, _) {
                    if (box.values.isEmpty) {
                      return Center(child: Text('No habits yet. Add one!', style: TextStyle(color: textColor)));
                    }

                    List<Habit> habits = box.values.toList();
                    List<int> savedOrder = (_settingsBox.get('habitOrder', defaultValue: <int>[]) as List).cast<int>();
                    habits.sort((a, b) {
                      int indexA = savedOrder.indexOf(a.key);
                      int indexB = savedOrder.indexOf(b.key);
                      if (indexA == -1 && indexB == -1) return 0;
                      if (indexA == -1) return 1;
                      if (indexB == -1) return -1;
                      return indexA.compareTo(indexB);
                    });

                    // NEW: Insert the Daily Progress Tracker right here!
                    return Column(
                      children: [
                        _buildTodayProgress(habits, textColor, cardColor),

                        Expanded(
                          child: Builder(
                              builder: (context) {
                                if (_viewMode == 0) {
                                  return ReorderableGridView.builder(
                                    padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: MediaQuery.of(context).size.width > 1400 ? 5 : (MediaQuery.of(context).size.width > 1000 ? 4 : (MediaQuery.of(context).size.width > 700 ? 3 : 2)),
                                      mainAxisExtent: 280,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: habits.length,
                                    onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, habits),
                                    dragWidgetBuilder: (index, child) {
                                      return Material(
                                        elevation: 12.0,
                                        color: Colors.transparent,
                                        shadowColor: Colors.black54,
                                        borderRadius: BorderRadius.circular(16),
                                        child: Transform.scale(scale: 1.05, child: child),
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      final habit = habits[index];
                                      final isDoneToday = habit.completedDays.contains(today);
                                      Map<DateTime, int> dataset = { for (var date in habit.completedDays) DateTime(date.year, date.month, date.day): 1 };
                                      return ReorderableDelayedDragStartListener(
                                        index: index, key: Key('grid_${habit.key}'),
                                        child: _buildStandardHabitCard(habit, isDoneToday, Color(habit.colorValue), cardColor, textColor, isDark, dataset),
                                      );
                                    },
                                  );
                                }

                                if (_viewMode == 2) {
                                  return ReorderableListView.builder(
                                    proxyDecorator: _dragDecorator,
                                    buildDefaultDragHandles: false,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    itemCount: habits.length,
                                    onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, habits),
                                    itemBuilder: (context, index) {
                                      final habit = habits[index];
                                      return ReorderableDelayedDragStartListener(
                                        index: index, key: Key('compact_${habit.key}'),
                                        child: _buildCompactHabitRow(habit, Color(habit.colorValue), cardColor, textColor, isDark, compactDates),
                                      );
                                    },
                                  );
                                }

                                return Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 800),
                                    child: ReorderableListView.builder(
                                      proxyDecorator: _dragDecorator,
                                      buildDefaultDragHandles: false,
                                      padding: const EdgeInsets.only(bottom: 80),
                                      itemCount: habits.length,
                                      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, habits),
                                      itemBuilder: (context, index) {
                                        final habit = habits[index];
                                        final isDoneToday = habit.completedDays.contains(today);
                                        Map<DateTime, int> dataset = { for (var date in habit.completedDays) DateTime(date.year, date.month, date.day): 1 };
                                        return ReorderableDelayedDragStartListener(
                                          index: index, key: Key('list_${habit.key}'),
                                          child: _buildStandardHabitCard(habit, isDoneToday, Color(habit.colorValue), cardColor, textColor, isDark, dataset),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // TAB 1: The New Schedule View
          const DailyScheduleScreen(),
          // TAB 2: The To-Do View
          const TodoScreen(),

          // TAB 3: The Notes View
          const NotesScreen(),

          // TAB 4: The Focus Timer View
          const FocusScreen(),
        ],
      ),
    );
  }
}