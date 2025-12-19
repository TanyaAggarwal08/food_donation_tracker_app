import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugIN =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool isInitialized() => _isInitialized;

  // -------------------------
  // INITIALIZE
  // -------------------------
  Future<void> initialize() async {
    if (isInitialized()) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Vancouver')); // Adjust as needed

    const initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugIN.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        // When notification fires, check if admin needs it
        if (response.id == 999) {
          await _handleAdminScheduledCheck();
        }
      },
    );

    // Request notification permission for Android 13+
    await notificationsPlugIN
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  // -------------------------
  // NOTIFICATION DETAILS
  // -------------------------
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_notification_channel_id',
        'Daily Notification',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

  Future<void> showNotification(String title, String body) async {
    await notificationsPlugIN.show(
      0,
      title,
      body,
      notificationDetails(),
    );
  }

  // -------------------------
  // FIRESTORE CHECK
  // -------------------------
  Future<Map<String, dynamic>> getAdminDeliveryStatus() async {
    final fs = FirebaseFirestore.instance;

    final storeQuery = await fs.collection('stores').get();
    final List<String> allStores = storeQuery.docs
        .map((doc) => (doc.data()['name'] as String).trim())
        .toList();

    if (allStores.isEmpty) {
      return {
        'unverifiedCount': 0,
        'storesWithNoEntryToday': <String>[],
      };
    }

    final deliveryQuery = await fs.collection('deliveries').get();

    int unverifiedCount = 0;
    Set<String> storesWithEntriesToday = {};

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (var doc in deliveryQuery.docs) {
      final data = doc.data();

      if (data['verified_status'] != true) {
        unverifiedCount++;
      }

      if (data['datetime'] is Timestamp) {
        DateTime dt = (data['datetime'] as Timestamp).toDate();
        if (dt.isAfter(todayStart)) {
          String storeName = (data['store_name'] as String).trim();
          storesWithEntriesToday.add(storeName);
        }
      }
    }

    List<String> storesWithNoEntryToday = allStores
        .where((store) => !storesWithEntriesToday.contains(store))
        .toList();

    return {
      'unverifiedCount': unverifiedCount,
      'storesWithNoEntryToday': storesWithNoEntryToday,
    };
  }

  // -------------------------
  // NEXT RUN TIME HELPER
  // -------------------------
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // -------------------------
  // SCHEDULE DAILY ADMIN NOTIFICATION
  // -------------------------
  Future<void> scheduleDailyAdminNotification({int hour = 18, int minute = 0}) async {
    await notificationsPlugIN.cancel(999); // cancel existing

    final scheduledTime = _nextInstanceOfTime(hour, minute);

    try {
      await notificationsPlugIN.zonedSchedule(
        999,
        'Daily Admin Report',
        'Checking deliveries...',
        scheduledTime,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'admin_check',
      );
      print("Daily admin notification scheduled at $scheduledTime (exact).");
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        print("Exact alarms not allowed. Scheduling inexact alarm instead.");
        await notificationsPlugIN.zonedSchedule(
          999,
          'Daily Admin Report',
          'Checking deliveries...',
          scheduledTime,
          notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'admin_check',
        );
      } else {
        rethrow;
      }
    }
  }

  // -------------------------
  // ONLY SHOW NOTIFICATION IF UNVERIFIED ENTRIES EXIST
  // -------------------------
  Future<void> _handleAdminScheduledCheck() async {
    final status = await getAdminDeliveryStatus();

    final int unverified = status['unverifiedCount'];
    final List<String> noEntry = status['storesWithNoEntryToday'];

    if (unverified == 0 && noEntry.isEmpty) {
      print("No issues → skipping admin notification.");
      return;
    }

    String body = "";
    if (unverified > 0) body += "$unverified entries need verification. ";
    if (noEntry.isNotEmpty) body += "${noEntry.length} stores have no entry today.";

    await showNotification("Daily Admin Report", body);
    print("Admin notification sent: $body");
  }



  void scheduleDailyAdminCheck() {
    final now = DateTime.now();
    final sixPm = DateTime(now.year, now.month, now.day, 6, 00);
    Duration initialDelay;

    if (now.isBefore(sixPm)) {
      initialDelay = sixPm.difference(now);
    } else {
      initialDelay = sixPm.add(Duration(days: 1)).difference(now);
    }

    Timer(initialDelay, () async {
      await _handleAdminScheduledCheck();

      // Schedule next day
      scheduleDailyAdminCheck();
    });
  }
}
