import '../../../shared/widgets/risk_semaphore.dart';

enum SolicitudPipelineStatus {
  pendiente('pendiente', 'Pendiente', 0xFFFFC857),
  enEvaluacion('en_evaluacion', 'En evaluacion', 0xFFFFC857),
  observada('observada', 'Observada', 0xFFFF9800),
  enviada('enviada', 'Enviada', 0xFF89D9FF),
  transmitida('transmitida', 'Transmitida', 0xFF27C46B),
  enAnalisis('en_analisis', 'En analisis', 0xFFFFC857),
  aprobada('aprobada', 'Aprobada', 0xFF27C46B),
  desembolsada('desembolsada', 'Desembolsada', 0xFF6ED2FF),
  rechazada('rechazada', 'Rechazada', 0xFFFF4D4D),
  borrador('borrador', 'Borrador', 0xFF86929A);

  const SolicitudPipelineStatus(this.code, this.label, this.colorValue);

  final String code;
  final String label;
  final int colorValue;

  static SolicitudPipelineStatus fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return SolicitudPipelineStatus.values.firstWhere(
      (status) => status.code == normalized,
      orElse: () => SolicitudPipelineStatus.enviada,
    );
  }

  bool get canTransmit => this == SolicitudPipelineStatus.enviada;

  bool get isClientAppOpenState =>
      this == SolicitudPipelineStatus.pendiente ||
      this == SolicitudPipelineStatus.enEvaluacion ||
      this == SolicitudPipelineStatus.observada;

  bool get isClosed =>
      this == SolicitudPipelineStatus.aprobada ||
      this == SolicitudPipelineStatus.desembolsada ||
      this == SolicitudPipelineStatus.rechazada;

  bool get isTrackable => this != SolicitudPipelineStatus.borrador;

  static List<SolicitudPipelineStatus> get trackingStatuses => [
    SolicitudPipelineStatus.enviada,
    SolicitudPipelineStatus.transmitida,
    SolicitudPipelineStatus.enAnalisis,
    SolicitudPipelineStatus.aprobada,
    SolicitudPipelineStatus.desembolsada,
    SolicitudPipelineStatus.rechazada,
  ];
}

enum RequestStatusTab {
  enviadas('Enviadas'),
  enComite('En comite'),
  aprobadas('Aprobadas'),
  desembolsadas('Desembolsadas'),
  rechazadas('Rechazadas');

  const RequestStatusTab(this.label);

  final String label;

  bool matches(SolicitudPipelineStatus status) {
    return switch (this) {
      RequestStatusTab.enviadas => status == SolicitudPipelineStatus.enviada,
      RequestStatusTab.enComite =>
        status == SolicitudPipelineStatus.transmitida ||
            status == SolicitudPipelineStatus.enAnalisis,
      RequestStatusTab.aprobadas => status == SolicitudPipelineStatus.aprobada,
      RequestStatusTab.desembolsadas =>
        status == SolicitudPipelineStatus.desembolsada,
      RequestStatusTab.rechazadas => status == SolicitudPipelineStatus.rechazada,
    };
  }
}

enum RequestDateRangeFilter {
  all('Todo'),
  last7('7 dias'),
  last30('30 dias'),
  thisMonth('Este mes');

  const RequestDateRangeFilter(this.label);

  final String label;

  DateTime? get startDate {
    final now = DateTime.now();
    return switch (this) {
      RequestDateRangeFilter.all => null,
      RequestDateRangeFilter.last7 => now.subtract(const Duration(days: 7)),
      RequestDateRangeFilter.last30 => now.subtract(const Duration(days: 30)),
      RequestDateRangeFilter.thisMonth => DateTime(now.year, now.month),
    };
  }
}

class RequestStatusSummary {
  const RequestStatusSummary({
    this.transmitida = 0,
    this.enAnalisis = 0,
    this.aprobada = 0,
    this.desembolsada = 0,
    this.rechazada = 0,
    this.enviada = 0,
  });

  final int transmitida;
  final int enAnalisis;
  final int aprobada;
  final int desembolsada;
  final int rechazada;
  final int enviada;

  int get inComite => transmitida + enAnalisis;
  int get closed => aprobada + desembolsada + rechazada;
  int get total =>
      transmitida + enAnalisis + aprobada + desembolsada + rechazada + enviada;

  int countForTab(RequestStatusTab tab) {
    return switch (tab) {
      RequestStatusTab.enviadas => enviada,
      RequestStatusTab.enComite => inComite,
      RequestStatusTab.aprobadas => aprobada,
      RequestStatusTab.desembolsadas => desembolsada,
      RequestStatusTab.rechazadas => rechazada,
    };
  }

  factory RequestStatusSummary.fromRequests(
    List<SubmittedCreditRequest> requests,
  ) {
    var transmitida = 0;
    var enAnalisis = 0;
    var aprobada = 0;
    var desembolsada = 0;
    var rechazada = 0;
    var enviada = 0;

    for (final request in requests) {
      switch (request.status) {
        case SolicitudPipelineStatus.transmitida:
          transmitida++;
        case SolicitudPipelineStatus.enAnalisis:
          enAnalisis++;
        case SolicitudPipelineStatus.aprobada:
          aprobada++;
        case SolicitudPipelineStatus.desembolsada:
          desembolsada++;
        case SolicitudPipelineStatus.rechazada:
          rechazada++;
        case SolicitudPipelineStatus.enviada:
          enviada++;
        case SolicitudPipelineStatus.pendiente:
        case SolicitudPipelineStatus.enEvaluacion:
        case SolicitudPipelineStatus.observada:
          enviada++;
        case SolicitudPipelineStatus.borrador:
          break;
      }
    }

    return RequestStatusSummary(
      transmitida: transmitida,
      enAnalisis: enAnalisis,
      aprobada: aprobada,
      desembolsada: desembolsada,
      rechazada: rechazada,
      enviada: enviada,
    );
  }
}

class RequestTimelineEvent {
  const RequestTimelineEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    this.responsible,
    this.isCompleted = true,
    this.isFuture = false,
  });

  final String title;
  final String description;
  final DateTime? timestamp;
  final String? responsible;
  final bool isCompleted;
  final bool isFuture;
}

class StatusChangeNotification {
  const StatusChangeNotification({
    required this.id,
    required this.solicitudId,
    required this.expedienteNumber,
    required this.clientName,
    required this.status,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String solicitudId;
  final String expedienteNumber;
  final String clientName;
  final SolicitudPipelineStatus status;
  final String message;
  final DateTime createdAt;
  final bool read;

  StatusChangeNotification markRead() {
    return StatusChangeNotification(
      id: id,
      solicitudId: solicitudId,
      expedienteNumber: expedienteNumber,
      clientName: clientName,
      status: status,
      message: message,
      createdAt: createdAt,
      read: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'solicitudId': solicitudId,
      'expedienteNumber': expedienteNumber,
      'clientName': clientName,
      'status': status.code,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'read': read,
    };
  }

  factory StatusChangeNotification.fromJson(Map<String, dynamic> json) {
    return StatusChangeNotification(
      id: json['id'].toString(),
      solicitudId: json['solicitudId'].toString(),
      expedienteNumber: json['expedienteNumber'].toString(),
      clientName: json['clientName'].toString(),
      status: SolicitudPipelineStatus.fromCode(json['status']?.toString()),
      message: json['message'].toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      read: json['read'] == true,
    );
  }
}

class SolicitudInternalNote {
  const SolicitudInternalNote({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;

  factory SolicitudInternalNote.fromJson(Map<String, dynamic> json) {
    return SolicitudInternalNote(
      id: json['id'].toString(),
      content: (json['contenido'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SubmittedCreditRequest {
  const SubmittedCreditRequest({
    required this.id,
    required this.expedienteNumber,
    required this.clientId,
    required this.clientName,
    required this.documentNumber,
    required this.requestedAmount,
    required this.termMonths,
    required this.status,
    required this.createdAt,
    required this.pendingSync,
    required this.hasBureauConsult,
    this.origen = 'app_operador',
    this.approvedAmount,
    this.rejectionReason,
    this.additionalCondition,
    this.assignedAnalyst,
    this.updatedAt,
    this.advisorName,
  });

  final String id;
  final String expedienteNumber;
  final String clientId;
  final String clientName;
  final String documentNumber;
  final double requestedAmount;
  final int termMonths;
  final SolicitudPipelineStatus status;
  final DateTime createdAt;
  final bool pendingSync;
  final bool hasBureauConsult;
  final String origen;
  final double? approvedAmount;
  final String? rejectionReason;
  final String? additionalCondition;
  final String? assignedAnalyst;
  final DateTime? updatedAt;
  final String? advisorName;

  bool get hasResolution =>
      status.isClosed ||
      assignedAnalyst != null ||
      approvedAmount != null ||
      (rejectionReason != null && rejectionReason!.isNotEmpty);

  bool get isFromClientApp => origen == 'app_cliente';

  int get daysSinceSubmission {
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  factory SubmittedCreditRequest.fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'];
    var clientName = 'Cliente';
    var documentNumber = '';
    if (cliente is Map) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      clientName = '$nombres $apellidos'.trim();
      documentNumber = (cliente['numero_documento'] ?? '').toString();
    }

    final consultas = json['consultas_buro'];
    final hasConsult = consultas is List && consultas.isNotEmpty;

    final asesor = json['asesores_negocio'];
    String? advisorName;
    if (asesor is Map) {
      final nombres = (asesor['nombres'] ?? '').toString().trim();
      final apellidos = (asesor['apellidos'] ?? '').toString().trim();
      final code = (asesor['codigo_empleado'] ?? '').toString().trim();
      final fullName = '$nombres $apellidos'.trim();
      if (fullName.isNotEmpty && code.isNotEmpty) {
        advisorName = '$fullName ($code)';
      } else if (fullName.isNotEmpty) {
        advisorName = fullName;
      }
    }

    return SubmittedCreditRequest(
      id: json['id'].toString(),
      expedienteNumber: (json['numero_expediente'] ?? 'S/N').toString(),
      clientId: json['cliente_id'].toString(),
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      documentNumber: documentNumber,
      requestedAmount: _doubleValue(json['monto_solicitado']),
      termMonths: _intValue(json['plazo_meses']) ?? 0,
      status: SolicitudPipelineStatus.fromCode(json['estado']?.toString()),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      pendingSync: json['pendiente_sync'] == true,
      hasBureauConsult: hasConsult,
      origen: (json['origen'] ?? 'app_operador').toString(),
      approvedAmount: _doubleOrNull(json['monto_aprobado']),
      rejectionReason: json['motivo_rechazo']?.toString(),
      additionalCondition: json['condicion_adicional']?.toString(),
      assignedAnalyst: json['analista_asignado']?.toString(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      advisorName: advisorName,
    );
  }
}

class StoredCreditDocument {
  const StoredCreditDocument({
    required this.id,
    required this.solicitudId,
    required this.expedienteNumber,
    required this.clientName,
    required this.typeCode,
    required this.typeLabel,
    required this.storageUrl,
    required this.sizeKb,
    required this.createdAt,
    this.sharpnessScore,
  });

  final String id;
  final String solicitudId;
  final String expedienteNumber;
  final String clientName;
  final String typeCode;
  final String typeLabel;
  final String storageUrl;
  final int sizeKb;
  final DateTime createdAt;
  final double? sharpnessScore;

  bool get isDataUri => storageUrl.startsWith('data:');

  factory StoredCreditDocument.fromJson(Map<String, dynamic> json) {
    final solicitud = json['solicitudes_credito'];
    var expediente = 'S/N';
    var clientName = 'Cliente';
    if (solicitud is Map) {
      expediente = (solicitud['numero_expediente'] ?? 'S/N').toString();
      final cliente = solicitud['clientes'];
      if (cliente is Map) {
        final nombres = (cliente['nombres'] ?? '').toString().trim();
        final apellidos = (cliente['apellidos'] ?? '').toString().trim();
        clientName = '$nombres $apellidos'.trim();
      }
    }

    return StoredCreditDocument(
      id: json['id'].toString(),
      solicitudId: json['solicitud_id'].toString(),
      expedienteNumber: expediente,
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      typeCode: (json['tipo_documento'] ?? '').toString(),
      typeLabel: _labelForType(json['tipo_documento']?.toString()),
      storageUrl: (json['storage_url'] ?? '').toString(),
      sizeKb: _intValue(json['tamanio_kb']) ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      sharpnessScore: _doubleOrNull(json['nitidez_score']),
    );
  }

  static String _labelForType(String? code) {
    return switch ((code ?? '').toUpperCase()) {
      'DNI_ANVERSO' => 'DNI anverso',
      'DNI_REVERSO' => 'DNI reverso',
      'RECIBO_SERVICIO' => 'Recibo de servicio',
      'FACHADA_NEGOCIO' => 'Fachada del negocio',
      'FOTO_CLIENTE_ASESOR' => 'Foto cliente y asesor',
      _ => code ?? 'Documento',
    };
  }
}

class BureauConsultResult {
  const BureauConsultResult({
    required this.id,
    required this.solicitudId,
    required this.documentNumber,
    required this.rating,
    required this.debtEntities,
    required this.totalDebtPen,
    required this.largestDebt,
    required this.maxOverdueDays,
    required this.consultedAt,
    this.pendingSync = false,
  });

  final String id;
  final String solicitudId;
  final String documentNumber;
  final SbsRating rating;
  final int debtEntities;
  final double totalDebtPen;
  final double largestDebt;
  final int maxOverdueDays;
  final DateTime consultedAt;
  final bool pendingSync;

  bool get blocksTransmission =>
      rating == SbsRating.doubtful || rating == SbsRating.loss;

  factory BureauConsultResult.fromJson(Map<String, dynamic> json) {
    return BureauConsultResult(
      id: json['id'].toString(),
      solicitudId: (json['solicitud_id'] ?? '').toString(),
      documentNumber: (json['dni_consultado'] ?? '').toString(),
      rating: SbsRating.fromCode(json['calificacion_sbs']?.toString()),
      debtEntities: _intValue(json['entidades_con_deuda']) ?? 0,
      totalDebtPen: _doubleValue(json['deuda_total_pen']),
      largestDebt: _doubleValue(json['mayor_deuda']),
      maxOverdueDays: _intValue(json['dias_mayor_mora']) ?? 0,
      consultedAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SolicitudPreEvaluation {
  const SolicitudPreEvaluation({
    required this.calificacion,
    required this.motivo,
    this.puntaje,
    this.evaluatedAt,
  });

  final String calificacion;
  final String motivo;
  final int? puntaje;
  final DateTime? evaluatedAt;

  bool get isApto => calificacion.trim().toUpperCase() == 'APTO';

  factory SolicitudPreEvaluation.fromJson(Map<String, dynamic> json) {
    return SolicitudPreEvaluation(
      calificacion: (json['calificacion'] ?? '').toString(),
      motivo: (json['motivo'] ?? '').toString(),
      puntaje: _intValue(json['puntaje']),
      evaluatedAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class PendingApprovalItem {
  const PendingApprovalItem({
    required this.request,
    required this.visitCompleted,
    required this.preEvalApto,
    required this.hasBureau,
    this.preEvalScore,
  });

  final SubmittedCreditRequest request;
  final bool visitCompleted;
  final bool preEvalApto;
  final bool hasBureau;
  final int? preEvalScore;

  bool get isReadyForApproval =>
      visitCompleted && preEvalApto && hasBureau;

  int get completedChecklistSteps =>
      (visitCompleted ? 1 : 0) + (preEvalApto ? 1 : 0) + (hasBureau ? 1 : 0);
}

class CreditRequestDetail {
  const CreditRequestDetail({
    required this.request,
    required this.documents,
    required this.internalNotes,
    this.bureauConsult,
    this.visitCompleted = false,
    this.preEvaluation,
  });

  final SubmittedCreditRequest request;
  final List<StoredCreditDocument> documents;
  final List<SolicitudInternalNote> internalNotes;
  final BureauConsultResult? bureauConsult;
  final bool visitCompleted;
  final SolicitudPreEvaluation? preEvaluation;

  bool get clientAppChecklistComplete =>
      visitCompleted &&
      preEvaluation?.isApto == true &&
      bureauConsult != null &&
      !bureauConsult!.blocksTransmission;
}

class TransmissionResult {
  const TransmissionResult({
    this.success = true,
    this.offline = false,
    this.errorMessage,
  });

  final bool success;
  final bool offline;
  final String? errorMessage;
}

class SolicitudMensaje {
  const SolicitudMensaje({
    required this.id,
    required this.solicitudId,
    required this.autorTipo,
    required this.contenido,
    this.createdAt,
  });

  final String id;
  final String solicitudId;
  final String autorTipo;
  final String contenido;
  final DateTime? createdAt;

  bool get esPropio => autorTipo == 'asesor';
  bool get esCliente => autorTipo == 'cliente';

  factory SolicitudMensaje.fromJson(Map<String, dynamic> json) {
    return SolicitudMensaje(
      id: json['id'].toString(),
      solicitudId: json['solicitud_id'].toString(),
      autorTipo: (json['autor_tipo'] ?? '').toString(),
      contenido: (json['contenido'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

int? _intValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}
