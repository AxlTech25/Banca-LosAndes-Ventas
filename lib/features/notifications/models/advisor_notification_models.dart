enum AdvisorNotificationType {
  solicitudNueva('solicitud_nueva', 'Nueva solicitud'),
  chatCliente('chat_cliente', 'Mensaje de cliente'),
  pagoPendiente('pago_pendiente', 'Pago por confirmar');

  const AdvisorNotificationType(this.code, this.label);

  final String code;
  final String label;

  static AdvisorNotificationType fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return AdvisorNotificationType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => AdvisorNotificationType.solicitudNueva,
    );
  }
}

class AdvisorNotification {
  const AdvisorNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.advisorId,
    this.referenciaTipo,
    this.referenciaId,
  });

  factory AdvisorNotification.fromJson(
    Map<String, dynamic> json, {
    required Set<String> readBroadcastIds,
  }) {
    final asesorId = json['asesor_id']?.toString();
    final id = json['id'].toString();
    final isBroadcast = asesorId == null || asesorId.isEmpty;

    return AdvisorNotification(
      id: id,
      advisorId: isBroadcast ? null : asesorId,
      type: AdvisorNotificationType.fromCode(json['tipo']?.toString()),
      title: (json['titulo'] ?? '').toString(),
      message: (json['mensaje'] ?? '').toString(),
      isRead: isBroadcast
          ? readBroadcastIds.contains(id)
          : json['leida'] == true,
      referenciaTipo: json['referencia_tipo']?.toString(),
      referenciaId: json['referencia_id']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String? advisorId;
  final AdvisorNotificationType type;
  final String title;
  final String message;
  final bool isRead;
  final String? referenciaTipo;
  final String? referenciaId;
  final DateTime createdAt;

  AdvisorNotification copyWith({bool? isRead}) {
    return AdvisorNotification(
      id: id,
      advisorId: advisorId,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      referenciaTipo: referenciaTipo,
      referenciaId: referenciaId,
      createdAt: createdAt,
    );
  }
}
