import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';

class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  // We no longer need to keep the EventController in the state,
  // the ValueListenableBuilder will generate a fresh one whenever the database changes!

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    // NEW: Listen to the Hive Box directly!
    return ValueListenableBuilder<Box<Habit>>(
      valueListenable: Hive.box<Habit>('habitsBox').listenable(),
      builder: (context, box, _) {

        // 1. Create a fresh controller with the absolute latest data
        final EventController<Habit> liveController = EventController<Habit>();
        final today = DateTime.now();

        for (var habit in box.values) {
          if (habit.scheduledStartTime != null && habit.scheduledEndTime != null) {
            final startTime = DateTime(today.year, today.month, today.day, habit.scheduledStartTime!.hour, habit.scheduledStartTime!.minute);
            final endTime = DateTime(today.year, today.month, today.day, habit.scheduledEndTime!.hour, habit.scheduledEndTime!.minute);

            liveController.add(CalendarEventData<Habit>(
              date: today,
              event: habit,
              title: habit.name,
              description: habit.description,
              startTime: startTime,
              endTime: endTime,
              color: Color(habit.colorValue),
            ));
          }
        }

        // 2. Render the Calendar using the live data
        return CalendarControllerProvider<Habit>(
          controller: liveController,
          child: Scaffold(
            backgroundColor: bgColor,
            body: DayView<Habit>(
              controller: liveController,
              showHalfHours: true,
              heightPerMinute: 1.5,
              backgroundColor: bgColor,
              scrollOffset: (DateTime.now().hour - 1) * 60 * 1.5,
              timeLineWidth: 75,

              headerStyle: HeaderStyle(
                headerTextStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: BoxDecoration(color: bgColor),
                leftIcon: Icon(Icons.chevron_left, color: textColor),
                rightIcon: Icon(Icons.chevron_right, color: textColor),
              ),

              liveTimeIndicatorSettings: const LiveTimeIndicatorSettings(
                color: Color(0xFF673AB7),
                showTime: true,
                showBullet: true,
              ),

              timeLineBuilder: (DateTime date) {
                if (date.minute != 0) {
                  return Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 15),
                    child: Container(width: 10, height: 1, color: Colors.grey.withOpacity(0.3)),
                  );
                }

                return Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 15),
                  child: Text(
                    "${date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour)} ${date.hour >= 12 ? 'PM' : 'AM'}",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                );
              },

              eventTileBuilder: (date, events, boundary, startDuration, endDuration) {
                if (events.isEmpty) return const SizedBox.shrink();
                final event = events.first;

                return Container(
                    margin: const EdgeInsets.only(right: 12, left: 4),
                    clipBehavior: Clip.hardEdge, // Silently cuts off anything outside the border
                    decoration: BoxDecoration(
                      color: event.color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: event.color, width: 1),
                    ),
                    padding: const EdgeInsets.all(8), // Reduced padding slightly to give text more room

                    // Wrap the column in a NeverScrollableScrollPhysics view.
                    // This allows it to calculate height without crashing the app!
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TIME ROW
                          Row(
                            children: [
                              const Icon(Icons.schedule, color: Colors.white70, size: 12),
                              const SizedBox(width: 4),
                              // Wrapping the text in Expanded stops the Right Overflow!
                              Expanded(
                                child: Text(
                                  "${DateFormat('h:mm').format(event.startTime!)} - ${DateFormat('h:mm a').format(event.endTime!)}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                  maxLines: 1, // Forces it to 1 line
                                  overflow: TextOverflow.ellipsis, // Adds "..." if it runs out of space
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // TITLE ROW
                          Text(
                            event.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2, // Allows up to 2 lines before cutting off
                            overflow: TextOverflow.ellipsis,
                          ),

                          // DESCRIPTION ROW
                          if (event.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                event.description!,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                  ),
                    )
                );
              },
            ),
          ),
        );
      },
    );
  }
}