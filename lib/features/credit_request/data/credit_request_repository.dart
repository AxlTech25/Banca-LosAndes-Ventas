import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/database/local_app_database.dart';
import '../models/credit_request_models.dart';
import '../services/document_storage_service.dart';

class CreditRequestRepository {
  CreditRequestRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
    required String agencyId,
    required SharedPreferences preferences,
    Connectivity? connectivity,
  }) : _client = client,
       _advisorId = advisorId,
       _agencyId = agencyId,
       _preferences = preferences,
       _connectivity = connectivity ?? Connectivity();

  final supabase.SupabaseClient _client;
  final String _advisorId;
  final String _agencyId;
  final SharedPreferences _preferences;
  final Connectivity _connectivity;

  String get _draftsKey => 'credit_request_drafts_$_advisorId';
  String get _syncQueueKey => 'credit_request_sync_queue_$_advisorId';

  Future<List<CreditRequestDraft>> loadDrafts() async {
    final sqliteDrafts =
        await LocalAppDatabase.loadDrafts(_advisorId);
    if (sqliteDrafts.isNotEmpty) {
      return sqliteDrafts;
    }

    final raw = _preferences.getString(_draftsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CreditRequestDraft.fromJson)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<CreditRequestDraft?> loadDraft(String localId) async {
    final drafts = await loadDrafts();
    for (final draft in drafts) {
      if (draft.localId == localId) {
        return draft;
      }
    }
    return null;
  }

  Future<void> saveDraft(CreditRequestDraft draft) async {
    await LocalAppDatabase.saveDraft(draft);

    final drafts = await loadDrafts();
    final index = drafts.indexWhere((item) => item.localId == draft.localId);
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.add(draft);
    }

    await _preferences.setString(
      _draftsKey,
      jsonEncode(drafts.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteDraft(String localId) async {
    await LocalAppDatabase.deleteDraft(localId);
    final drafts = await loadDrafts();
    drafts.removeWhere((item) => item.localId == localId);
    await _preferences.setString(
      _draftsKey,
      jsonEncode(drafts.map((item) => item.toJson()).toList()),
    );
  }

  Future<CreditRequestDraft> createDraft(CreditRequestLaunchData launch) async {
    final localId = _client.auth.currentSession?.user.id != null
        ? '${DateTime.now().millisecondsSinceEpoch}'
        : DateTime.now().millisecondsSinceEpoch.toString();
    final draft = launch.toDraft(
      localId: localId,
      advisorId: _advisorId,
      agencyId: _agencyId,
    );
    await saveDraft(draft);
    return draft;
  }

  Future<CreditRequestSubmitResult> submit(CreditRequestDraft draft) async {
    if (!draft.canSubmit) {
      return const CreditRequestSubmitResult(
        errorMessage: 'Completa los pasos obligatorios antes de enviar.',
      );
    }

    final prepared = draft.copyWith(
      numeroExpediente: draft.numeroExpediente ?? _generateExpedienteNumber(),
    );

    if (!await _hasNetwork()) {
      return _queueOfflineSubmission(prepared);
    }

    try {
      return await _submitOnline(prepared);
    } catch (error) {
      return _queueOfflineSubmission(
        prepared.copyWith(pendienteSync: true),
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> syncPendingRequests() async {
    if (!await _hasNetwork()) {
      return;
    }

    final queue = _loadSyncQueue();
    if (queue.isEmpty) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        final draft = CreditRequestDraft.fromJson(item);
        final result = await _submitOnline(draft.copyWith(pendienteSync: false));
        if (result.isSuccess) {
          await deleteDraft(draft.localId);
        } else {
          remaining.add(item);
        }
      } catch (_) {
        remaining.add(item);
      }
    }

    await _preferences.setString(_syncQueueKey, jsonEncode(remaining));
  }

  Future<int> countLocalPendingSync() async {
    final queue = _loadSyncQueue();
    return queue.length;
  }

  Future<CreditRequestSubmitResult> _submitOnline(
    CreditRequestDraft draft,
  ) async {
    final clientId = await _ensureClient(draft);
    final payload = draft
        .copyWith(clientId: clientId, pendienteSync: false)
        .toSupabasePayload(clientId: clientId);

    final row = await _client
        .from('solicitudes_credito')
        .insert(payload)
        .select('id')
        .single();

    final solicitudId = row['id'].toString();
    await _persistDocuments(solicitudId, draft.documents);
    await deleteDraft(draft.localId);
    await _removeFromSyncQueue(draft.localId);

    return CreditRequestSubmitResult(solicitudId: solicitudId);
  }

  Future<CreditRequestSubmitResult> _queueOfflineSubmission(
    CreditRequestDraft draft, {
    String? errorMessage,
  }) async {
    final queued = draft.copyWith(
      status: CreditRequestStatus.pendingSync,
      pendienteSync: true,
    );
    await saveDraft(queued);

    final queue = _loadSyncQueue();
    queue.removeWhere((item) => item['localId'] == draft.localId);
    queue.add(queued.toJson());
    await _preferences.setString(_syncQueueKey, jsonEncode(queue));

    return CreditRequestSubmitResult(
      offline: true,
      errorMessage: errorMessage,
    );
  }

  Future<String> _ensureClient(CreditRequestDraft draft) async {
    if (draft.clientId != null && draft.clientId!.isNotEmpty) {
      return draft.clientId!;
    }

    final existing = await _client
        .from('clientes')
        .select('id')
        .eq('numero_documento', draft.documentNumber)
        .maybeSingle();

    if (existing != null) {
      return existing['id'].toString();
    }

    final inserted = await _client
        .from('clientes')
        .insert({
          'numero_documento': draft.documentNumber,
          'nombres': draft.clientFirstName,
          'apellidos': draft.clientLastName,
          'tipo_negocio': draft.businessType,
          'nombre_negocio': draft.businessName,
          'antiguedad_negocio_meses': draft.businessAgeMonths,
        })
        .select('id')
        .single();

    return inserted['id'].toString();
  }

  Future<void> _persistDocuments(
    String solicitudId,
    List<CreditDocumentAttachment> documents,
  ) async {
    final storage = DocumentStorageService(client: _client);
    for (final document in documents) {
      final file = File(document.localPath);
      if (!file.existsSync()) {
        continue;
      }

      final bytes = await file.readAsBytes();
      final storageUrl = await storage.uploadDocument(
        solicitudId: solicitudId,
        typeCode: document.type.code,
        localPath: document.localPath,
      );
      final encoded = base64Encode(bytes);
      await _client.from('solicitudes_documentos').insert({
        'solicitud_id': solicitudId,
        'tipo_documento': document.type.code,
        'storage_url': storageUrl ??
            'data:image/jpeg;base64,$encoded',
        'tamanio_kb': document.sizeKb > 0
            ? document.sizeKb
            : (bytes.length / 1024).ceil(),
        if (document.sharpnessScore > 0)
          'nitidez_score': document.sharpnessScore,
      });
    }
  }

  List<Map<String, dynamic>> _loadSyncQueue() {
    final raw = _preferences.getString(_syncQueueKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _removeFromSyncQueue(String localId) async {
    final queue = _loadSyncQueue()
      ..removeWhere((item) => item['localId'] == localId);
    await _preferences.setString(_syncQueueKey, jsonEncode(queue));
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((state) => state != ConnectivityResult.none);
  }

  String _generateExpedienteNumber() {
    final suffix = DateTime.now().millisecondsSinceEpoch % 100000000;
    return 'SOL-$suffix';
  }
}
