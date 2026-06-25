import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/portfolio_alert.dart';

class PortfolioAlertsRepository {
  PortfolioAlertsRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
    required SharedPreferences preferences,
  }) : _client = client,
       _advisorId = advisorId,
       _preferences = preferences;

  final supabase.SupabaseClient _client;
  final String _advisorId;
  final SharedPreferences _preferences;

  static const _selectQuery = '''
    id,
    cliente_id,
    tipo_alerta,
    mensaje,
    leida,
    created_at,
    clientes (
      nombres,
      apellidos
    )
  ''';

  String get _cacheKey => 'alertas_cartera_$_advisorId';

  Future<List<PortfolioAlert>> fetchAlerts() async {
    try {
      final rows = await _client
          .from('alertas_cartera')
          .select(_selectQuery)
          .eq('asesor_id', _advisorId)
          .order('created_at', ascending: false);

      final alerts = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PortfolioAlert.fromJson)
          .toList();
      await _cacheAlerts(alerts);
      return alerts;
    } catch (_) {
      return _loadCachedAlerts();
    }
  }

  Future<void> markAsRead(String alertId) async {
    await _client
        .from('alertas_cartera')
        .update({'leida': true})
        .eq('id', alertId)
        .eq('asesor_id', _advisorId);
  }

  supabase.RealtimeChannel subscribeToInserts(void Function() onChange) {
    final channel = _client.channel('alertas_cartera_$_advisorId');
    channel
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alertas_cartera',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'asesor_id',
            value: _advisorId,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.update,
          schema: 'public',
          table: 'alertas_cartera',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'asesor_id',
            value: _advisorId,
          ),
          callback: (_) => onChange(),
        );
    channel.subscribe();
    return channel;
  }

  Future<void> _cacheAlerts(List<PortfolioAlert> alerts) async {
    await _preferences.setString(
      _cacheKey,
      jsonEncode(
        alerts
            .map(
              (alert) => {
                'id': alert.id,
                'cliente_id': alert.clientId,
                'clientName': alert.clientName,
                'tipo_alerta': alert.type.code,
                'mensaje': alert.message,
                'leida': alert.isRead,
                'created_at': alert.createdAt.toIso8601String(),
              },
            )
            .toList(),
      ),
    );
  }

  List<PortfolioAlert> _loadCachedAlerts() {
    final raw = _preferences.getString(_cacheKey);
    if (raw == null) {
      return [];
    }

    return (jsonDecode(raw) as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      return PortfolioAlert(
        id: json['id'].toString(),
        clientId: json['cliente_id'].toString(),
        clientName: json['clientName'].toString(),
        type: PortfolioAlertType.fromCode(json['tipo_alerta']?.toString()),
        message: json['mensaje'].toString(),
        isRead: json['leida'] == true,
        createdAt: DateTime.parse(json['created_at'].toString()),
      );
    }).toList();
  }
}
