import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/advisor_notification_models.dart';

class AdvisorNotificationsRepository {
  AdvisorNotificationsRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
  }) : _client = client,
       _advisorId = advisorId;

  final supabase.SupabaseClient _client;
  final String _advisorId;

  Future<List<AdvisorNotification>> fetchNotifications() async {
    final rows = await _client
        .from('notificaciones_asesor')
        .select(
          'id, asesor_id, tipo, titulo, mensaje, referencia_tipo, '
          'referencia_id, leida, created_at',
        )
        .or('asesor_id.eq.$_advisorId,asesor_id.is.null')
        .order('created_at', ascending: false)
        .limit(50);

    final readBroadcastIds = await _fetchReadBroadcastIds();

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => AdvisorNotification.fromJson(
            row,
            readBroadcastIds: readBroadcastIds,
          ),
        )
        .toList();
  }

  Future<int> countUnread() async {
    final notifications = await fetchNotifications();
    return notifications.where((item) => !item.isRead).length;
  }

  Future<void> markAsRead(AdvisorNotification notification) async {
    await _client.rpc(
      'marcar_notificacion_asesor_leida',
      params: {'p_notificacion_id': notification.id},
    );
  }

  supabase.RealtimeChannel subscribeToChanges(void Function() onChange) {
    return _client
        .channel('notificaciones_asesor_$_advisorId')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_asesor',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<Set<String>> _fetchReadBroadcastIds() async {
    try {
      final rows = await _client
          .from('notificaciones_asesor_lectura')
          .select('notificacion_id')
          .eq('asesor_id', _advisorId);

      return (rows as List)
          .map((row) => row['notificacion_id'].toString())
          .toSet();
    } catch (_) {
      return {};
    }
  }
}
