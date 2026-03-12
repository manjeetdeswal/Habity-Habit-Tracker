import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';

import '../services/habitDatabase.dart';
import '../services/notification_service.dart';
import '../models/habit.dart';

class CreateHabitScreen extends StatefulWidget {
  final Habit? existingHabit;
  const CreateHabitScreen({super.key, this.existingHabit});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final HabitDatabase db = HabitDatabase();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _selectedColor = 0xFF673AB7;
  IconData _selectedIcon = Icons.menu_book_rounded;

  bool _showAdvanced = false;
  int _completionsPerDay = 1;
  bool _isStepByStep = true;
  List<TimeOfDay> _reminderTimes = [];

  List<String> _selectedCategories = [];
  String _streakGoalInterval = 'Daily';
  bool _allowExceeding = false;
  List<int> _reminderDays = [1, 2, 3, 4, 5, 6, 7];

  // NEW: Daily Schedule Time Blocks
  TimeOfDay? _scheduledStartTime;
  TimeOfDay? _scheduledEndTime;

  final List<String> _availableCategories = ['Art', 'Finances', 'Fitness', 'Health', 'Nutrition', 'Social', 'Study', 'Work', 'Other', 'Morning', 'Day', 'Evening'];
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final List<int> _colors = [
    0xFFFF5252, 0xFFFF9800, 0xFFFFEB3B, 0xFF4CAF50, 0xFF00BCD4, 0xFF448AFF, 0xFF7C4DFF,
    0xFFE040FB, 0xFFFF4081, 0xFFF44336, 0xFF8BC34A, 0xFF009688, 0xFF03A9F4, 0xFF3F51B5,
    0xFF9C27B0, 0xFF607D8B, 0xFF795548, 0xFF9E9E9E,
  ];

  final List<IconData> _icons =[
    Icons.show_chart, Icons.alarm, Icons.apple_rounded, Icons.hotel, Icons.account_balance_wallet,
    Icons.favorite_border, Icons.face, Icons.fitness_center, Icons.menu_book, Icons.picture_in_picture,
    Icons.palette, Icons.autorenew, Icons.music_note, Icons.shower, Icons.list,
    Icons.local_cafe, Icons.attach_money, Icons.favorite, Icons.eco, Icons.sports_esports,
    Icons.directions_bike, Icons.water_drop, Icons.directions_run, Icons.self_improvement,
    Icons.medication, Icons.wb_sunny, Icons.nightlight_round, Icons.cleaning_services,
    Icons.restaurant, Icons.shopping_cart, Icons.airplanemode_active, Icons.pets, Icons.school
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingHabit != null) {
      final h = widget.existingHabit!;
      _nameController.text = h.name;
      _descController.text = h.description;
      _selectedColor = h.colorValue;
      _selectedIcon = IconData(h.iconCodePoint, fontFamily: 'MaterialIcons');
      _completionsPerDay = h.completionsPerDay;
      _selectedCategories = h.categories.toList();
      _streakGoalInterval = h.streakGoalInterval;
      _allowExceeding = h.allowExceeding;
      _reminderDays = h.reminderDays.toList();

      if (h.reminderTimes.isNotEmpty) {
        _reminderTimes = h.reminderTimes.map((dt) => TimeOfDay(hour: dt.hour, minute: dt.minute)).toList();
      } else {
        _reminderTimes = [];
      }

      // NEW: Load existing schedule times
      if (h.scheduledStartTime != null) {
        _scheduledStartTime = TimeOfDay(hour: h.scheduledStartTime!.hour, minute: h.scheduledStartTime!.minute);
      }
      if (h.scheduledEndTime != null) {
        _scheduledEndTime = TimeOfDay(hour: h.scheduledEndTime!.hour, minute: h.scheduledEndTime!.minute);
      }

    } else {
      final random = Random();
      _selectedColor = _colors[random.nextInt(_colors.length)];
      _selectedIcon = _icons[random.nextInt(_icons.length)];
    }
  }

  void _saveHabit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Habit title cannot be empty!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
      );
      return;
    }

    final now = DateTime.now();
    List<DateTime> dbTimes = _reminderTimes.map((t) =>
        DateTime(now.year, now.month, now.day, t.hour, t.minute)
    ).toList();

    // NEW: Convert TimeOfDay to DateTime for Hive
    DateTime? finalStartTime;
    DateTime? finalEndTime;

    if (_scheduledStartTime != null) {
      finalStartTime = DateTime(now.year, now.month, now.day, _scheduledStartTime!.hour, _scheduledStartTime!.minute);
    }
    if (_scheduledEndTime != null) {
      finalEndTime = DateTime(now.year, now.month, now.day, _scheduledEndTime!.hour, _scheduledEndTime!.minute);
    }

    int currentHabitKey;

    if (widget.existingHabit != null) {
      // UPDATE EXISTING HABIT
      widget.existingHabit!.name = _nameController.text;
      widget.existingHabit!.description = _descController.text;
      widget.existingHabit!.colorValue = _selectedColor;
      widget.existingHabit!.iconCodePoint = _selectedIcon.codePoint;
      widget.existingHabit!.completionsPerDay = _completionsPerDay;
      widget.existingHabit!.reminderTimes = dbTimes;
      widget.existingHabit!.categories = _selectedCategories;
      widget.existingHabit!.streakGoalInterval = _streakGoalInterval;
      widget.existingHabit!.allowExceeding = _allowExceeding;
      widget.existingHabit!.reminderDays = _reminderDays;

      // NEW: Save Schedule Times
      widget.existingHabit!.scheduledStartTime = finalStartTime;
      widget.existingHabit!.scheduledEndTime = finalEndTime;

      widget.existingHabit!.save();

      currentHabitKey = widget.existingHabit!.key;
    } else {
      // ADD NEW HABIT
      db.addCustomHabit(
        name: _nameController.text,
        description: _descController.text,
        colorValue: _selectedColor,
        iconCodePoint: _selectedIcon.codePoint,
        completionsPerDay: _completionsPerDay,
        reminderTimes: dbTimes,
        categories: _selectedCategories,
        streakGoalInterval: _streakGoalInterval,
        allowExceeding: _allowExceeding,
        reminderDays: _reminderDays,
        // NEW: Pass Schedule Times
        scheduledStartTime: finalStartTime,
        scheduledEndTime: finalEndTime,
      );

      final box = Hive.box<Habit>('habitsBox');
      currentHabitKey = box.values.last.key;
    }

    if (_reminderTimes.isNotEmpty) {
      NotificationService.scheduleHabitReminder(currentHabitKey, _nameController.text, _reminderTimes, _reminderDays);
    } else {
      NotificationService.cancelHabitReminder(currentHabitKey);
    }

    Navigator.pop(context);
  }

  void _showStreakGoalSheet(Color cardColor, Color textColor) {
    showModalBottomSheet(
        context: context, backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Streak Goal', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ...['None', 'Daily', 'Week', 'Month'].map((interval) => ListTile(
                  title: Text(interval, style: TextStyle(color: textColor)),
                  trailing: _streakGoalInterval == interval ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                  onTap: () {
                    setState(() => _streakGoalInterval = interval);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          );
        }
    );
  }

  void _showCategoriesSheet(Color cardColor, Color textColor) {
    TextEditingController customCategoryController = TextEditingController();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categories', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: customCategoryController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Add custom category...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF673AB7)),
                            onPressed: () {
                              if (customCategoryController.text.trim().isNotEmpty) {
                                setModalState(() {
                                  String newCat = customCategoryController.text.trim();
                                  if (!_availableCategories.contains(newCat)) _availableCategories.add(newCat);
                                  if (!_selectedCategories.contains(newCat)) _selectedCategories.add(newCat);
                                });
                                setState(() {});
                                customCategoryController.clear();
                              }
                            },
                          ),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF673AB7))),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 10, runSpacing: 10,
                            children: _availableCategories.map((cat) {
                              final isSelected = _selectedCategories.contains(cat);
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    isSelected ? _selectedCategories.remove(cat) : _selectedCategories.add(cat);
                                  });
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(color: isSelected ? const Color(0xFF673AB7) : cardColor, borderRadius: BorderRadius.circular(20)),
                                  child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.w600)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF673AB7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Save & Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  void _showExceedingDialog(Color cardColor, Color textColor) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: cardColor,
          title: Text('Keep counting beyond goal', style: TextStyle(color: textColor)),
          content: Text('Continue tracking completions after reaching your daily goal.', style: TextStyle(color: Colors.grey.shade500)),
          actions: [
            TextButton(onPressed: () { setState(() => _allowExceeding = false); Navigator.pop(context); }, child: const Text('Stop at goal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7)),
              onPressed: () { setState(() => _allowExceeding = true); Navigator.pop(context); },
              child: const Text('Allow exceeding', style: TextStyle(color: Colors.white)),
            ),
          ],
        )
    );
  }

  void _showReminderSheet(Color cardColor, Color textColor) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reminders (${_reminderTimes.length})', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final dayNum = index + 1;
                                final isSelected = _reminderDays.contains(dayNum);
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() { isSelected ? _reminderDays.remove(dayNum) : _reminderDays.add(dayNum); });
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: isSelected ? const Color(0xFF673AB7) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                    child: Text(_weekDays[index], style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                            ..._reminderTimes.map((time) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.schedule, color: Colors.white), const SizedBox(width: 10),
                                            Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                        onTap: () {
                                          setModalState(() => _reminderTimes.remove(time));
                                          setState(() {});
                                        },
                                        child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_outline, color: Colors.redAccent))),
                                  ],
                                ),
                              );
                            }),
                            GestureDetector(
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                  if (picked != null) {
                                    setModalState(() {
                                      if (!_reminderTimes.contains(picked)) {
                                        _reminderTimes.add(picked);
                                      }
                                    });
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF673AB7), width: 2)
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add, color: Color(0xFF673AB7)), SizedBox(width: 8),
                                        Text('Add Time', style: TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold, fontSize: 16))
                                      ],
                                    )
                                )
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  // NEW: Helper widget to build the Time Picker buttons cleanly
  Widget _buildTimePickerBox(String title, TimeOfDay? time, Color cardColor, Color textColor, bool isStart) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
        if (picked != null) {
          setState(() {
            if (isStart) _scheduledStartTime = picked;
            else _scheduledEndTime = picked;
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(title, true),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: time != null ? const Color(0xFF673AB7).withOpacity(0.2) : cardColor,
              borderRadius: BorderRadius.circular(12),
              border: time != null ? Border.all(color: const Color(0xFF673AB7)) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : 'Not Set',
                  style: TextStyle(color: time != null ? const Color(0xFF673AB7) : Colors.grey, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.schedule, color: time != null ? const Color(0xFF673AB7) : Colors.grey, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text(widget.existingHabit == null ? 'New Habit' : 'Edit Habit', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF673AB7), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveHabit,
            child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Name', isDark), _buildTextField(_nameController, 'e.g., Reading', cardColor, textColor), const SizedBox(height: 20),
            _buildLabel('Description', isDark), _buildTextField(_descController, 'Read everyday for at least 15 minutes', cardColor, textColor), const SizedBox(height: 30),

            _buildLabel('Icon', isDark),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 15, runSpacing: 15, children: _icons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isSelected ? Color(_selectedColor) : cardColor, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54), size: 28),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 30),

            _buildLabel('Color', isDark),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 15, runSpacing: 15, children: _colors.map((colorHex) {
                final isSelected = _selectedColor == colorHex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorHex),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Color(colorHex), borderRadius: BorderRadius.circular(10), border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3) : null),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 30),

            Center(
              child: GestureDetector(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Advanced Options ${_showAdvanced ? "▲" : "▼"}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 30),

            if (_showAdvanced) ...[

              // NEW: Daily Schedule Time Blocks Added Here
              Row(
                children: [
                  Expanded(child: _buildTimePickerBox('Schedule Start', _scheduledStartTime, cardColor, textColor, true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTimePickerBox('Schedule End', _scheduledEndTime, cardColor, textColor, false)),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _buildSettingTile('Streak Goal', _streakGoalInterval, cardColor, textColor, onTap: () => _showStreakGoalSheet(cardColor, textColor))),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _buildSettingTile(
                          'Reminder',
                          _reminderTimes.isEmpty
                              ? '0 Active'
                              : (_reminderTimes.length == 1 ? _reminderTimes.first.format(context) : '${_reminderTimes.length} Active'),
                          cardColor,
                          textColor,
                          onTap: () => _showReminderSheet(cardColor, textColor)
                      )
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildSettingTile('Categories', _selectedCategories.isEmpty ? 'None' : _selectedCategories.join(', '), cardColor, textColor, onTap: () => _showCategoriesSheet(cardColor, textColor)),
              const SizedBox(height: 20),

              _buildLabel('How should completions be tracked?', isDark),
              Row(
                children: [
                  Expanded(child: GestureDetector(onTap: () => setState(() => _isStepByStep = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: _isStepByStep ? cardColor : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardColor)), child: Text('Step By Step', style: TextStyle(color: _isStepByStep ? textColor : Colors.grey))))),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(onTap: () => setState(() => _isStepByStep = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: !_isStepByStep ? cardColor : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardColor)), child: Text('Custom Value', style: TextStyle(color: !_isStepByStep ? textColor : Colors.grey))))),
                ],
              ),
              const SizedBox(height: 20),

              _buildLabel('Completions Per Day', isDark),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(border: InputBorder.none),
                              onChanged: (val) => _completionsPerDay = int.tryParse(val) ?? 1,
                              controller: TextEditingController(text: _completionsPerDay.toString())..selection = TextSelection.collapsed(offset: _completionsPerDay.toString().length),
                            ),
                          ),
                          Text('/ Day', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _showExceedingDialog(cardColor, textColor),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _allowExceeding ? Colors.green.withOpacity(0.2) : cardColor, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.fact_check_outlined, color: _allowExceeding ? Colors.green : textColor),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 14)));
  Widget _buildTextField(TextEditingController controller, String hint, Color fill, Color text) => TextField(controller: controller, style: TextStyle(color: text), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade500), filled: true, fillColor: fill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));

  Widget _buildSettingTile(String label, String value, Color fill, Color text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label, true),
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(value, style: TextStyle(color: text, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)), const Icon(Icons.chevron_right, color: Colors.grey, size: 20)]),
          ),
        ],
      ),
    );
  }
}