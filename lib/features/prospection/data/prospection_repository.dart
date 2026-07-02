import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/pre_evaluation_models.dart';
import '../services/pre_evaluation_scoring.dart';

class ProspectionRepository {
  ProspectionRepository({
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

  String get _pendingKey => 'pre_evaluaciones_pendientes_$_advisorId';
  String get _deserterKey => 'deserciones_pendientes_$_advisorId';

  Future<PreEvaluationResult> evaluateProspect(ProspectFormData form) async {
    if (!await _hasNetwork()) {
      await _queueEvaluation(form);
      return PreEvaluationResult(
        status: PreEvaluationStatus.pending,
        reason: 'Sin conexion. La pre-evaluacion se procesara al reconectar.',
        pendingSync: true,
      );
    }

    return evaluateProspectOnline(form);
  }

  Future<PreEvaluationResult> evaluateProspectOnline(
    ProspectFormData form,
  ) async {
    return PreEvaluationScoring.evaluateFromProspect(form);
  }

  Future<void> syncPendingEvaluations() async {
    if (!await _hasNetwork()) {
      return;
    }

    final raw = _preferences.getString(_pendingKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final rows = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    final remaining = <Map<String, dynamic>>[];

    for (final row in rows) {
      try {
        await evaluateProspectOnline(_formFromQueue(row));
      } catch (_) {
        remaining.add(row);
      }
    }

    await _preferences.setString(_pendingKey, jsonEncode(remaining));
  }

  Future<void> saveDeserterRecord({
    required String clientId,
    required String portfolioEntryId,
    required DeserterFormData data,
  }) async {
    final payload = {
      'client_id': clientId,
      'cartera_id': portfolioEntryId,
      'advisor_id': _advisorId,
      'data': data.toJson(),
      'created_at': DateTime.now().toIso8601String(),
    };

    if (await _hasNetwork() && portfolioEntryId.isNotEmpty) {
      await _client.from('cartera_diaria').update({
        'resultado_visita': 'Desertor registrado',
        'observacion_visita':
            '${data.reason} · ${data.returnProbability} · ${data.observations}',
        'estado_visita': 'visitado',
        'timestamp_visita': DateTime.now().toIso8601String(),
      }).eq('id', portfolioEntryId);
      return;
    }

    final queue = _loadDeserterQueue();
    queue.add(payload);
    await _preferences.setString(_deserterKey, jsonEncode(queue));
  }

  Future<void> _queueEvaluation(ProspectFormData form) async {
    final queue = _loadEvaluationQueue();
    queue.add({
      ...form.toJson(),
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _preferences.setString(_pendingKey, jsonEncode(queue));
  }

  List<Map<String, dynamic>> _loadEvaluationQueue() {
    final raw = _preferences.getString(_pendingKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _loadDeserterQueue() {
    final raw = _preferences.getString(_deserterKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  ProspectFormData _formFromQueue(Map<String, dynamic> json) {
    return ProspectFormData(
      documentNumber: json['documento'].toString(),
      firstName: json['nombres'].toString(),
      lastName: json['apellidos'].toString(),
      birthDate: DateTime.parse(json['fecha_nacimiento'].toString()),
      businessType: json['tipo_negocio'].toString(),
      businessAgeYears: int.parse(json['antiguedad_anos'].toString()),
      businessAgeMonths: int.parse(json['antiguedad_meses'].toString()),
      estimatedIncome: double.parse(json['ingresos_estimados'].toString()),
      monthlyExpenses: double.tryParse(
            json['gastos_mensuales']?.toString() ?? '',
          ) ??
          0,
      requestedAmount: double.parse(json['monto_solicitado'].toString()),
      termMonths: int.tryParse(json['plazo_meses']?.toString() ?? '') ?? 18,
      creditPurpose: json['destino_credito'].toString(),
    );
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((state) => state != ConnectivityResult.none);
  }
}
