import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../credit_request/models/pipeline_models.dart';
import '../models/supervision_models.dart';

class SupervisionRepository {
  SupervisionRepository({
    required supabase.SupabaseClient client,
    required String agencyId,
  }) : _client = client,
       _agencyId = agencyId;

  final supabase.SupabaseClient _client;
  final String _agencyId;

  static String _dateOnly(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }

  static DateTime _monthStart(DateTime month) {
    return DateTime(month.year, month.month);
  }

  static DateTime _monthEnd(DateTime month) {
    return DateTime(month.year, month.month + 1);
  }

  Future<List<AgencyAdvisor>> fetchActiveAdvisors() async {
    final rows = await _client
        .from('asesores_negocio')
        .select('id, codigo_empleado, nombres, apellidos')
        .eq('agencia_id', _agencyId)
        .eq('activo', true)
        .order('apellidos');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AgencyAdvisor.fromJson)
        .toList();
  }

  Future<List<AdvisorCoverageSnapshot>> fetchCoverageForDate(
    DateTime date,
  ) async {
    final advisors = await fetchActiveAdvisors();
    final dateKey = _dateOnly(date);

    final rows = await _client
        .from('cartera_diaria')
        .select(
          'asesor_id, estado_visita, timestamp_visita, lat_visita, lng_visita',
        )
        .eq('agencia_id', _agencyId)
        .eq('fecha_asignacion', dateKey);

    final visits = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(DailyPortfolioVisitRow.fromJson)
        .toList();

    return advisors.map((advisor) {
      final advisorVisits =
          visits.where((visit) => visit.advisorId == advisor.id).toList();
      final visitedCount = advisorVisits
          .where((visit) => visit.visitStatus.isCompleted)
          .length;

      DailyPortfolioVisitRow? lastLocatedVisit;
      for (final visit in advisorVisits) {
        if (visit.latitude == null || visit.longitude == null) {
          continue;
        }
        if (lastLocatedVisit == null) {
          lastLocatedVisit = visit;
          continue;
        }
        final currentTs = visit.timestampVisit;
        final previousTs = lastLocatedVisit.timestampVisit;
        if (currentTs != null &&
            (previousTs == null || currentTs.isAfter(previousTs))) {
          lastLocatedVisit = visit;
        }
      }

      DateTime? lastSyncAt;
      for (final visit in advisorVisits) {
        final timestamp = visit.timestampVisit;
        if (timestamp == null) {
          continue;
        }
        if (lastSyncAt == null || timestamp.isAfter(lastSyncAt)) {
          lastSyncAt = timestamp;
        }
      }

      return AdvisorCoverageSnapshot(
        advisor: advisor,
        totalAssigned: advisorVisits.length,
        visitedCount: visitedCount,
        lastSyncAt: lastSyncAt,
        lastLatitude: lastLocatedVisit?.latitude,
        lastLongitude: lastLocatedVisit?.longitude,
      );
    }).toList();
  }

  Future<AgencyProductivityReport> fetchProductivityForMonth(
    DateTime month,
  ) async {
    final advisors = await fetchActiveAdvisors();
    final start = _monthStart(month);
    final end = _monthEnd(month);

    final rows = await _client
        .from('solicitudes_credito')
        .select('asesor_id, estado, monto_aprobado, created_at')
        .eq('agencia_id', _agencyId)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());

    final requests = (rows as List).cast<Map<String, dynamic>>();

    final reportRows = advisors.map((advisor) {
      final advisorRequests = requests
          .where((row) => row['asesor_id'].toString() == advisor.id)
          .toList();

      var submitted = 0;
      var approved = 0;
      var disbursed = 0;
      var disbursedAmount = 0.0;

      for (final row in advisorRequests) {
        final status = SolicitudPipelineStatus.fromCode(row['estado']?.toString());
        if (status == SolicitudPipelineStatus.borrador) {
          continue;
        }

        submitted++;
        if (status == SolicitudPipelineStatus.aprobada ||
            status == SolicitudPipelineStatus.desembolsada) {
          approved++;
        }
        if (status == SolicitudPipelineStatus.desembolsada) {
          disbursed++;
          disbursedAmount +=
              (row['monto_aprobado'] as num?)?.toDouble() ?? 0;
        }
      }

      return AdvisorProductivityRow(
        advisor: advisor,
        submittedCount: submitted,
        approvedCount: approved,
        disbursedCount: disbursed,
        disbursedAmount: disbursedAmount,
      );
    }).toList();

    return AgencyProductivityReport(month: start, rows: reportRows);
  }

  supabase.RealtimeChannel subscribeToCoverageChanges(
    void Function() onChange,
  ) {
    final channel = _client.channel('cartera_cobertura_$_agencyId');
    channel
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'cartera_diaria',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'agencia_id',
            value: _agencyId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }
}
