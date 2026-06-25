import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/dashboard_summary.dart';

/// Embed PostgREST: 014 agrega solicitud_id en cartera_diaria ademas de
/// cartera_diaria_id en solicitudes_credito; hay que desambiguar la FK.
const _solicitudCarteraEmbed =
    'cartera_diaria!solicitudes_credito_cartera_diaria_id_fkey';

class DashboardRepository {
  DashboardRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
    required String agencyId,
  }) : _client = client,
       _advisorId = advisorId,
       _agencyId = agencyId;

  final supabase.SupabaseClient _client;
  final String _advisorId;
  final String _agencyId;

  static String _todayKey() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
  }

  Future<DashboardSummary> fetchSummary({required bool includeAgencyApproval}) async {
    final today = _todayKey();
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);

    final carteraRows = await _client
        .from('cartera_diaria')
        .select('estado_visita, timestamp_visita, creditos(monto_desembolsado, saldo_actual)')
        .eq('asesor_id', _advisorId)
        .eq('fecha_asignacion', today);

    final visits = (carteraRows as List).cast<Map<String, dynamic>>();
    var managedToday = 0;
    var portfolioAmount = 0.0;

    for (final row in visits) {
      final status = (row['estado_visita'] ?? '').toString();
      if (status == 'visitado') {
        managedToday++;
      }

      final credito = row['creditos'];
      if (credito is Map) {
        portfolioAmount += (credito['saldo_actual'] as num?)?.toDouble() ??
            (credito['monto_desembolsado'] as num?)?.toDouble() ??
            0;
      }
    }

    final totalInPortfolio = visits.length;
    final pendingVisits = totalInPortfolio - managedToday;

    final approvedRows = await _client
        .from('solicitudes_credito')
        .select('id')
        .eq('asesor_id', _advisorId)
        .eq('estado', 'aprobada')
        .gte('updated_at', monthStart.toIso8601String());

    var readyForApproval = 0;
    if (includeAgencyApproval) {
      final evalRows = await _client
          .from('solicitudes_credito')
          .select(
            'id, $_solicitudCarteraEmbed(estado_visita), '
            'pre_evaluaciones_solicitud(calificacion), consultas_buro(id)',
          )
          .eq('origen', 'app_cliente')
          .eq('agencia_id', _agencyId)
          .eq('estado', 'en_evaluacion');

      for (final row in (evalRows as List).cast<Map<String, dynamic>>()) {
        if (_isReadyForApproval(row)) {
          readyForApproval++;
        }
      }
    }

    return DashboardSummary(
      pendingVisits: pendingVisits,
      totalInPortfolio: totalInPortfolio,
      managedToday: managedToday,
      portfolioAmount: portfolioAmount,
      approvedThisMonth: (approvedRows as List).length,
      readyForApproval: readyForApproval,
    );
  }

  bool _isReadyForApproval(Map<String, dynamic> row) {
    final cartera = row['cartera_diaria'];
    var visitOk = false;
    if (cartera is Map) {
      visitOk = (cartera['estado_visita'] ?? '').toString() == 'visitado';
    } else if (cartera is List && cartera.isNotEmpty) {
      final first = cartera.first;
      if (first is Map) {
        visitOk = (first['estado_visita'] ?? '').toString() == 'visitado';
      }
    }

    final preEval = row['pre_evaluaciones_solicitud'];
    var apto = false;
    if (preEval is Map) {
      apto = (preEval['calificacion'] ?? '').toString().toUpperCase() == 'APTO';
    } else if (preEval is List && preEval.isNotEmpty) {
      final first = preEval.first;
      if (first is Map) {
        apto = (first['calificacion'] ?? '').toString().toUpperCase() == 'APTO';
      }
    }

    final buro = row['consultas_buro'];
    final hasBuro = buro is List && buro.isNotEmpty;

    return visitOk && apto && hasBuro;
  }
}
