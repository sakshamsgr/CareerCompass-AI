import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';

class TaskTrackerScreen extends StatefulWidget {
  const TaskTrackerScreen({super.key});

  @override
  State<TaskTrackerScreen> createState() => _TaskTrackerScreenState();
}

class _TaskTrackerScreenState extends State<TaskTrackerScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = []; 
  Map<String, dynamic> _completions = {}; 
  int _currentStreak = 0;
  DateTime? _joinedAt;
  
  double _streakThreshold = 0.5;
  
  bool _isReminderOn = false;
  TimeOfDay? _reminderTime;
  
  final DateTime _today = DateTime.now();
  late DateTime _yesterday;
  late int _daysInMonth;
  late String _currentMonthName;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();

  final List<String> _emojiOptions = ['🚀', '🎯', '💧', '🧠', '📚', '💻', '🏋️‍♀️', '🍎', '🧘', '🎨', '⭐', '🔥'];
  final List<Color> _colorOptions = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.purple, Colors.cyan, Colors.teal, Colors.pink
  ];

  @override
  void initState() {
    super.initState();
    _yesterday = _today.subtract(const Duration(days: 1));
    _daysInMonth = DateUtils.getDaysInMonth(_today.year, _today.month);
    _currentMonthName = DateFormat('MMMM yyyy').format(_today);
    
    _headerScrollController.addListener(() {
      if (_gridScrollController.hasClients && _headerScrollController.position.pixels != _gridScrollController.position.pixels) {
        _gridScrollController.jumpTo(_headerScrollController.position.pixels);
      }
    });
    _gridScrollController.addListener(() {
      if (_headerScrollController.hasClients && _gridScrollController.position.pixels != _headerScrollController.position.pixels) {
        _headerScrollController.jumpTo(_gridScrollController.position.pixels);
      }
    });

    _fetchData();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        
        setState(() {
          _joinedAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          _streakThreshold = (data['streakThreshold'] ?? 0.5).toDouble();
          _isReminderOn = data['isReminderOn'] ?? false;
          
          if (data['reminderTime'] != null) {
            final parts = data['reminderTime'].toString().split(':');
            _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }

          List<dynamic> rawTasks = data['tasks'] ?? [];
          _tasks = [];
          
          for (var t in rawTasks) {
            if (t is String) {
              _tasks.add({'name': t, 'emoji': '⭐', 'color': AppTheme.secondaryAccent.toARGB32()});
            } else if (t is Map) {
              _tasks.add(Map<String, dynamic>.from(t));
            }
          }
          
          if (data['task_completions'] != null) {
            final rawCompletions = data['task_completions'] as Map;
            _completions = rawCompletions.map((key, value) {
              return MapEntry(key.toString(), Map<String, dynamic>.from(value as Map));
            });
          }
          _currentStreak = data['currentStreak'] ?? 0;
        });
        
        _calculateStreak(); 
      }
    }
    setState(() => _isLoading = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  void _scrollToToday() {
    if (_verticalScrollController.hasClients) {
      double offset = ((_today.day - 1) * 60.0) - 60.0; 
      if (offset < 0) offset = 0;
      
      double maxScroll = _verticalScrollController.position.maxScrollExtent;
      if (offset > maxScroll) offset = maxScroll;

      _verticalScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  Future<void> _saveToFirebase() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'tasks': _tasks,
        'task_completions': _completions,
        'currentStreak': _currentStreak,
        'streakThreshold': _streakThreshold, 
        'isReminderOn': _isReminderOn,
        'reminderTime': _reminderTime != null ? "${_reminderTime!.hour}:${_reminderTime!.minute}" : null,
      });
    }
  }

  void _calculateStreak() {
    int streak = 0;
    
    for (int i = 0; i < 365; i++) {
      DateTime checkDate = _today.subtract(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(checkDate);
      
      int completedTasks = 0;
      if (_completions.containsKey(dateKey)) {
        final dayData = _completions[dateKey] as Map; 
        for (var task in _tasks) {
          if (dayData[task['name']] == true) completedTasks++;
        }
      }

      double percentage = _tasks.isNotEmpty ? (completedTasks / _tasks.length) : 0.0;

      if (percentage >= _streakThreshold) {
        streak++; 
      } else {
        if (i == 0) continue; 
        break; 
      }
    }

    setState(() => _currentStreak = streak);
    
    // 🚀 THE FIX: Always save to Firebase regardless of streak changes!
    _saveToFirebase();
  }

  void _toggleTask(String taskName, int day) {
    DateTime targetDate = DateTime(_today.year, _today.month, day);
    
    bool isToday = targetDate.year == _today.year && targetDate.month == _today.month && targetDate.day == _today.day;
    bool isYesterday = targetDate.year == _yesterday.year && targetDate.month == _yesterday.month && targetDate.day == _yesterday.day;
    
    if (!isToday && !isYesterday) return;

    String dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
    
    setState(() {
      if (!_completions.containsKey(dateKey)) {
        _completions[dateKey] = {};
      }
      bool currentValue = _completions[dateKey][taskName] ?? false;
      _completions[dateKey][taskName] = !currentValue;
    });

    _calculateStreak();
  }

  Future<void> _showReminderDialog() async {
    TimeOfDay initialTime = _reminderTime ?? const TimeOfDay(hour: 20, minute: 0); 
    
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: AppTheme.isDark(context) ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _reminderTime = pickedTime;
        _isReminderOn = true;
      });
      await NotificationService.scheduleDailyReminder(pickedTime);
      _saveToFirebase();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Reminder set for ${pickedTime.format(context)}!"),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  void _toggleReminder() {
    setState(() {
      _isReminderOn = !_isReminderOn;
    });
    if (_isReminderOn && _reminderTime != null) {
      NotificationService.scheduleDailyReminder(_reminderTime!);
    } else {
      NotificationService.cancelReminders();
    }
    _saveToFirebase();
  }

  void _showThresholdDialog() {
    double tempThreshold = _streakThreshold;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isDark = AppTheme.isDark(context);
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
              title: Text('Set Daily Goal', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "What percentage of tasks must be completed to keep your streak alive?",
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "${(tempThreshold * 100).toInt()}%",
                    style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: tempThreshold,
                    min: 0.5,
                    max: 1.0,
                    divisions: 5,
                    activeColor: AppTheme.secondaryAccent,
                    inactiveColor: isDark ? Colors.white24 : Colors.black12,
                    onChanged: (val) {
                      setModalState(() => tempThreshold = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                  onPressed: () {
                    setState(() => _streakThreshold = tempThreshold);
                    _calculateStreak(); 
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showAddEditTaskDialog({int? index}) {
    bool isEditing = index != null;
    TextEditingController controller = TextEditingController(text: isEditing ? _tasks[index]['name'] : '');
    String selectedEmoji = isEditing ? _tasks[index]['emoji'] : '🚀';
    Color selectedColor = isEditing ? Color(_tasks[index]['color']) : Colors.blue;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isDark = AppTheme.isDark(context);
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
              title: Text(isEditing ? 'Edit Task' : 'New Custom Task', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: AppTheme.inputDecoration('Task Name', Icons.edit, context),
                    ),
                    const SizedBox(height: 20),
                    const Text("Pick an Emoji Icon", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _emojiOptions.map((e) => GestureDetector(
                        onTap: () => setModalState(() => selectedEmoji = e),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedEmoji == e ? AppTheme.primaryAccent.withValues(alpha: 0.3 * 255) : Colors.transparent,
                            border: Border.all(color: selectedEmoji == e ? AppTheme.primaryAccent : Colors.transparent),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text("Pick a Color Theme", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _colorOptions.map((c) => GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 35, height: 35,
                          decoration: BoxDecoration(
                            color: c, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: selectedColor == c ? 3 : 0)
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () {
                      final String oldName = _tasks[index]['name'];
                      setState(() {
                        _tasks.removeAt(index);
                        _completions.forEach((dateKey, dayData) {
                          if (dayData is Map && dayData.containsKey(oldName)) {
                            dayData.remove(oldName);
                          }
                        });
                      });
                      _calculateStreak();
                      Navigator.pop(context);
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: selectedColor),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      final String newName = controller.text.trim();
                      final newTask = {'name': newName, 'emoji': selectedEmoji, 'color': selectedColor.toARGB32()};
                      
                      setState(() {
                        if (isEditing) {
                          final String oldName = _tasks[index]['name'];
                          _tasks[index] = newTask;
                          if (oldName != newName) {
                            _completions.forEach((dateKey, dayData) {
                              if (dayData is Map && dayData.containsKey(oldName)) {
                                dayData[newName] = dayData[oldName];
                                dayData.remove(oldName);
                              }
                            });
                          }
                        } else {
                          _tasks.add(newTask);
                        }
                      });
                      _calculateStreak();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _openHistoryCalendar() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => CalendarHistoryScreen(
        completions: _completions, 
        tasks: _tasks, 
        joinedAt: _joinedAt ?? DateTime.now(),
        streakThreshold: _streakThreshold,
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;
    Color borderColor = isDark ? Colors.white10 : Colors.black12;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Habit Matrix', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppTheme.primaryAccent),
            tooltip: 'View History',
            onPressed: _openHistoryCalendar,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentMonthName, 
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  InkWell(
                    onTap: _isReminderOn ? _toggleReminder : _showReminderDialog,
                    onLongPress: () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending test notification...")));
                       NotificationService.showTestNotification();
                    }, 
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isReminderOn ? AppTheme.primaryAccent.withValues(alpha: 0.1 * 255) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isReminderOn ? AppTheme.primaryAccent.withValues(alpha: 0.5 * 255) : borderColor)
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isReminderOn ? Icons.alarm_on : Icons.alarm_add, 
                            color: _isReminderOn ? AppTheme.primaryAccent : Colors.grey, 
                            size: 16
                          ),
                          if (_isReminderOn && _reminderTime != null) ...[
                            const SizedBox(width: 4),
                            Text(_reminderTime!.format(context), style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold))
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  InkWell(
                    onTap: _showThresholdDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryAccent.withValues(alpha: 0.1 * 255),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secondaryAccent.withValues(alpha: 0.5 * 255))
                      ),
                      child: Row(
                        children: [
                          Text("Goal: ${(_streakThreshold * 100).toInt()}%", style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(width: 4),
                          const Icon(Icons.settings, color: AppTheme.secondaryAccent, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            Expanded(
              child: _tasks.isEmpty 
                ? _buildEmptyState(textColor, isDark)
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.2 * 255)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03 * 255), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          Container(
                            height: 75,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03 * 255) : Colors.black.withValues(alpha: 0.02 * 255),
                              border: Border(bottom: BorderSide(color: borderColor)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                                  child: Icon(Icons.date_range, color: AppTheme.primaryAccent.withValues(alpha: 0.5 * 255)),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _headerScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const ClampingScrollPhysics(),
                                    child: Row(
                                      children: List.generate(_tasks.length, (index) {
                                        final task = _tasks[index];
                                        return InkWell(
                                          onTap: () => _showAddEditTaskDialog(index: index),
                                          child: Container(
                                            width: 130, 
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(task['emoji'], style: const TextStyle(fontSize: 20)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  task['name'],
                                                  maxLines: 2, 
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              controller: _verticalScrollController,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 80,
                                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                                    child: Column(
                                      children: List.generate(_daysInMonth, (dayIndex) {
                                        int day = dayIndex + 1;
                                        DateTime targetDate = DateTime(_today.year, _today.month, day);
                                        bool isToday = targetDate.year == _today.year && targetDate.month == _today.month && targetDate.day == _today.day;
                                        return Container(
                                          height: 60,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isToday ? AppTheme.primaryAccent.withValues(alpha: 0.1 * 255) : Colors.transparent,
                                            border: Border(bottom: BorderSide(color: borderColor, width: 0.5))
                                          ),
                                          child: Text(
                                            "${DateFormat('MMM').format(targetDate)}\n$day",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isToday ? AppTheme.primaryAccent : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 12, height: 1.2
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _gridScrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics: const ClampingScrollPhysics(),
                                      child: Column(
                                        children: List.generate(_daysInMonth, (dayIndex) {
                                          int day = dayIndex + 1;
                                          DateTime targetDate = DateTime(_today.year, _today.month, day);
                                          bool isToday = targetDate.year == _today.year && targetDate.month == _today.month && targetDate.day == _today.day;
                                          bool isYesterday = targetDate.year == _yesterday.year && targetDate.month == _yesterday.month && targetDate.day == _yesterday.day;
                                          bool isInteractive = isToday || isYesterday;
                                          bool isFuture = targetDate.isAfter(_today);

                                          return Row(
                                            children: List.generate(_tasks.length, (taskIndex) {
                                              final task = _tasks[taskIndex];
                                              final taskColor = Color(task['color']);
                                              String dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
                                              bool isCompleted = _completions[dateKey]?[task['name']] ?? false;

                                              Widget stampContent;
                                              if (isFuture) {
                                                stampContent = Icon(Icons.lock_outline, size: 16, color: Colors.grey.withValues(alpha: 0.3 * 255));
                                              } else if (isCompleted) {
                                                stampContent = Icon(Icons.check_circle, color: taskColor, size: 24);
                                              } else if (isInteractive) {
                                                stampContent = Container(
                                                  width: 20, height: 20,
                                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.withValues(alpha: 0.5 * 255), width: 2)),
                                                ); 
                                              } else {
                                                stampContent = Text("—", style: TextStyle(color: Colors.grey.withValues(alpha: 0.4 * 255), fontWeight: FontWeight.bold));
                                              }

                                              return GestureDetector(
                                                onTap: isInteractive ? () => _toggleTask(task['name'], day) : null,
                                                child: Container(
                                                  width: 130, 
                                                  height: 60,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: isToday ? AppTheme.primaryAccent.withValues(alpha: 0.02 * 255) : Colors.transparent,
                                                    border: Border(
                                                      right: BorderSide(color: borderColor, width: 0.5),
                                                      bottom: BorderSide(color: borderColor, width: 0.5)
                                                    )
                                                  ),
                                                  child: stampContent,
                                                ),
                                              );
                                            }),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.secondaryAccent,
        onPressed: () => _showAddEditTaskDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.primaryAccent.withValues(alpha: 0.1 * 255), shape: BoxShape.circle),
            child: const Icon(Icons.fact_check_outlined, size: 60, color: AppTheme.primaryAccent),
          ),
          const SizedBox(height: 24),
          Text("No Habits Tracked", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Use the AI Career Dashboard to generate\nhabits, or manually add your own below.",
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class CalendarHistoryScreen extends StatelessWidget {
  final Map<String, dynamic> completions;
  final List<Map<String, dynamic>> tasks;
  final DateTime joinedAt;
  final double streakThreshold;

  const CalendarHistoryScreen({
    super.key, 
    required this.completions, 
    required this.tasks, 
    required this.joinedAt,
    required this.streakThreshold,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;
    
    DateTime now = DateTime.now();
    int totalMonths = ((now.year - joinedAt.year) * 12) + (now.month - joinedAt.month) + 1;
    if (totalMonths <= 0) totalMonths = 1; 
    if (totalMonths > 60) totalMonths = 60; 
    
    List<DateTime> months = List.generate(totalMonths, (index) => DateTime(now.year, now.month - index, 1));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(title: Text('My Consistency', style: TextStyle(color: textColor)), iconTheme: IconThemeData(color: textColor)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        itemBuilder: (context, index) {
          DateTime monthDate = months[index];
          String monthName = DateFormat('MMMM yyyy').format(monthDate);
          int daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(monthName, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: daysInMonth,
                itemBuilder: (context, dayIndex) {
                  int day = dayIndex + 1;
                  DateTime targetDate = DateTime(monthDate.year, monthDate.month, day);
                  String dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
                  
                  int completedTasks = 0;
                  if (completions.containsKey(dateKey)) {
                    final dayData = completions[dateKey] as Map; 
                    for (var t in tasks) {
                      if (dayData[t['name']] == true) completedTasks++;
                    }
                  }
                  
                  bool isFuture = targetDate.isAfter(now);
                  bool isBeforeJoined = targetDate.isBefore(DateTime(joinedAt.year, joinedAt.month, joinedAt.day));
                  
                  bool isWin = tasks.isNotEmpty && (completedTasks / tasks.length) >= streakThreshold;

                  return Container(
                    decoration: BoxDecoration(
                      color: isFuture || isBeforeJoined 
                          ? Colors.transparent 
                          : (isWin ? Colors.orange.withValues(alpha: 0.2 * 255) : (isDark ? Colors.white.withValues(alpha: 0.05 * 255) : Colors.black.withValues(alpha: 0.05 * 255))),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isWin ? Colors.orange : Colors.transparent)
                    ),
                    alignment: Alignment.center,
                    child: isWin 
                        ? const Text('🔥', style: TextStyle(fontSize: 16))
                        : Text(day.toString(), style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 12)),
                  );
                },
              )
            ],
          );
        },
      ),
    );
  }
}