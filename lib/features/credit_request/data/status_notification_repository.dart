import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pipeline_models.dart';

class StatusNotificationRepository {
  StatusNotificationRepository({required SharedPreferences preferences})
    : _preferences = preferences;

  final SharedPreferences _preferences;

  String get _storageKey => 'status_notifications';

  List<StatusChangeNotification> loadAll() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(StatusChangeNotification.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int unreadCount() {
    return loadAll().where((item) => !item.read).length;
  }

  Future<void> recordStatusChanges({
    required List<SubmittedCreditRequest> previous,
    required List<SubmittedCreditRequest> current,
  }) async {
    final previousById = {for (final item in previous) item.id: item.status};
    final notifications = loadAll();
    final existingIds = notifications.map((item) => item.id).toSet();

    for (final request in current) {
      final oldStatus = previousById[request.id];
      if (oldStatus == null || oldStatus == request.status) {
        continue;
      }
      if (!_notifiableStatus(request.status)) {
        continue;
      }

      final id = '${request.id}_${request.status.code}_${request.updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
      if (existingIds.contains(id)) {
        continue;
      }

      notifications.insert(
        0,
        StatusChangeNotification(
          id: id,
          solicitudId: request.id,
          expedienteNumber: request.expedienteNumber,
          clientName: request.clientName,
          status: request.status,
          message: _messageForStatus(request),
          createdAt: request.updatedAt ?? DateTime.now(),
        ),
      );
    }

    await _save(notifications);
  }

  Future<void> markRead(String notificationId) async {
    final updated = loadAll()
        .map(
          (item) => item.id == notificationId ? item.markRead() : item,
        )
        .toList();
    await _save(updated);
  }

  Future<void> markAllRead() async {
    final updated = loadAll().map((item) => item.markRead()).toList();
    await _save(updated);
  }

  bool _notifiableStatus(SolicitudPipelineStatus status) {
    return status == SolicitudPipelineStatus.aprobada ||
        status == SolicitudPipelineStatus.rechazada ||
        status == SolicitudPipelineStatus.desembolsada ||
        status == SolicitudPipelineStatus.enAnalisis ||
        status == SolicitudPipelineStatus.transmitida;
  }

  String _messageForStatus(SubmittedCreditRequest request) {
    return switch (request.status) {
      SolicitudPipelineStatus.transmitida =>
        '${request.clientName} — expediente en evaluacion.',
      SolicitudPipelineStatus.enAnalisis =>
        '${request.clientName} — analista ${request.assignedAnalyst ?? 'asignado'}.',
      SolicitudPipelineStatus.aprobada =>
        '${request.clientName} — S/${request.approvedAmount?.toStringAsFixed(2) ?? request.requestedAmount.toStringAsFixed(2)} aprobado.',
      SolicitudPipelineStatus.rechazada =>
        '${request.clientName} — ${request.rejectionReason ?? 'Solicitud rechazada.'}',
      SolicitudPipelineStatus.desembolsada =>
        '${request.clientName} puede retirar en agencia.',
      _ => '${request.clientName} — ${request.status.label}.',
    };
  }

  Future<void> _save(List<StatusChangeNotification> notifications) async {
    final trimmed = notifications.take(50).toList();
    await _preferences.setString(
      _storageKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }
}
