import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Initialize the raw timezone database FIRST
    tz.initializeTimeZones();
    
    // 2. 🚀 BULLETPROOF TIMEZONE CHECK (Fixed for new package version)
    String timeZoneName;
    try {
      // The new package returns an object, so we grab it dynamically
      dynamic localTz = await FlutterTimezone.getLocalTimezone();
      // Extract the string whether it's the old version (String) or new version (.name)
      timeZoneName = localTz is String ? localTz : localTz.name;
    } catch (e) {
      debugPrint("⚠️ Could not fetch device timezone, falling back to IST");
      timeZoneName = 'Asia/Kolkata'; // Fallback to Indian Standard Time
    }
    
    // 3. Force the app to lock onto this specific local timezone
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint("⏰ App Timezone successfully locked to: $timeZoneName");

    // 4. Initialize Notifications
    try {
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidInit);
      
      await _notificationsPlugin.initialize(settings: initSettings);
    } catch (e) {
      debugPrint("Notification Init Error: $e");
    }
  }
  // 🚀 INSTANT TEST FUNCTION
  static Future<void> showTestNotification() async {
    await _notificationsPlugin.show(
      id: 99,
      title: 'Testing 1..2..3 🚀',
      body: 'If you see this, notifications are working perfectly on your phone!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel', 
          'Test Notifications', 
          importance: Importance.max, 
          priority: Priority.high,
          icon: '@mipmap/ic_launcher'
        ),
      ),
    );
  }

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    // ASK FOR PERMISSIONS
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _notificationsPlugin.cancelAll(); 

    // 🚀 CRITICAL MATH: now perfectly synced to local time!
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    
    // If the time they picked has already passed today, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint("🔥 ALARM SECURED FOR: $scheduledDate (Local Time)");

    await _notificationsPlugin.zonedSchedule(
      id: 0,
      title: '🔥 Protect Your Streak!',
      body: 'You have pending tasks today. Complete them before midnight so you don\'t lose your progress!',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel', 
          'Habit Reminders', 
          importance: Importance.max, 
          priority: Priority.high,
          icon: '@mipmap/ic_launcher'
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, 
    );
  }

  static Future<void> cancelReminders() async {
    await _notificationsPlugin.cancelAll();
  }
}