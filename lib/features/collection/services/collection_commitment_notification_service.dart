import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class CollectionCommitmentNotificationService {
  CollectionCommitmentNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static var _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> scheduleCommitment({
    required String clientId,
    required String clientName,
    required double amount,
    required DateTime commitmentDate,
  }) async {
    await initialize();

    final scheduled = DateTime(
      commitmentDate.year,
      commitmentDate.month,
      commitmentDate.day,
      9,
    );
    final when = scheduled.isAfter(DateTime.now())
        ? scheduled
        : DateTime.now().add(const Duration(minutes: 1));

    final notificationId = clientId.hashCode.abs() % 100000;
    const androidDetails = AndroidNotificationDetails(
      'cobranza_compromisos',
      'Compromisos de cobranza',
      channelDescription: 'Recordatorios de pagos acordados en campo',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      notificationId,
      'Compromiso de pago',
      '$clientName — S/ ${amount.toStringAsFixed(2)}',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}
