import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/events/portfolio_refresh_signal.dart';
import '../data/credit_pipeline_repository.dart';
import '../models/pipeline_models.dart';
import '../services/transmission_checklist.dart';
import '../services/transmission_progress_service.dart';

class ClientAppInboxViewModel extends ChangeNotifier {
  ClientAppInboxViewModel({
    required CreditPipelineRepository repository,
    required String agencyId,
  }) : _repository = repository,
       _agencyId = agencyId;

  final CreditPipelineRepository _repository;
  final String _agencyId;

  final List<SubmittedCreditRequest> _requests = [];
  bool isLoading = false;
  bool isAssigning = false;
  String? errorMessage;
  String? assigningId;

  List<SubmittedCreditRequest> get requests => List.unmodifiable(_requests);

  int get assignableCount =>
      _requests.where((r) => r.status == SolicitudPipelineStatus.pendiente).length;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchPendingClientAppRequests();
      _requests
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> takeCase(String solicitudId) async {
    assigningId = solicitudId;
    isAssigning = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.assignClientAppRequest(
        solicitudId: solicitudId,
        agencyId: _agencyId,
      );
      _requests.removeWhere((request) => request.id == solicitudId);
      PortfolioRefreshSignal.instance.notifyChanged();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isAssigning = false;
      assigningId = null;
      notifyListeners();
    }
  }
}

class SuperOperadorApprovalInboxViewModel extends ChangeNotifier {
  SuperOperadorApprovalInboxViewModel({
    required CreditPipelineRepository repository,
    required String agencyId,
  }) : _repository = repository,
       _agencyId = agencyId;

  final CreditPipelineRepository _repository;
  final String _agencyId;

  final List<PendingApprovalItem> _items = [];
  bool isLoading = false;
  String? errorMessage;

  List<PendingApprovalItem> get requests {
    final ready = _items.where((item) => item.isReadyForApproval).toList();
    final pending =
        _items.where((item) => !item.isReadyForApproval).toList();
    return [...ready, ...pending];
  }

  int get readyCount =>
      _items.where((item) => item.isReadyForApproval).length;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchAgencyApprovalQueue(
        agencyId: _agencyId,
      );
      _items
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

class SubmittedRequestsViewModel extends ChangeNotifier {
  SubmittedRequestsViewModel({required CreditPipelineRepository repository})
    : _repository = repository;

  final CreditPipelineRepository _repository;

  final List<SubmittedCreditRequest> _requests = [];
  bool isLoading = false;
  String? errorMessage;

  List<SubmittedCreditRequest> get requests => List.unmodifiable(_requests);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchSubmittedRequests();
      _requests
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

class CreditRequestDetailViewModel extends ChangeNotifier {
  CreditRequestDetailViewModel({
    required CreditPipelineRepository repository,
    required TransmissionProgressService transmissionService,
    required String solicitudId,
  }) : _repository = repository,
       _transmissionService = transmissionService,
       _solicitudId = solicitudId;

  final CreditPipelineRepository _repository;
  final TransmissionProgressService _transmissionService;
  final String _solicitudId;

  CreditRequestDetail? detail;
  bool isLoading = false;
  bool isConsultingBureau = false;
  bool isTransmitting = false;
  bool isSavingNote = false;
  bool isUpdatingClientAppStatus = false;
  bool isRunningPreEvaluation = false;
  bool isRegisteringVisit = false;
  String? errorMessage;
  String? successMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      detail = await _repository.fetchRequestDetail(_solicitudId);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> consultBureau(String consentSignatureBase64) async {
    final current = detail;
    if (current == null) {
      return false;
    }

    isConsultingBureau = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final result = await _repository.runBureauConsult(
        solicitudId: current.request.id,
        clientId: current.request.clientId,
        documentNumber: current.request.documentNumber,
        consentSignatureBase64: consentSignatureBase64,
      );
      await load();
      successMessage = result.pendingSync
          ? 'Consulta buró guardada offline. Se sincronizara al reconectar.'
          : 'Consulta buró registrada.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isConsultingBureau = false;
      notifyListeners();
    }
  }

  Future<bool> addInternalNote(String content) async {
    final current = detail;
    if (current == null) {
      return false;
    }

    isSavingNote = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.addInternalNote(
        solicitudId: current.request.id,
        content: content,
      );
      await load();
      successMessage = 'Nota interna registrada.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSavingNote = false;
      notifyListeners();
    }
  }

  Future<bool> updateClientAppStatus({
    required String nuevoEstado,
    String? motivoRechazo,
    double? montoAprobado,
    String? condicionAdicional,
  }) async {
    final current = detail;
    if (current == null || !current.request.isFromClientApp) {
      return false;
    }

    isUpdatingClientAppStatus = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.updateClientAppRequestStatus(
        solicitudId: current.request.id,
        nuevoEstado: nuevoEstado,
        motivoRechazo: motivoRechazo,
        montoAprobado: montoAprobado,
        condicionAdicional: condicionAdicional,
      );
      await load();
      successMessage = 'Estado actualizado: '
          '${SolicitudPipelineStatus.fromCode(nuevoEstado).label}.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isUpdatingClientAppStatus = false;
      notifyListeners();
    }
  }

  Future<bool> runPreEvaluation() async {
    final current = detail;
    if (current == null || !current.request.isFromClientApp) {
      return false;
    }

    isRunningPreEvaluation = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.runPreEvaluationForRequest(current.request.id);
      await load();
      successMessage = 'Pre-evaluacion registrada.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isRunningPreEvaluation = false;
      notifyListeners();
    }
  }

  Future<bool> registerClientAppVisit({
    double? latitude,
    double? longitude,
    String? observation,
  }) async {
    final current = detail;
    if (current == null || !current.request.isFromClientApp) {
      return false;
    }

    isRegisteringVisit = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.registerClientAppVisit(
        solicitudId: current.request.id,
        latitude: latitude,
        longitude: longitude,
        observation: observation,
      );
      await load();
      successMessage = 'Visita registrada en campo.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isRegisteringVisit = false;
      notifyListeners();
    }
  }

  Future<bool> transmit({
    void Function(TransmissionStep step, int current, int total)? onProgress,
  }) async {
    final current = detail;
    if (current == null) {
      return false;
    }

    final checklist = TransmissionChecklist.evaluate(current);
    if (!checklist.isReady) {
      final pending = checklist.pendingItems.map((item) => item.label).join(', ');
      errorMessage =
          'Checklist incompleto antes de transmitir: $pending.';
      notifyListeners();
      return false;
    }

    isTransmitting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final result = await _transmissionService.transmitWithProgress(
        detail: current,
        transmitCore: () => _repository.transmitRequest(current.request.id),
        onProgress: onProgress,
      );
      if (!result.success) {
        errorMessage = result.errorMessage ?? 'No se pudo transmitir.';
        return false;
      }

      await load();
      successMessage = result.offline
          ? 'Transmision pendiente de sincronizacion.'
          : 'Solicitud transmitida al back office.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isTransmitting = false;
      notifyListeners();
    }
  }
}

class SolicitudChatViewModel extends ChangeNotifier {
  SolicitudChatViewModel({
    required CreditPipelineRepository repository,
    required String solicitudId,
    required String clienteId,
  }) : _repository = repository,
       _solicitudId = solicitudId,
       _clienteId = clienteId;

  final CreditPipelineRepository _repository;
  final String _solicitudId;
  final String _clienteId;

  final List<SolicitudMensaje> _mensajes = [];
  bool isLoading = false;
  bool isSending = false;
  bool chatNoDisponible = false;
  String? errorMessage;
  supabase.RealtimeChannel? _channel;

  List<SolicitudMensaje> get mensajes => List.unmodifiable(_mensajes);

  void startListening() {
    _channel?.unsubscribe();
    _channel = _repository.subscribeMensajesSolicitud(
      solicitudId: _solicitudId,
      onChange: load,
    );
  }

  Future<void> load() async {
    isLoading = _mensajes.isEmpty;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchMensajesSolicitud(_solicitudId);
      _mensajes
        ..clear()
        ..addAll(fetched);
      await _repository.marcarMensajesLeidosAsesor(_solicitudId);
    } catch (error) {
      if (error is ChatNoDisponibleException) {
        chatNoDisponible = true;
      }
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> send(String contenido) async {
    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.enviarMensajeAsesor(
        solicitudId: _solicitudId,
        clienteId: _clienteId,
        contenido: contenido,
      );
      await load();
      return true;
    } catch (error) {
      if (error is ChatNoDisponibleException) {
        chatNoDisponible = true;
      }
      errorMessage = error.toString();
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

class DocumentsHubViewModel extends ChangeNotifier {
  DocumentsHubViewModel({required CreditPipelineRepository repository})
    : _repository = repository;

  final CreditPipelineRepository _repository;

  final List<StoredCreditDocument> _documents = [];
  bool isLoading = false;
  String? errorMessage;

  List<StoredCreditDocument> get documents => List.unmodifiable(_documents);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchRecentDocuments();
      _documents
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
