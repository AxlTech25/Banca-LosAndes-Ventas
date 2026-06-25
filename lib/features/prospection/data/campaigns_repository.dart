import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/pre_evaluation_models.dart';

class CampaignsRepository {
  CampaignsRepository({
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
    tipo_campana,
    monto_ofertado,
    activa,
    fecha_vencimiento,
    clientes (
      nombres,
      apellidos
    )
  ''';

  String get _cacheKey => 'campanas_activas_$_advisorId';

  Future<List<ActiveCampaign>> fetchActiveCampaigns() async {
    try {
      final today = _dateOnly(DateTime.now());
      final rows = await _client
          .from('campanas_activas')
          .select(_selectQuery)
          .eq('asesor_id', _advisorId)
          .eq('activa', true)
          .gte('fecha_vencimiento', today)
          .order('fecha_vencimiento');

      final campaigns = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(ActiveCampaign.fromJson)
          .where((campaign) => !campaign.isExpired)
          .toList();
      await _cacheCampaigns(campaigns);
      return campaigns;
    } catch (_) {
      return _loadCachedCampaigns();
    }
  }

  Future<void> _cacheCampaigns(List<ActiveCampaign> campaigns) async {
    await _preferences.setString(
      _cacheKey,
      jsonEncode(
        campaigns
            .map(
              (campaign) => {
                'id': campaign.id,
                'cliente_id': campaign.clientId,
                'clientName': campaign.clientName,
                'tipo_campana': campaign.type.code,
                'monto_ofertado': campaign.offeredAmount,
                'fecha_vencimiento': campaign.expirationDate.toIso8601String(),
                'activa': campaign.isActive,
              },
            )
            .toList(),
      ),
    );
  }

  List<ActiveCampaign> _loadCachedCampaigns() {
    final raw = _preferences.getString(_cacheKey);
    if (raw == null) {
      return [];
    }

    return (jsonDecode(raw) as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      return ActiveCampaign(
        id: json['id'].toString(),
        clientId: json['cliente_id'].toString(),
        clientName: json['clientName'].toString(),
        type: CampaignType.fromCode(json['tipo_campana']?.toString()),
        offeredAmount: (json['monto_ofertado'] as num).toDouble(),
        expirationDate: DateTime.parse(json['fecha_vencimiento'].toString()),
        isActive: json['activa'] != false,
      );
    }).toList();
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
