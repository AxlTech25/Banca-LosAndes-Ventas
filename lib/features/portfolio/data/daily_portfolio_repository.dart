import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/daily_client.dart';
import '../../route/data/geofence_repository.dart';

class DailyPortfolioRepository {
  DailyPortfolioRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
    required SharedPreferences preferences,
    Connectivity? connectivity,
  }) : _client = client,
       _advisorId = advisorId,
       _preferences = preferences,
       _connectivity = connectivity ?? Connectivity();

  final supabase.SupabaseClient _client;
  final String _advisorId;
  final SharedPreferences _preferences;
  final Connectivity _connectivity;

  static const _portfolioSelect = '''
    id,
    asesor_id,
    cliente_id,
    agencia_id,
    credito_id,
    fecha_asignacion,
    tipo_gestion,
    prioridad,
    score_prioridad,
    estado_visita,
    resultado_visita,
    observacion_visita,
    timestamp_visita,
    lat_visita,
    lng_visita,
    orden_manual,
    solicitud_id,
    clientes (
      id,
      nombres,
      apellidos,
      numero_documento,
      lat,
      lng
    ),
    creditos (
      saldo_actual,
      monto_desembolsado,
      dias_mora
    )
  ''';

  String get _lastSyncKey => 'cartera_diaria_last_sync_$_advisorId';
  String get _pendingVisitsKey => 'visitas_pendientes_$_advisorId';
  String get _queryDateKey => 'cartera_fecha_consulta_$_advisorId';

  String _cacheKeyFor(String queryDate) =>
      'cartera_diaria_${_advisorId}_$queryDate';

  String _orderKeyFor(String queryDate) =>
      'cartera_orden_local_${_advisorId}_$queryDate';

  DateTime? get lastSyncAt {
    final value = _preferences.getString(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<List<DailyClient>> loadCachedPortfolio() async {
    final queryDate = await _queryDateForCache();
    final content = _preferences.getString(_cacheKeyFor(queryDate));
    if (content == null || content.isEmpty) {
      return [];
    }

    final rows = jsonDecode(content) as List<dynamic>;
    final clients = rows
        .cast<Map<String, dynamic>>()
        .map(DailyClient.fromJson)
        .toList();
    return _applyLocalOrder(clients, queryDate);
  }

  Future<List<DailyClient>> refreshTodayPortfolio() async {
    final queryDate = await _resolveQueryDate();
    var clients = await _fetchPortfolioForDate(queryDate);
    if (clients.isEmpty) {
      final latestDate = await _latestAssignmentDate();
      if (latestDate != null && latestDate != queryDate) {
        clients = await _fetchPortfolioForDate(latestDate);
        await _preferences.setString(_queryDateKey, latestDate);
      }
    } else {
      await _preferences.setString(_queryDateKey, queryDate);
    }

    final activeDate =
        _preferences.getString(_queryDateKey) ?? queryDate;
    await _savePortfolio(clients, activeDate);
    await _preferences.setString(
      _lastSyncKey,
      DateTime.now().toIso8601String(),
    );
    return _applyLocalOrder(clients, activeDate);
  }

  Future<void> saveManualOrder(List<DailyClient> clients) async {
    final queryDate = await _queryDateForCache();
    final orderedIds = clients.map((client) => client.id).toList();
    await _preferences.setString(
      _orderKeyFor(queryDate),
      jsonEncode(orderedIds),
    );
  }

  Future<void> saveVisitResult({
    required DailyClient client,
    required VisitStatus status,
    required String observation,
  }) async {
    final now = DateTime.now();
    final position = await _currentPosition();
    final payload = <String, Object?>{
      'estado_visita': status.code,
      'resultado_visita': status.label,
      'observacion_visita': observation,
      'timestamp_visita': now.toIso8601String(),
      'lat_visita': position?.latitude,
      'lng_visita': position?.longitude,
      'pendiente_sync': false,
    };

    if (await _hasNetwork()) {
      await _client.from('cartera_diaria').update(payload).eq('id', client.id);
    } else {
      await _queuePendingVisit(client.id, payload);
    }

    final cached = await loadCachedPortfolio();
    final updated = cached
        .map(
          (item) => item.id == client.id
              ? item.copyWith(visitStatus: status, observation: observation)
              : item,
        )
        .toList();
    final queryDate = await _queryDateForCache();
    await _savePortfolio(updated, queryDate);
  }

  Future<void> syncPendingVisits() async {
    if (!await _hasNetwork()) {
      return;
    }

    final content = _preferences.getString(_pendingVisitsKey);
    if (content == null || content.isEmpty) {
      return;
    }

    final rows = (jsonDecode(content) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final remaining = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final id = row['id'].toString();
        final payload = Map<String, Object?>.from(row['payload'] as Map);
        payload['pendiente_sync'] = false;
        await _client.from('cartera_diaria').update(payload).eq('id', id);
      } catch (_) {
        remaining.add(row);
      }
    }

    await _preferences.setString(_pendingVisitsKey, jsonEncode(remaining));
  }

  Future<List<DailyClient>> _fetchPortfolioForDate(String queryDate) async {
    final rows = await _client
        .from('cartera_diaria')
        .select(_portfolioSelect)
        .eq('asesor_id', _advisorId)
        .eq('fecha_asignacion', queryDate)
        .order('score_prioridad', ascending: false);

    return rows
        .cast<Map<String, dynamic>>()
        .map(DailyClient.fromJson)
        .toList();
  }

  Future<String> _resolveQueryDate() async {
    try {
      final result = await _client.rpc('business_today');
      return _normalizeDate(result);
    } catch (_) {
      return _dateOnly(DateTime.now());
    }
  }

  Future<String?> _latestAssignmentDate() async {
    try {
      final row = await _client
          .from('cartera_diaria')
          .select('fecha_asignacion')
          .eq('asesor_id', _advisorId)
          .order('fecha_asignacion', ascending: false)
          .limit(1)
          .maybeSingle();
      final value = row?['fecha_asignacion'];
      if (value == null) {
        return null;
      }
      return _normalizeDate(value);
    } catch (_) {
      return null;
    }
  }

  Future<String> _queryDateForCache() async {
    final stored = _preferences.getString(_queryDateKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return _resolveQueryDate();
  }

  Future<void> _savePortfolio(
    List<DailyClient> clients,
    String queryDate,
  ) async {
    await _preferences.setString(
      _cacheKeyFor(queryDate),
      jsonEncode(clients.map((client) => client.toJson()).toList()),
    );
  }

  List<DailyClient> _applyLocalOrder(
    List<DailyClient> clients,
    String queryDate,
  ) {
    final content = _preferences.getString(_orderKeyFor(queryDate));
    final order = content == null
        ? <String>[]
        : (jsonDecode(content) as List<dynamic>)
              .map((value) => '$value')
              .toList();
    if (order.isEmpty) {
      return _systemSorted(clients);
    }

    final indexById = <String, int>{
      for (var i = 0; i < order.length; i++) order[i]: i,
    };
    final sorted = List<DailyClient>.from(clients);
    sorted.sort((a, b) {
      final aOrder = indexById[a.id];
      final bOrder = indexById[b.id];
      if (aOrder != null && bOrder != null) {
        return aOrder.compareTo(bOrder);
      }
      if (aOrder != null) {
        return -1;
      }
      if (bOrder != null) {
        return 1;
      }
      return b.priorityScore.compareTo(a.priorityScore);
    });
    return sorted;
  }

  List<DailyClient> _systemSorted(List<DailyClient> clients) {
    final sorted = List<DailyClient>.from(clients);
    sorted.sort((a, b) {
      if (a.isVisited != b.isVisited) {
        return a.isVisited ? 1 : -1;
      }
      return b.priorityScore.compareTo(a.priorityScore);
    });
    return sorted;
  }

  Future<void> _queuePendingVisit(
    String clientId,
    Map<String, Object?> payload,
  ) async {
    final content = _preferences.getString(_pendingVisitsKey);
    final rows = content == null || content.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(content) as List<dynamic>).cast<Map<String, dynamic>>();
    rows.add({
      'id': clientId,
      'payload': {...payload, 'pendiente_sync': true},
      'created_at': DateTime.now().toIso8601String(),
    });
    await _preferences.setString(_pendingVisitsKey, jsonEncode(rows));
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((state) => state != ConnectivityResult.none);
  }

  Future<Position?> _currentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String _normalizeDate(Object? value) {
    final raw = value.toString();
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<TomorrowPortfolioPrefetch> prefetchTomorrowPortfolio() async {
    final tomorrow = _dateOnly(DateTime.now().add(const Duration(days: 1)));
    final clients = await _fetchPortfolioForDate(tomorrow);
    await _savePortfolio(clients, tomorrow);
    await _preferences.setString('cartera_manana_fecha_$_advisorId', tomorrow);
    await _preferences.setInt('cartera_manana_count_$_advisorId', clients.length);
    await _preferences.setString(
      'cartera_manana_sync_at_$_advisorId',
      DateTime.now().toIso8601String(),
    );
    return TomorrowPortfolioPrefetch(
      assignmentDate: tomorrow,
      clientCount: clients.length,
    );
  }

  Future<NightlySyncResult> runFullNightlySync() async {
    final tomorrowResult = await prefetchTomorrowPortfolio();
    final todayClients = await refreshTodayPortfolio();
    final tomorrowClients =
        await _fetchPortfolioForDate(tomorrowResult.assignmentDate);

    final clientIds = <String>{
      ...todayClients.map((client) => client.clientId),
      ...tomorrowClients.map((client) => client.clientId),
    };

    var profilesCached = 0;
    for (final clientId in clientIds) {
      try {
        final row = await _client
            .from('clientes')
            .select('id')
            .eq('id', clientId)
            .maybeSingle();
        if (row == null) {
          continue;
        }
        final credits = await _client
            .from('creditos')
            .select('id, saldo_actual, dias_mora, cuotas_pagadas, cuotas_total')
            .eq('cliente_id', clientId)
            .order('fecha_desembolso', ascending: false)
            .limit(5);
        await _preferences.setString(
          'ficha_resumen_${_advisorId}_$clientId',
          jsonEncode({
            'cliente_id': clientId,
            'creditos': credits,
            'cached_at': DateTime.now().toIso8601String(),
          }),
        );
        profilesCached++;
      } catch (_) {}
    }

    final now = DateTime.now();
    await _preferences.setString(_lastSyncKey, now.toIso8601String());
    await _preferences.setString(
      'cartera_nightly_complete_$_advisorId',
      now.toIso8601String(),
    );

    return NightlySyncResult(
      assignmentDate: tomorrowResult.assignmentDate,
      portfolioClientCount: tomorrowResult.clientCount,
      profilesCached: profilesCached,
      syncedAt: now,
    );
  }

  Future<bool> isInsideWorkZone() async {
    final position = await _currentPosition();
    if (position == null) {
      return true;
    }

    final geofenceRepository = GeofenceRepository(client: _client);
    final zones = await geofenceRepository.fetchZonesForAdvisor(_advisorId);
    if (zones.isEmpty) {
      return true;
    }

    return geofenceRepository.isInsideAnyZone(
      position.latitude,
      position.longitude,
      zones,
    );
  }
}

class NightlySyncResult {
  const NightlySyncResult({
    required this.assignmentDate,
    required this.portfolioClientCount,
    required this.profilesCached,
    required this.syncedAt,
  });

  final String assignmentDate;
  final int portfolioClientCount;
  final int profilesCached;
  final DateTime syncedAt;
}

class TomorrowPortfolioPrefetch {
  const TomorrowPortfolioPrefetch({
    required this.assignmentDate,
    required this.clientCount,
  });

  final String assignmentDate;
  final int clientCount;
}
