import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../models/focus_session.dart';

// NEW: Global variable that tells HomePage to hide the Bottom Navigation Bar
final ValueNotifier<bool> isFocusFullscreen = ValueNotifier(false);

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final Box<FocusSession> _focusBox = Hive.box<FocusSession>('focusBox');
  final TextEditingController _taskController = TextEditingController();

  Timer? _timer;
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;

  String _currentMode = 'Pomodoro';
  Color _currentColor = const Color(0xFFE53935);
  bool _isFullscreen = false;

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    isFocusFullscreen.value = false; // Always restore nav bar when leaving tab
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      isFocusFullscreen.value = _isFullscreen; // Tells HomePage to hide Nav Bar!

      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  // --- TIMER ENGINE ---
  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopTimer(completed: true);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _stopTimer({bool completed = false}) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
    if (completed && (_currentMode == 'Pomodoro' || _currentMode == 'Custom Timer')) {
      _saveSession();
      _showCompletionDialog();
    }
  }

  void _setMode(String mode, int minutes, Color color) {
    _timer?.cancel();
    setState(() {
      _currentMode = mode;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _currentColor = color;
      _isRunning = false;
    });
  }

  void _showEditTimerDialog() {
    TextEditingController minController = TextEditingController(text: (_totalSeconds ~/ 60).toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Custom Timer', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: minController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: 'minutes',
            suffixStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF673AB7))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7)),
            onPressed: () {
              int? newMinutes = int.tryParse(minController.text);
              if (newMinutes != null && newMinutes > 0) {
                _timer?.cancel();
                setState(() {
                  _totalSeconds = newMinutes * 60;
                  _remainingSeconds = _totalSeconds;
                  _currentMode = 'Custom Timer';
                  _isRunning = false;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Set Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _saveSession() {
    int minutesLogged = _totalSeconds ~/ 60;
    _focusBox.add(
      FocusSession(
        date: DateTime.now(),
        durationInMinutes: minutesLogged,
        mode: _currentMode,
        taskName: _taskController.text.trim().isNotEmpty ? _taskController.text.trim() : null,
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Session Complete! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Great job! Your ${_taskController.text.isNotEmpty ? '"${_taskController.text}" ' : ''}session has been logged.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7)),
            onPressed: () {
              Navigator.pop(ctx);
              _setMode('Short Break', 5, const Color(0xFF43A047));
            },
            child: const Text('Start Break', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  int _getTodayTotalMinutes() {
    final today = DateTime.now();
    return _focusBox.values.where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day)
        .fold(0, (sum, item) => sum + item.durationInMinutes);
  }

  int _getTodaySessions() {
    final today = DateTime.now();
    return _focusBox.values.where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day).length;
  }

  // ==========================================
  // UI BUILDER HELPERS
  // ==========================================

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: EdgeInsets.only(left: 20.0, right: 10.0, top: _isFullscreen ? 10.0 : 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isFullscreen ? 0.0 : 1.0,
            child: Text(_isFullscreen ? '' : 'Focus Mode', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          ),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.grey.shade500, size: 30),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInput(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: TextField(
        controller: _taskController,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'What are you focusing on?',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildModeToggles(Color textColor, bool isDark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _isFullscreen ? const SizedBox.shrink() : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              _buildModeButton('Pomodoro', 25, const Color(0xFFE53935), textColor, isDark),
              _buildModeButton('Short Break', 5, const Color(0xFF43A047), textColor, isDark),
              _buildModeButton('Long Break', 15, const Color(0xFF1E88E5), textColor, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String title, int minutes, Color color, Color textColor, bool isDark) {
    bool isSelected = _currentMode == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _taskController.clear();
          _setMode(title, minutes, color);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected && !isDark ? [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4)] : [],
          ),
          child: Center(
            child: Text(title, style: TextStyle(color: isSelected ? textColor : Colors.grey.shade500, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerRing(double progress, int minutes, int seconds, Color textColor, bool isDark, bool isLandscape) {
    double screenHeight = MediaQuery.of(context).size.height;
    bool isDesktop = MediaQuery.of(context).size.width > 900; // Check if we are on PC

    // PC Responsive Math
    double ringRadius = isDesktop ? (screenHeight * 0.35).clamp(150.0, 250.0) : (isLandscape ? 110.0 : (_isFullscreen ? 160.0 : 130.0));
    double fontFlip = isDesktop ? 100 : (isLandscape ? 50 : (_isFullscreen ? 70 : 55));
    double fontColon = isDesktop ? 80 : (isLandscape ? 40 : (_isFullscreen ? 60 : 45));

    return Stack(
      alignment: Alignment.center,
      children: [
        CircularPercentIndicator(
          radius: ringRadius,
          lineWidth: 8.0,
          percent: progress,
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
          progressColor: _currentColor,
          animation: true,
          animateFromLastPercent: true,
          animationDuration: 1000,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _currentColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedFlipCounter(value: minutes, wholeDigits: 2, textStyle: TextStyle(fontSize: fontFlip, fontWeight: FontWeight.bold, color: _currentColor, fontFamily: 'monospace')),
                  Text(':', style: TextStyle(fontSize: fontColon, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.5))),
                  AnimatedFlipCounter(value: seconds, wholeDigits: 2, textStyle: TextStyle(fontSize: fontFlip, fontWeight: FontWeight.bold, color: _currentColor, fontFamily: 'monospace')),
                ],
              ),
            ),
            if (!_isRunning && _remainingSeconds == _totalSeconds)
              GestureDetector(
                onTap: _showEditTimerDialog,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.grey.shade500, size: 16),
                      const SizedBox(width: 5),
                      Text('Edit Time', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
  Widget _buildControls(Color textColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isRunning || _remainingSeconds < _totalSeconds)
          GestureDetector(
            onTap: () => _stopTimer(completed: false),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade200, shape: BoxShape.circle),
              child: Icon(Icons.stop_rounded, color: textColor, size: 30),
            ),
          ),
        GestureDetector(
          onTap: _isRunning ? _pauseTimer : _startTimer,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: _currentColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(_isRunning ? 'PAUSE' : 'START', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(Color textColor, bool isDark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _isFullscreen ? const SizedBox.shrink() : ValueListenableBuilder<Box<FocusSession>>(
          valueListenable: _focusBox.listenable(),
          builder: (context, box, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 28),
                      const SizedBox(height: 5),
                      Text('${_getTodaySessions()}', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Sessions Today', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.3)),
                  Column(
                    children: [
                      const Icon(Icons.timer_rounded, color: Color(0xFF673AB7), size: 28),
                      const SizedBox(height: 5),
                      Text('${_getTodayTotalMinutes()}m', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Deep Work', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          }
      ),
    );
  }

  // ==========================================
  // MAIN BUILD METHOD WITH ORIENTATION
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    double progress = 1.0 - (_remainingSeconds / _totalSeconds);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            bool isLandscape = orientation == Orientation.landscape;

            // --- LANDSCAPE / PC LAYOUT ---
            if (isLandscape) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(textColor),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: _buildTimerRing(progress, minutes, seconds, textColor, isDark, true),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500), // Stops stretching on PC!
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              _buildTaskInput(textColor),
                              const SizedBox(height: 10),
                              _buildModeToggles(textColor, isDark),
                              const SizedBox(height: 20),
                              _buildControls(textColor, isDark),
                              const SizedBox(height: 10),
                              _buildStats(textColor, isDark),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // --- PORTRAIT MOBILE LAYOUT ---
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          _buildHeader(textColor),
                          _buildTaskInput(textColor),
                          _buildModeToggles(textColor, isDark),
                          const Spacer(),

                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildTimerRing(progress, minutes, seconds, textColor, isDark, false),
                          ),

                          const Spacer(),
                          _buildControls(textColor, isDark),
                          const Spacer(),
                          _buildStats(textColor, isDark),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}