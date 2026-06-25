import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../collection/services/collection_commitment_notification_service.dart';

class PortfolioSyncNotificationService {
  PortfolioSyncNotificationService._();

  static const _channelId = 'cartera_sync';
  static const _notificationId = 9001;

  static Future<void> showTomorrowPortfolioReady({
    required int clientCount,
    required String assignmentDate,
  }) async {
    await CollectionCommitmentNotificationService.initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Sincronizacion de cartera',
      channelDescription:
          'Avisos cuando la cartera del dia siguiente esta disponible',
      importance: Importance.high,
      priority: Priority.high,
    );

    await FlutterLocalNotificationsPlugin().show(
      _notificationId,
      'Tu cartera de manana esta lista',
      '$clientCount clientes asignados para $assignmentDate.',
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> scheduleNightlySyncReminder({
    required DateTime scheduledAt,
  }) async {
    await CollectionCommitmentNotificationService.initialize();

    final when = scheduledAt.isAfter(DateTime.now())
        ? scheduledAt
        : DateTime.now().add(const Duration(minutes: 1));

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Sincronizacion de cartera',
      channelDescription:
          'Avisos cuando la cartera del dia siguiente esta disponible',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await FlutterLocalNotificationsPlugin().zonedSchedule(
      _notificationId + 1,
      'Sincronizando cartera nocturna',
      'Descargando la cartera de manana...',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
