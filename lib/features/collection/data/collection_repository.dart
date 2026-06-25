import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../portfolio/models/daily_client.dart';
import '../models/collection_models.dart';
import '../services/collection_commitment_notification_service.dart';

class CollectionRepository {
  CollectionRepository({
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

  String get _pendingActionsKey => 'acciones_cobranza_pendientes_$_advisorId';
  String get _actionsCacheKey => 'acciones_cobranza_cache_$_advisorId';

  static const _overdueSelect = '''
    id,
    cliente_id,
    credito_id,
    dias_mora,
    monto_vencido,
    fecha_ultimo_contacto,
    clientes (
      nombres,
      apellidos,
      numero_documento
    ),
    creditos (
      dias_mora,
      saldo_actual
    )
  ''';

  Future<List<OverdueClientEntry>> fetchOverduePortfolio({
    List<DailyClient> portfolioFallback = const [],
  }) async {
    try {
      final rows = await _client
          .from('cartera_vencida')
          .select(_overdueSelect)
          .eq('asesor_id', _advisorId)
          .order('dias_mora', ascending: false);

      final entries = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(OverdueClientEntry.fromJson)
          .toList();

      if (entries.isNotEmpty) {
        return _attachPortfolioIds(entries, portfolioFallback);
      }
    } catch (_) {
      // Fallback a clientes en mora de la cartera diaria.
    }

    return portfolioFallback
        .where(
          (client) =>
              client.managementType == ManagementType.recovery ||
              client.daysPastDue > 0,
        )
        .map(OverdueClientEntry.fromDailyClient)
        .toList();
  }

  Future<List<CollectionActionRecord>> fetchRecentActions({
    int limit = 20,
  }) async {
    try {
      final rows = await _client
          .from('acciones_cobranza')
          .select('''
            id,
            cliente_id,
            tipo_gestion,
            resultado,
            monto_pagado,
            fecha_compromiso,
            monto_compromiso,
            observaciones,
            timestamp_gestion,
            clientes ( nombres, apellidos )
          ''')
          .eq('asesor_id', _advisorId)
          .order('timestamp_gestion', ascending: false)
          .limit(limit);

      final actions = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(CollectionActionRecord.fromJson)
          .toList();
      await _cacheActions(actions);
      return actions;
    } catch (_) {
      return _loadCachedActions();
    }
  }

  Future<CollectionBoardSummary> fetchSummary({
    required List<OverdueClientEntry> overdueClients,
    required List<CollectionActionRecord> recentActions,
  }) async {
    final today = DateTime.now();
    final actionsToday = recentActions.where((action) {
      return action.registeredAt.year == today.year &&
          action.registeredAt.month == today.month &&
          action.registeredAt.day == today.day;
    }).length;

    final totalOverdue = overdueClients.fold<double>(
      0,
      (sum, entry) => sum + entry.overdueAmount,
    );

    return CollectionBoardSummary(
      overdueClients: overdueClients.length,
      totalOverdueAmount: totalOverdue,
      actionsToday: actionsToday,
    );
  }

  Future<void> registerAction({
    required OverdueClientEntry client,
    required CollectionActionFormData form,
    String? portfolioEntryId,
  }) async {
    final validation = form.validate();
    if (validation != null) {
      throw StateError(validation);
    }

    if (client.creditId.isEmpty) {
      throw StateError('El cliente no tiene credito asociado.');
    }

    final position = await _currentPosition();
    final payload = form.toPayload(
      advisorId: _advisorId,
      clientId: client.clientId,
      creditId: client.creditId,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );

    if (await _hasNetwork()) {
      await _persistAction(
        payload: payload,
        client: client,
        overdueEntryId: client.id,
        portfolioEntryId: portfolioEntryId ?? client.portfolioEntryId,
        form: form,
      );
      return;
    }

    await _queueAction({
      'payload': payload,
      'overdue_entry_id': client.id,
      'portfolio_entry_id': portfolioEntryId ?? client.portfolioEntryId,
      'client_id': client.clientId,
      'client_name': client.clientName,
      'overdue_amount': client.overdueAmount,
      'form': _formToMap(form),
    });
  }

  Future<void> syncPendingActions() async {
    if (!await _hasNetwork()) {
      return;
    }

    final queue = _loadPendingQueue();
    if (queue.isEmpty) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        final payload = Map<String, dynamic>.from(item['payload'] as Map);
        final formMap = Map<String, dynamic>.from(item['form'] as Map);
        final form = _formFromMap(formMap);
        final client = OverdueClientEntry(
          id: item['overdue_entry_id']?.toString() ?? '',
          clientId: item['client_id']?.toString() ?? '',
          creditId: payload['credito_id']?.toString() ?? '',
          clientName: item['client_name']?.toString() ?? 'Cliente',
          documentNumber: '',
          daysPastDue: 0,
          overdueAmount: (item['overdue_amount'] as num?)?.toDouble() ?? 0,
        );
        await _persistAction(
          payload: payload,
          client: client,
          overdueEntryId: item['overdue_entry_id']?.toString() ?? '',
          portfolioEntryId: item['portfolio_entry_id']?.toString(),
          form: form,
        );
      } catch (_) {
        remaining.add(item);
      }
    }

    await _preferences.setString(_pendingActionsKey, jsonEncode(remaining));
  }

  Future<void> _persistAction({
    required Map<String, dynamic> payload,
    required OverdueClientEntry client,
    required String overdueEntryId,
    required CollectionActionFormData form,
    String? portfolioEntryId,
  }) async {
    await _client.from('acciones_cobranza').insert(payload);

    if (_isUuid(overdueEntryId)) {
      await _touchOverdueContact(overdueEntryId);
      await _applyOverdueBalanceUpdate(
        overdueEntryId: overdueEntryId,
        form: form,
        currentOverdueAmount: client.overdueAmount,
      );
    }

    if (portfolioEntryId != null && portfolioEntryId.isNotEmpty) {
      await _markPortfolioVisited(portfolioEntryId, form.observations);
    }

    if (form.result == CollectionResultType.paymentCommitment &&
        form.commitmentDate != null &&
        form.commitmentAmount != null) {
      await CollectionCommitmentNotificationService.scheduleCommitment(
        clientId: client.clientId,
        clientName: client.clientName,
        amount: form.commitmentAmount!,
        commitmentDate: form.commitmentDate!,
      );
    }
  }

  Future<void> _applyOverdueBalanceUpdate({
    required String overdueEntryId,
    required CollectionActionFormData form,
    required double currentOverdueAmount,
  }) async {
    if (form.result == CollectionResultType.fullPayment) {
      await _client
          .from('cartera_vencida')
          .update({'monto_vencido': 0})
          .eq('id', overdueEntryId)
          .eq('asesor_id', _advisorId);
      return;
    }

    if (form.result == CollectionResultType.partialPayment &&
        form.amountPaid != null) {
      final remaining = (currentOverdueAmount - form.amountPaid!)
          .clamp(0, double.infinity);
      await _client
          .from('cartera_vencida')
          .update({'monto_vencido': remaining})
          .eq('id', overdueEntryId)
          .eq('asesor_id', _advisorId);
    }
  }

  Map<String, dynamic> _formToMap(CollectionActionFormData form) {
    return {
      'tipo_gestion': form.managementType.code,
      'resultado': form.result.code,
      'monto_pagado': form.amountPaid,
      'fecha_compromiso': form.commitmentDate?.toIso8601String(),
      'monto_compromiso': form.commitmentAmount,
      'observaciones': form.observations,
    };
  }

  CollectionActionFormData _formFromMap(Map<String, dynamic> map) {
    return CollectionActionFormData(
      managementType: CollectionManagementType.fromCode(
        map['tipo_gestion']?.toString(),
      ),
      result: CollectionResultType.fromCode(map['resultado']?.toString()),
      observations: map['observaciones']?.toString() ?? '',
      amountPaid: (map['monto_pagado'] as num?)?.toDouble(),
      commitmentDate: map['fecha_compromiso'] == null
          ? null
          : DateTime.tryParse(map['fecha_compromiso'].toString()),
      commitmentAmount: (map['monto_compromiso'] as num?)?.toDouble(),
    );
  }

  Future<void> _touchOverdueContact(String overdueEntryId) async {
    await _client
        .from('cartera_vencida')
        .update({'fecha_ultimo_contacto': _dateOnly(DateTime.now())})
        .eq('id', overdueEntryId)
        .eq('asesor_id', _advisorId);
  }

  Future<void> _markPortfolioVisited(
    String portfolioEntryId,
    String observation,
  ) async {
    await _client
        .from('cartera_diaria')
        .update({
          'estado_visita': VisitStatus.visited.code,
          'resultado_visita': 'Gestion de cobranza',
          'observacion_visita': observation,
          'timestamp_visita': DateTime.now().toIso8601String(),
        })
        .eq('id', portfolioEntryId)
        .eq('asesor_id', _advisorId);
  }

  List<OverdueClientEntry> _attachPortfolioIds(
    List<OverdueClientEntry> entries,
    List<DailyClient> portfolio,
  ) {
    return entries.map((entry) {
      DailyClient? match;
      for (final client in portfolio) {
        if (client.clientId == entry.clientId) {
          match = client;
          break;
        }
      }
      if (match == null) {
        return entry;
      }
      return OverdueClientEntry(
        id: entry.id,
        clientId: entry.clientId,
        creditId: entry.creditId.isEmpty ? (match.creditId ?? '') : entry.creditId,
        clientName: entry.clientName,
        documentNumber: entry.documentNumber.isEmpty
            ? match.documentNumber
            : entry.documentNumber,
        daysPastDue: entry.daysPastDue > 0 ? entry.daysPastDue : match.daysPastDue,
        overdueAmount:
            entry.overdueAmount > 0 ? entry.overdueAmount : match.creditAmount,
        lastContactDate: entry.lastContactDate,
        portfolioEntryId: match.id,
      );
    }).toList();
  }

  Future<void> _queueAction(Map<String, dynamic> item) async {
    final queue = _loadPendingQueue()..add(item);
    await _preferences.setString(_pendingActionsKey, jsonEncode(queue));
  }

  List<Map<String, dynamic>> _loadPendingQueue() {
    final raw = _preferences.getString(_pendingActionsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _cacheActions(List<CollectionActionRecord> actions) async {
    await _preferences.setString(
      _actionsCacheKey,
      jsonEncode(
        actions
            .map(
              (action) => {
                'id': action.id,
                'cliente_id': action.clientId,
                'clientName': action.clientName,
                'tipo_gestion': action.managementType.code,
                'resultado': action.result.code,
                'monto_pagado': action.amountPaid,
                'fecha_compromiso': action.commitmentDate?.toIso8601String(),
                'monto_compromiso': action.commitmentAmount,
                'observaciones': action.observations,
                'timestamp_gestion': action.registeredAt.toIso8601String(),
              },
            )
            .toList(),
      ),
    );
  }

  List<CollectionActionRecord> _loadCachedActions() {
    final raw = _preferences.getString(_actionsCacheKey);
    if (raw == null) {
      return [];
    }

    return (jsonDecode(raw) as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      return CollectionActionRecord(
        id: json['id'].toString(),
        clientId: json['cliente_id'].toString(),
        clientName: json['clientName'].toString(),
        managementType: CollectionManagementType.fromCode(
          json['tipo_gestion']?.toString(),
        ),
        result: CollectionResultType.fromCode(json['resultado']?.toString()),
        registeredAt: DateTime.parse(json['timestamp_gestion'].toString()),
        amountPaid: (json['monto_pagado'] as num?)?.toDouble(),
        commitmentDate: json['fecha_compromiso'] == null
            ? null
            : DateTime.tryParse(json['fecha_compromiso'].toString()),
        commitmentAmount: (json['monto_compromiso'] as num?)?.toDouble(),
        observations: json['observaciones']?.toString(),
      );
    }).toList();
  }

  Future<Position?> _currentPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    try {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((state) => state != ConnectivityResult.none);
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
