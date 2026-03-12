import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'models/focus_session.dart';
import 'models/note.dart';
import 'models/todo.dart';
import 'services/habitDatabase.dart';
import 'models/habit.dart';
import 'screens/home_page.dart';
import 'services/local_sync_service.dart';
import 'services/notification_service.dart';





@pragma("vm:entry-point")
Future<void> interactiveCallback(Uri? uri) async {
  if (uri?.host == 'tickhabit') {
    int habitKey = int.parse(uri?.queryParameters['id'] ?? '-1');
    if (habitKey != -1) {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HabitAdapter());
      }
      final box = await Hive.openBox<Habit>('habitsBox');
      final habit = box.values.firstWhere((h) => h.key == habitKey);

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);


      bool isDone = habit.completedDays.any((d) => d.year == today.year && d.month == today.month && d.day == today.day);


      if (isDone) {
        habit.completedDays.removeWhere((d) => d.year == today.year && d.month == today.month && d.day == today.day);
        isDone = false;
      } else {
        habit.completedDays.add(today);
        isDone = true;
      }

      habit.save();

      await HomeWidget.saveWidgetData<bool>('habit_${habit.key}_done', isDone);


      await HabitDatabase.syncWidgetState(habit);

      await HomeWidget.updateWidget(name: 'FitdyWidgetProvider');
    }
  }
}


final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();


  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(TodoAdapter());
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(FocusSessionAdapter());


  await Hive.openBox<Habit>('habitsBox');
  await Hive.openBox<Todo>('todoBox');
  await Hive.openBox<Note>('notesBox');
  await Hive.openBox<FocusSession>('focusBox');
  await Hive.openBox('settingsBox');

  await NotificationService.init();
  await LocalSyncService.start();
  HomeWidget.registerInteractivityCallback(interactiveCallback);

  runApp(const FitdyApp());
}

class FitdyApp extends StatelessWidget {
  const FitdyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'Habity',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.grey.shade100,
              cardColor: Colors.white,
              appBarTheme: AppBarTheme(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black, elevation: 0),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121421),
              cardColor: const Color(0xFF1C1F30),
              appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121421), foregroundColor: Colors.white, elevation: 0),
              useMaterial3: true,
            ),
            themeMode: currentMode,
            home: const HomePage(),
          );
        }
    );
  }
}