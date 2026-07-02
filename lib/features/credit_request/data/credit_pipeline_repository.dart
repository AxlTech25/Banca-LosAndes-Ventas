import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../shared/widgets/risk_semaphore.dart';
import '../models/pipeline_models.dart';

class ChatNoDisponibleException implements Exception {
  const ChatNoDisponibleException();

  @override
  String toString() =>
      'El chat no esta disponible. Ejecuta en Supabase la migracion '
      '008_fase4_pagos_firma_chat_buro.sql (seccion de chat).';
}

bool _esTablaChatFaltante(supabase.PostgrestException error) {
  final msg = error.message.toLowerCase();
  return msg.contains('mensajes_solicitud') &&
      (msg.contains('could not find') ||
          msg.contains('does not exist') ||
          msg.contains('schema cache'));
}

class CreditPipelineRepository {
  CreditPipelineRepository({
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

  String get _bureauQueueKey => 'consultas_buro_pendientes_$_advisorId';
  String get _transmitQueueKey => 'transmisiones_pendientes_$_advisorId';
  String get _trackingCacheKey => 'solicitudes_seguimiento_$_advisorId';

  bool lastFetchWasCached = false;

  /// Ver [DashboardRepository] — FK explicita tras migracion 014.
  static const solicitudCarteraDiariaEmbed =
      'cartera_diaria!solicitudes_credito_cartera_diaria_id_fkey';

  static const _submittedSelect = '''
    id,
    numero_expediente,
    cliente_id,
    monto_solicitado,
    monto_aprobado,
    plazo_meses,
    estado,
    origen,
    pendiente_sync,
    motivo_rechazo,
    condicion_adicional,
    analista_asignado,
    created_at,
    updated_at,
    clientes (
      nombres,
      apellidos,
      numero_documento
    ),
    consultas_buro ( id )
  ''';

  static const _detailSelect = '''
    id,
    numero_expediente,
    cliente_id,
    monto_solicitado,
    monto_aprobado,
    plazo_meses,
    estado,
    origen,
    pendiente_sync,
    motivo_rechazo,
    condicion_adicional,
    analista_asignado,
    created_at,
    updated_at,
    cartera_diaria_id,
    clientes (
      nombres,
      apellidos,
      numero_documento
    ),
    consultas_buro ( id ),
    $solicitudCarteraDiariaEmbed (
      estado_visita
    ),
    pre_evaluaciones_solicitud (
      calificacion,
      puntaje,
      motivo,
      created_at
    )
  ''';

  static const _committeeSelect = '''
    id,
    numero_expediente,
    cliente_id,
    monto_solicitado,
    monto_aprobado,
    plazo_meses,
    estado,
    origen,
    pendiente_sync,
    motivo_rechazo,
    condicion_adicional,
    analista_asignado,
    created_at,
    updated_at,
    clientes (
      nombres,
      apellidos,
      numero_documento
    ),
    consultas_buro ( id ),
    asesores_negocio (
      nombres,
      apellidos,
      codigo_empleado
    )
  ''';

  static const _approvalQueueSelect = '''
    id,
    numero_expediente,
    cliente_id,
    monto_solicitado,
    monto_aprobado,
    plazo_meses,
    estado,
    origen,
    pendiente_sync,
    motivo_rechazo,
    condicion_adicional,
    analista_asignado,
    created_at,
    updated_at,
    clientes (
      nombres,
      apellidos,
      numero_documento
    ),
    consultas_buro ( id ),
    asesores_negocio (
      nombres,
      apellidos,
      codigo_empleado
    ),
    $solicitudCarteraDiariaEmbed (
      estado_visita
    ),
    pre_evaluaciones_solicitud (
      calificacion,
      puntaje,
      motivo,
      created_at
    )
  ''';

  Future<List<PendingApprovalItem>> fetchAgencyApprovalQueue({
    required String agencyId,
  }) async {
    final rows = await _client
        .from('solicitudes_credito')
        .select(_approvalQueueSelect)
        .eq('origen', 'app_cliente')
        .eq('agencia_id', agencyId)
        .eq('estado', 'en_evaluacion')
        .order('updated_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_pendingApprovalFromRow)
        .toList();
  }

  PendingApprovalItem _pendingApprovalFromRow(Map<String, dynamic> row) {
    final preEval = _preEvaluationFromRow(row);
    final consultas = row['consultas_buro'];
    final hasBureau = consultas is List && consultas.isNotEmpty;

    return PendingApprovalItem(
      request: SubmittedCreditRequest.fromJson(row),
      visitCompleted: _visitCompletedFromRow(row),
      preEvalApto: preEval?.isApto ?? false,
      hasBureau: hasBureau,
      preEvalScore: preEval?.puntaje,
    );
  }

  Future<List<SubmittedCreditRequest>> fetchCommitteeQueue({
    required bool agencyWide,
  }) async {
    var query = _client
        .from('solicitudes_credito')
        .select(_committeeSelect)
        .inFilter('estado', ['enviada', 'transmitida', 'en_analisis']);

    if (!agencyWide) {
      query = query.eq('asesor_id', _advisorId);
    }

    final rows = await query.order('updated_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SubmittedCreditRequest.fromJson)
        .toList();
  }

  Future<List<SubmittedCreditRequest>> fetchPendingClientAppRequests() async {
    final rows = await _client
        .from('solicitudes_credito')
        .select(_submittedSelect)
        .eq('origen', 'app_cliente')
        .isFilter('asesor_id', null)
        .inFilter('estado', ['pendiente', 'borrador'])
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SubmittedCreditRequest.fromJson)
        .toList();
  }

  Future<String> assignClientAppRequest({
    required String solicitudId,
    required String agencyId,
  }) async {
    try {
      final result = await _client.rpc(
        'asignar_solicitud_app_cliente',
        params: {'p_solicitud_id': solicitudId},
      );
      return result.toString();
    } on supabase.PostgrestException catch (error) {
      if (error.message.contains('asignar_solicitud_app_cliente') ||
          error.code == 'PGRST202') {
        return _assignClientAppRequestFallback(
          solicitudId: solicitudId,
          agencyId: agencyId,
        );
      }
      rethrow;
    }
  }

  Future<String> _assignClientAppRequestFallback({
    required String solicitudId,
    required String agencyId,
  }) async {
    final solicitud = await _client
        .from('solicitudes_credito')
        .select('id, cliente_id, origen, asesor_id, estado')
        .eq('id', solicitudId)
        .maybeSingle();

    if (solicitud == null) {
      throw StateError('Solicitud no encontrada.');
    }
    if (solicitud['origen']?.toString() != 'app_cliente') {
      throw StateError('Solo solicitudes de app cliente pueden asignarse.');
    }

    await _client
        .from('solicitudes_credito')
        .update({
          'asesor_id': _advisorId,
          'agencia_id': agencyId,
          'estado': 'en_evaluacion',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', solicitudId)
        .eq('origen', 'app_cliente');

    final assignmentDate = await _businessToday();
    final clienteId = solicitud['cliente_id'].toString();

    final existing = await _client
        .from('cartera_diaria')
        .select('id')
        .eq('asesor_id', _advisorId)
        .eq('cliente_id', clienteId)
        .eq('fecha_asignacion', assignmentDate)
        .maybeSingle();

    String carteraId;
    if (existing != null) {
      carteraId = existing['id'].toString();
      await _client.from('cartera_diaria').update({
        'tipo_gestion': 'NUEVA_SOLICITUD',
        'prioridad': 'normal',
        'score_prioridad': 38,
        'solicitud_id': solicitudId,
        'estado_visita': 'pendiente',
      }).eq('id', carteraId);
    } else {
      final inserted = await _client
          .from('cartera_diaria')
          .insert({
            'asesor_id': _advisorId,
            'cliente_id': clienteId,
            'agencia_id': agencyId,
            'fecha_asignacion': assignmentDate,
            'tipo_gestion': 'NUEVA_SOLICITUD',
            'prioridad': 'normal',
            'score_prioridad': 38,
            'estado_visita': 'pendiente',
            'solicitud_id': solicitudId,
          })
          .select('id')
          .single();
      carteraId = inserted['id'].toString();
    }

    await _client
        .from('solicitudes_credito')
        .update({'cartera_diaria_id': carteraId})
        .eq('id', solicitudId);

    return carteraId;
  }

  Future<String> _businessToday() async {
    try {
      final result = await _client.rpc('business_today');
      return _normalizeAssignmentDate(result);
    } catch (_) {
      return _dateOnly(DateTime.now());
    }
  }

  String _normalizeAssignmentDate(Object? value) {
    if (value is DateTime) {
      return _dateOnly(value);
    }
    final raw = value?.toString() ?? '';
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    return _dateOnly(DateTime.now());
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<SolicitudPreEvaluation> runPreEvaluationForRequest(
    String solicitudId,
  ) async {
    final response = await _client.rpc(
      'pre_evaluar_solicitud_app_cliente',
      params: {'p_solicitud_id': solicitudId},
    );

    if (response is Map<String, dynamic>) {
      return SolicitudPreEvaluation(
        calificacion: (response['calificacion'] ?? '').toString(),
        motivo: (response['motivo'] ?? '').toString(),
        puntaje: (response['puntaje_estimado'] as num?)?.toInt(),
        evaluatedAt: DateTime.now(),
      );
    }

    throw StateError('Respuesta de pre-evaluacion invalida.');
  }

  Future<void> registerClientAppVisit({
    required String solicitudId,
    double? latitude,
    double? longitude,
    String? observation,
  }) async {
    await _client.rpc(
      'registrar_visita_solicitud_app_cliente',
      params: {
        'p_solicitud_id': solicitudId,
        'p_lat': latitude,
        'p_lng': longitude,
        'p_observacion': observation,
      },
    );
  }

  Future<void> updateClientAppRequestStatus({
    required String solicitudId,
    required String nuevoEstado,
    String? motivoRechazo,
    double? montoAprobado,
    String? condicionAdicional,
  }) async {
    await _client.rpc(
      'actualizar_estado_solicitud_app_cliente',
      params: {
        'p_solicitud_id': solicitudId,
        'p_nuevo_estado': nuevoEstado,
        'p_motivo_rechazo': motivoRechazo,
        'p_monto_aprobado': montoAprobado,
        'p_condicion_adicional': condicionAdicional,
      },
    );
  }

  Future<List<SubmittedCreditRequest>> fetchSubmittedRequests() async {
    lastFetchWasCached = false;
    try {
      final rows = await _client
          .from('solicitudes_credito')
          .select(_submittedSelect)
          .eq('asesor_id', _advisorId)
          .neq('estado', 'borrador')
          .order('updated_at', ascending: false);

      final requests = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(SubmittedCreditRequest.fromJson)
          .toList();
      await _cacheTrackedRequests(requests);
      return requests;
    } catch (_) {
      lastFetchWasCached = true;
      return _loadCachedTrackedRequests();
    }
  }

  Future<List<SubmittedCreditRequest>> fetchTrackedRequests() async {
    final all = await fetchSubmittedRequests();
    return all
        .where((request) => request.status.isTrackable)
        .toList();
  }

  Future<CreditRequestDetail?> fetchRequestDetail(String solicitudId) async {
    final row = await _client
        .from('solicitudes_credito')
        .select(_detailSelect)
        .eq('id', solicitudId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final request = SubmittedCreditRequest.fromJson(row);
    final documents = await fetchDocuments(solicitudId);
    final bureauConsult = await fetchLatestBureauConsult(solicitudId);
    final notes = await fetchInternalNotes(solicitudId);
    final visitCompleted = _visitCompletedFromRow(row);
    final preEvaluation = _preEvaluationFromRow(row);

    return CreditRequestDetail(
      request: request,
      documents: documents,
      internalNotes: notes,
      bureauConsult: bureauConsult,
      visitCompleted: visitCompleted,
      preEvaluation: preEvaluation,
    );
  }

  bool _visitCompletedFromRow(Map<String, dynamic> row) {
    final cartera = row['cartera_diaria'];
    if (cartera is Map) {
      return (cartera['estado_visita'] ?? '').toString() == 'visitado';
    }
    if (cartera is List && cartera.isNotEmpty) {
      final first = cartera.first;
      if (first is Map) {
        return (first['estado_visita'] ?? '').toString() == 'visitado';
      }
    }
    return false;
  }

  SolicitudPreEvaluation? _preEvaluationFromRow(Map<String, dynamic> row) {
    final preEval = row['pre_evaluaciones_solicitud'];
    Map<String, dynamic>? data;
    if (preEval is Map) {
      data = preEval.cast<String, dynamic>();
    } else if (preEval is List && preEval.isNotEmpty) {
      final first = preEval.first;
      if (first is Map) {
        data = first.cast<String, dynamic>();
      }
    }
    if (data == null) {
      return null;
    }
    return SolicitudPreEvaluation.fromJson(data);
  }

  Future<List<SolicitudInternalNote>> fetchInternalNotes(
    String solicitudId,
  ) async {
    final rows = await _client
        .from('solicitudes_notas_internas')
        .select('id, contenido, created_at')
        .eq('solicitud_id', solicitudId)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SolicitudInternalNote.fromJson)
        .toList();
  }

  Future<SolicitudInternalNote> addInternalNote({
    required String solicitudId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw StateError('La nota no puede estar vacia.');
    }
    if (trimmed.length > 500) {
      throw StateError('La nota admite maximo 500 caracteres.');
    }

    final row = await _client
        .from('solicitudes_notas_internas')
        .insert({
          'solicitud_id': solicitudId,
          'asesor_id': _advisorId,
          'contenido': trimmed,
        })
        .select('id, contenido, created_at')
        .single();

    return SolicitudInternalNote.fromJson(row);
  }

  supabase.RealtimeChannel subscribeToStatusChanges(void Function() onChange) {
    final channel = _client.channel('solicitudes_status_$_advisorId');
    channel
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.update,
          schema: 'public',
          table: 'solicitudes_credito',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'asesor_id',
            value: _advisorId,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'solicitudes_notas_internas',
          callback: (_) => onChange(),
        );
    channel.subscribe();
    return channel;
  }

  Future<List<SolicitudMensaje>> fetchMensajesSolicitud(String solicitudId) async {
    try {
      final rows = await _client
          .from('mensajes_solicitud')
          .select('id, solicitud_id, autor_tipo, contenido, created_at')
          .eq('solicitud_id', solicitudId)
          .order('created_at', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(SolicitudMensaje.fromJson)
          .toList();
    } on supabase.PostgrestException catch (error) {
      if (_esTablaChatFaltante(error)) {
        throw const ChatNoDisponibleException();
      }
      rethrow;
    }
  }

  Future<SolicitudMensaje> enviarMensajeAsesor({
    required String solicitudId,
    required String clienteId,
    required String contenido,
  }) async {
    final trimmed = contenido.trim();
    if (trimmed.isEmpty) {
      throw StateError('El mensaje no puede estar vacio.');
    }

    try {
      final row = await _client
          .from('mensajes_solicitud')
          .insert({
            'solicitud_id': solicitudId,
            'cliente_id': clienteId,
            'asesor_id': _advisorId,
            'autor_tipo': 'asesor',
            'contenido': trimmed,
            'leido_asesor': true,
            'leido_cliente': false,
          })
          .select('id, solicitud_id, autor_tipo, contenido, created_at')
          .single();
      return SolicitudMensaje.fromJson(row);
    } on supabase.PostgrestException catch (error) {
      if (_esTablaChatFaltante(error)) {
        throw const ChatNoDisponibleException();
      }
      throw StateError(error.message);
    }
  }

  Future<void> marcarMensajesLeidosAsesor(String solicitudId) async {
    try {
      await _client
          .from('mensajes_solicitud')
          .update({'leido_asesor': true})
          .eq('solicitud_id', solicitudId)
          .eq('autor_tipo', 'cliente')
          .eq('leido_asesor', false);
    } on supabase.PostgrestException catch (error) {
      if (_esTablaChatFaltante(error)) {
        return;
      }
    }
  }

  supabase.RealtimeChannel subscribeMensajesSolicitud({
    required String solicitudId,
    required void Function() onChange,
  }) {
    return _client
        .channel('mensajes_asesor_$solicitudId')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'mensajes_solicitud',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'solicitud_id',
            value: solicitudId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> _cacheTrackedRequests(
    List<SubmittedCreditRequest> requests,
  ) async {
    await _preferences.setString(
      _trackingCacheKey,
      jsonEncode(
        requests
            .map(
              (request) => {
                'id': request.id,
                'numero_expediente': request.expedienteNumber,
                'cliente_id': request.clientId,
                'clientName': request.clientName,
                'documentNumber': request.documentNumber,
                'monto_solicitado': request.requestedAmount,
                'monto_aprobado': request.approvedAmount,
                'plazo_meses': request.termMonths,
                'estado': request.status.code,
                'pendiente_sync': request.pendingSync,
                'motivo_rechazo': request.rejectionReason,
                'condicion_adicional': request.additionalCondition,
                'analista_asignado': request.assignedAnalyst,
                'created_at': request.createdAt.toIso8601String(),
                'updated_at': request.updatedAt?.toIso8601String(),
                'hasBureauConsult': request.hasBureauConsult,
              },
            )
            .toList(),
      ),
    );
  }

  List<SubmittedCreditRequest> _loadCachedTrackedRequests() {
    final raw = _preferences.getString(_trackingCacheKey);
    if (raw == null) {
      return [];
    }

    return (jsonDecode(raw) as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      return SubmittedCreditRequest(
        id: json['id'].toString(),
        expedienteNumber: json['numero_expediente'].toString(),
        clientId: json['cliente_id'].toString(),
        clientName: json['clientName'].toString(),
        documentNumber: json['documentNumber'].toString(),
        requestedAmount: (json['monto_solicitado'] as num).toDouble(),
        termMonths: (json['plazo_meses'] as num).toInt(),
        status: SolicitudPipelineStatus.fromCode(json['estado']?.toString()),
        createdAt: DateTime.parse(json['created_at'].toString()),
        pendingSync: json['pendiente_sync'] == true,
        hasBureauConsult: json['hasBureauConsult'] == true,
        approvedAmount: (json['monto_aprobado'] as num?)?.toDouble(),
        rejectionReason: json['motivo_rechazo']?.toString(),
        additionalCondition: json['condicion_adicional']?.toString(),
        assignedAnalyst: json['analista_asignado']?.toString(),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'].toString()),
      );
    }).toList();
  }

  Future<List<StoredCreditDocument>> fetchDocuments(String solicitudId) async {
    final rows = await _client
        .from('solicitudes_documentos')
        .select('''
          id,
          solicitud_id,
          tipo_documento,
          storage_url,
          tamanio_kb,
          nitidez_score,
          created_at,
          solicitudes_credito (
            numero_expediente,
            clientes ( nombres, apellidos )
          )
        ''')
        .eq('solicitud_id', solicitudId)
        .order('created_at');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(StoredCreditDocument.fromJson)
        .toList();
  }

  Future<List<StoredCreditDocument>> fetchRecentDocuments({
    int limit = 30,
  }) async {
    final solicitudes = await fetchSubmittedRequests();
    if (solicitudes.isEmpty) {
      return [];
    }

    final ids = solicitudes.map((request) => request.id).toList();
    final rows = await _client
        .from('solicitudes_documentos')
        .select('''
          id,
          solicitud_id,
          tipo_documento,
          storage_url,
          tamanio_kb,
          nitidez_score,
          created_at,
          solicitudes_credito (
            numero_expediente,
            clientes ( nombres, apellidos )
          )
        ''')
        .inFilter('solicitud_id', ids)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(StoredCreditDocument.fromJson)
        .toList();
  }

  Future<BureauConsultResult?> fetchLatestBureauConsult(
    String solicitudId,
  ) async {
    final row = await _client
        .from('consultas_buro')
        .select()
        .eq('solicitud_id', solicitudId)
        .eq('asesor_id', _advisorId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return BureauConsultResult.fromJson(row);
  }

  Future<BureauConsultResult> runBureauConsult({
    required String solicitudId,
    required String clientId,
    required String documentNumber,
    required String consentSignatureBase64,
  }) async {
    final reused = await _findRecentBureauConsult(documentNumber);
    if (reused != null) {
      return reused;
    }

    if (!await _hasNetwork()) {
      final result = await _localBureauConsult(
        solicitudId: solicitudId,
        clientId: clientId,
        documentNumber: documentNumber,
        consentSignatureBase64: consentSignatureBase64,
        persist: false,
      );
      await _queueBureauConsult({
        'solicitud_id': solicitudId,
        'cliente_id': clientId,
        'dni_consultado': documentNumber,
        'firma_consentimiento_base64': consentSignatureBase64,
        'resultado': result.toJsonPayload(),
      });
      return BureauConsultResult(
        id: '',
        solicitudId: solicitudId,
        documentNumber: documentNumber,
        rating: result.rating,
        debtEntities: result.debtEntities,
        totalDebtPen: result.totalDebtPen,
        largestDebt: result.largestDebt,
        maxOverdueDays: result.maxOverdueDays,
        consultedAt: DateTime.now(),
        pendingSync: true,
      );
    }

    try {
      final response = await _client.functions.invoke(
        'consultar-buro',
        body: {
          'solicitud_id': solicitudId,
          'cliente_id': clientId,
          'dni': documentNumber,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return _persistBureauConsult(
          solicitudId: solicitudId,
          clientId: clientId,
          documentNumber: documentNumber,
          consentSignatureBase64: consentSignatureBase64,
          payload: data,
        );
      }
    } catch (_) {
      // Edge Function mock no disponible.
    }

    return _localBureauConsult(
      solicitudId: solicitudId,
      clientId: clientId,
      documentNumber: documentNumber,
      consentSignatureBase64: consentSignatureBase64,
      persist: true,
    );
  }

  Future<TransmissionResult> transmitRequest(String solicitudId) async {
    if (!await _hasNetwork()) {
      await _queueTransmission(solicitudId);
      return const TransmissionResult(offline: true);
    }

    try {
      await _client
          .from('solicitudes_credito')
          .update({
            'estado': SolicitudPipelineStatus.transmitida.code,
            'pendiente_sync': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', solicitudId)
          .eq('asesor_id', _advisorId);

      await _client.from('solicitudes_notas_internas').insert({
        'solicitud_id': solicitudId,
        'asesor_id': _advisorId,
        'contenido': 'Solicitud transmitida al back office desde campo.',
      });

      return const TransmissionResult();
    } catch (error) {
      return TransmissionResult(errorMessage: error.toString());
    }
  }

  Future<void> syncPendingPipeline() async {
    if (!await _hasNetwork()) {
      return;
    }

    await _syncPendingBureauConsults();
    await _syncPendingTransmissions();
  }

  Future<void> _syncPendingBureauConsults() async {
    final queue = _loadQueue(_bureauQueueKey);
    if (queue.isEmpty) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        final payload = item['resultado'] as Map<String, dynamic>;
        await _client.from('consultas_buro').insert({
          'asesor_id': _advisorId,
          'cliente_id': item['cliente_id'],
          'solicitud_id': item['solicitud_id'],
          'dni_consultado': item['dni_consultado'],
          'calificacion_sbs': payload['calificacion_sbs'],
          'entidades_con_deuda': payload['entidades_con_deuda'],
          'deuda_total_pen': payload['deuda_total_pen'],
          'mayor_deuda': payload['mayor_deuda'],
          'dias_mayor_mora': payload['dias_mayor_mora'],
          'resultado_json': payload,
          'firma_consentimiento_base64': item['firma_consentimiento_base64'],
        });
      } catch (_) {
        remaining.add(item);
      }
    }

    await _preferences.setString(_bureauQueueKey, jsonEncode(remaining));
  }

  Future<void> _syncPendingTransmissions() async {
    final queue = _loadStringQueue(_transmitQueueKey);
    if (queue.isEmpty) {
      return;
    }

    final remaining = <String>[];
    for (final solicitudId in queue) {
      final result = await transmitRequest(solicitudId);
      if (!result.success || result.offline) {
        remaining.add(solicitudId);
      }
    }

    await _preferences.setString(_transmitQueueKey, jsonEncode(remaining));
  }

  Future<BureauConsultResult> _localBureauConsult({
    required String solicitudId,
    required String clientId,
    required String documentNumber,
    required String consentSignatureBase64,
    required bool persist,
  }) async {
    final profile = await _bureauProfileFromClient(
      documentNumber: documentNumber,
      clientId: clientId,
    );
    final payload = {
      'calificacion_sbs': profile.rating.label,
      'entidades_con_deuda': profile.debtEntities,
      'deuda_total_pen': profile.totalDebtPen,
      'mayor_deuda': profile.largestDebt,
      'dias_mayor_mora': profile.maxOverdueDays,
      'origen': profile.source,
    };

    if (persist) {
      return _persistBureauConsult(
        solicitudId: solicitudId,
        clientId: clientId,
        documentNumber: documentNumber,
        consentSignatureBase64: consentSignatureBase64,
        payload: payload,
      );
    }

    return BureauConsultResult(
      id: '',
      solicitudId: solicitudId,
      documentNumber: documentNumber,
      rating: profile.rating,
      debtEntities: profile.debtEntities,
      totalDebtPen: profile.totalDebtPen,
      largestDebt: profile.largestDebt,
      maxOverdueDays: profile.maxOverdueDays,
      consultedAt: DateTime.now(),
    );
  }

  Future<BureauConsultResult> _persistBureauConsult({
    required String solicitudId,
    required String clientId,
    required String documentNumber,
    required String consentSignatureBase64,
    required Map<String, dynamic> payload,
  }) async {
    final row = await _client
        .from('consultas_buro')
        .insert({
          'asesor_id': _advisorId,
          'cliente_id': clientId,
          'solicitud_id': solicitudId,
          'dni_consultado': documentNumber,
          'calificacion_sbs': payload['calificacion_sbs'],
          'entidades_con_deuda': payload['entidades_con_deuda'],
          'deuda_total_pen': payload['deuda_total_pen'],
          'mayor_deuda': payload['mayor_deuda'],
          'dias_mayor_mora': payload['dias_mayor_mora'],
          'resultado_json': payload,
          'firma_consentimiento_base64': consentSignatureBase64,
        })
        .select()
        .single();

    return BureauConsultResult.fromJson(row);
  }

  Future<_BureauProfile> _bureauProfileFromClient({
    required String documentNumber,
    required String clientId,
  }) async {
    try {
      final response = await _client.rpc(
        'consultar_buro_por_cliente',
        params: {
          'p_dni': documentNumber,
          'p_cliente_id': clientId,
        },
      );
      if (response is Map<String, dynamic>) {
        return _BureauProfile(
          rating: SbsRating.fromCode(response['calificacion_sbs']?.toString()),
          debtEntities: (response['entidades_con_deuda'] as num?)?.toInt() ?? 0,
          totalDebtPen: (response['deuda_total_pen'] as num?)?.toDouble() ?? 0,
          largestDebt: (response['mayor_deuda'] as num?)?.toDouble() ?? 0,
          maxOverdueDays: (response['dias_mayor_mora'] as num?)?.toInt() ?? 0,
          source: response['origen']?.toString() ?? 'perfil_cliente',
        );
      }
    } catch (_) {
      // RPC no disponible: perfil limpio por defecto.
    }

    return const _BureauProfile(
      rating: SbsRating.normal,
      debtEntities: 0,
      totalDebtPen: 0,
      largestDebt: 0,
      maxOverdueDays: 0,
      source: 'sin_registro',
    );
  }

  Future<void> _queueBureauConsult(Map<String, dynamic> payload) async {
    final queue = _loadQueue(_bureauQueueKey)..add(payload);
    await _preferences.setString(_bureauQueueKey, jsonEncode(queue));
  }

  Future<void> _queueTransmission(String solicitudId) async {
    final queue = _loadStringQueue(_transmitQueueKey);
    if (!queue.contains(solicitudId)) {
      queue.add(solicitudId);
    }
    await _preferences.setString(_transmitQueueKey, jsonEncode(queue));
  }

  List<Map<String, dynamic>> _loadQueue(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  List<String> _loadStringQueue(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
  }

  Future<BureauConsultResult?> _findRecentBureauConsult(
    String documentNumber,
  ) async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final row = await _client
        .from('consultas_buro')
        .select()
        .eq('dni_consultado', documentNumber)
        .eq('asesor_id', _advisorId)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final payload = row['resultado_json'];
    if (payload is Map<String, dynamic>) {
      final origen = payload['origen']?.toString();
      if (origen == 'ultimo_digito' ||
          origen == 'mock_dni' ||
          origen == 'demo_caso' ||
          origen == 'creditos_internos' ||
          origen == 'perfil_buro_cliente') {
        return null;
      }
    }

    return BureauConsultResult.fromJson(row);
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((state) => state != ConnectivityResult.none);
  }
}

class _BureauProfile {
  const _BureauProfile({
    required this.rating,
    required this.debtEntities,
    required this.totalDebtPen,
    required this.largestDebt,
    required this.maxOverdueDays,
    required this.source,
  });

  final SbsRating rating;
  final int debtEntities;
  final double totalDebtPen;
  final double largestDebt;
  final int maxOverdueDays;
  final String source;
}

extension on BureauConsultResult {
  Map<String, dynamic> toJsonPayload() {
    return {
      'calificacion_sbs': rating.label,
      'entidades_con_deuda': debtEntities,
      'deuda_total_pen': totalDebtPen,
      'mayor_deuda': largestDebt,
      'dias_mayor_mora': maxOverdueDays,
    };
  }
}
