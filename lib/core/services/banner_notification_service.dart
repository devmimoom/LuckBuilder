import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/banner_promotion/models/banner_item.dart';
import '../../features/banner_promotion/models/banner_schedule_snapshot.dart';

/// iOS 本地橫幅通知（立即顯示與每日排程）。
class BannerNotificationService {
  BannerNotificationService._();
  static final BannerNotificationService instance = BannerNotificationService._();

  static const int maxNotificationBodyLength = 220;

  /// 排程通知 ID 區間 [base, base + maxBannerScheduleSlots)
  static const int bannerScheduleIdBase = 10000;
  static const int maxBannerScheduleSlots = 32;

  static const String prefKeyEnabled = 'banner_notifications_enabled';
  static const String prefKeyScheduleSnapshot = 'banner_schedule_snapshot_v1';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  String truncateForNotificationBody(String content) {
    final t = content.trim();
    if (t.length <= maxNotificationBodyLength) return t;
    return '${t.substring(0, maxNotificationBodyLength)}…';
  }

  Future<bool> requestIosNotificationPermission() async {
    if (!Platform.isIOS) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;
    final granted = await ios.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  Future<void> cancelBannerScheduledNotifications() async {
    if (!_initialized) await init();
    for (var i = 0; i < maxBannerScheduleSlots; i++) {
      await _plugin.cancel(id: bannerScheduleIdBase + i);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 依每日 [timesOfDay] 筆數建立重複推播（內容輪播 [items]）。
  /// 僅 iOS 會實際排程；其他平台只寫入 [prefKeyEnabled]。
  Future<void> enableBannerSchedule({
    required List<BannerItem> items,
    required List<TimeOfDay> timesOfDay,
    BannerScheduleSnapshot? scheduleSnapshot,
  }) async {
    if (items.isEmpty) {
      throw StateError('NO_ITEMS');
    }
    if (timesOfDay.isEmpty) {
      throw StateError('NO_TIMES');
    }
    if (timesOfDay.length > maxBannerScheduleSlots) {
      throw StateError('TOO_MANY_TIMES');
    }

    if (!_initialized) await init();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEnabled, true);
    if (scheduleSnapshot != null) {
      await prefs.setString(
        prefKeyScheduleSnapshot,
        jsonEncode(scheduleSnapshot.toJson()),
      );
    }

    await cancelBannerScheduledNotifications();

    if (!Platform.isIOS) {
      return;
    }

    final permitted = await requestIosNotificationPermission();
    if (!permitted) {
      await prefs.setBool(prefKeyEnabled, false);
      throw StateError('NOT_PERMITTED');
    }

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (var i = 0; i < timesOfDay.length; i++) {
      final item = items[i % items.length];
      final t = timesOfDay[i];
      final scheduled = _nextInstanceOfTime(t);

      await _plugin.zonedSchedule(
        id: bannerScheduleIdBase + i,
        title: item.pushTitle.isNotEmpty ? item.pushTitle : item.itemId,
        body: truncateForNotificationBody(item.content),
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.itemId,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// 關閉排程並清除啟用狀態。
  Future<void> disableBannerNotifications() async {
    if (!_initialized) await init();
    await cancelBannerScheduledNotifications();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEnabled, false);
    await prefs.remove(prefKeyScheduleSnapshot);
  }

  Future<BannerScheduleSnapshot?> loadScheduleSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKeyScheduleSnapshot);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return BannerScheduleSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isBannerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKeyEnabled) ?? false;
  }
}
