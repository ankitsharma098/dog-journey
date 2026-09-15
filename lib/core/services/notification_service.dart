import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/device_locale.dart';

/// Local notifications for vaccine/medication reminders (HP-4, HP-5).
/// Scheduling logic (offsets, dedupe, timezone-aware fire times) is
/// built with the Health Passport feature.
///
/// [init] only sets up the plugin and timezone — it must NOT prompt for
/// permission. Asking on cold boot, before the user has done anything
/// that needs a reminder, tanks opt-in rates; [requestPermission] is
/// called later, the first time a screen actually schedules one (e.g.
/// saving a vaccine due date).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await DeviceLocale.timezone()));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  FlutterLocalNotificationsPlugin get plugin => _plugin;
}
