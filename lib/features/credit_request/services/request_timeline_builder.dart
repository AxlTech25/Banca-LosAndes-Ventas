import '../models/pipeline_models.dart';

class RequestTimelineBuilder {
  const RequestTimelineBuilder._();

  static List<RequestTimelineEvent> build(CreditRequestDetail detail) {
    if (detail.request.isFromClientApp) {
      return _buildClientAppTimeline(detail);
    }
    return _buildOperatorTimeline(detail);
  }

  static List<RequestTimelineEvent> _buildClientAppTimeline(
    CreditRequestDetail detail,
  ) {
    final request = detail.request;
    final events = <RequestTimelineEvent>[
      RequestTimelineEvent(
        title: 'Solicitud enviada',
        description:
            'El cliente registro ${request.expedienteNumber} desde la app.',
        timestamp: request.createdAt,
        responsible: request.clientName,
      ),
    ];

    if (detail.bureauConsult != null) {
      events.add(
        RequestTimelineEvent(
          title: 'Consulta buró',
          description:
              'Calificacion ${detail.bureauConsult!.rating.label} registrada.',
          timestamp: detail.bureauConsult!.consultedAt,
          responsible: 'Asesor de negocios',
        ),
      );
    }

    final status = request.status;

    if (status != SolicitudPipelineStatus.pendiente &&
        status != SolicitudPipelineStatus.borrador) {
      events.add(
        RequestTimelineEvent(
          title: 'En evaluacion',
          description: 'Un asesor revisa la solicitud del cliente.',
          timestamp: request.updatedAt,
          responsible: request.advisorName ?? 'Asesor de negocios',
          isCompleted: status != SolicitudPipelineStatus.enEvaluacion,
          isFuture: status == SolicitudPipelineStatus.enEvaluacion,
        ),
      );
    }

    if (status == SolicitudPipelineStatus.observada) {
      events.add(
        RequestTimelineEvent(
          title: 'Documentos requeridos',
          description: request.additionalCondition ??
              'Se solicitaron documentos adicionales al cliente.',
          timestamp: request.updatedAt,
          responsible: request.advisorName ?? 'Asesor de negocios',
        ),
      );
    }

    if (status == SolicitudPipelineStatus.aprobada) {
      events.add(
        RequestTimelineEvent(
          title: 'Credito aprobado',
          description: request.approvedAmount == null
              ? 'Solicitud aprobada por el asesor.'
              : 'Monto aprobado: S/ ${request.approvedAmount!.toStringAsFixed(2)}.',
          timestamp: request.updatedAt,
          responsible: request.advisorName ?? 'Asesor de negocios',
        ),
      );
      events.add(
        const RequestTimelineEvent(
          title: 'Desembolso pendiente',
          description: 'Confirma el desembolso cuando el credito se active.',
          timestamp: null,
          responsible: 'Asesor de negocios',
          isCompleted: false,
          isFuture: true,
        ),
      );
    } else if (status == SolicitudPipelineStatus.rechazada) {
      events.add(
        RequestTimelineEvent(
          title: 'Solicitud rechazada',
          description: request.rejectionReason ?? 'No aprobada en esta ocasion.',
          timestamp: request.updatedAt,
          responsible: request.advisorName ?? 'Asesor de negocios',
        ),
      );
    } else if (status == SolicitudPipelineStatus.desembolsada) {
      events.add(
        RequestTimelineEvent(
          title: 'Credito aprobado',
          description: request.approvedAmount == null
              ? 'Solicitud aprobada por el asesor.'
              : 'Monto aprobado: S/ ${request.approvedAmount!.toStringAsFixed(2)}.',
          timestamp: request.updatedAt,
          responsible: request.advisorName ?? 'Asesor de negocios',
        ),
      );
      events.add(
        RequestTimelineEvent(
          title: 'Credito desembolsado',
          description: 'El cliente puede ver el credito en su app.',
          timestamp: request.updatedAt,
          responsible: 'Operaciones',
        ),
      );
    }

    return events;
  }

  static List<RequestTimelineEvent> _buildOperatorTimeline(
    CreditRequestDetail detail,
  ) {
    final request = detail.request;
    final events = <RequestTimelineEvent>[
      RequestTimelineEvent(
        title: 'Solicitud registrada',
        description: 'Expediente ${request.expedienteNumber} capturado en campo.',
        timestamp: request.createdAt,
        responsible: 'Asesor de negocios',
      ),
    ];

    if (detail.bureauConsult != null) {
      events.add(
        RequestTimelineEvent(
          title: 'Consulta buró',
          description:
              'Calificacion ${detail.bureauConsult!.rating.label} registrada.',
          timestamp: detail.bureauConsult!.consultedAt,
          responsible: 'Asesor de negocios',
        ),
      );
    }

    if (request.status == SolicitudPipelineStatus.transmitida ||
        request.status == SolicitudPipelineStatus.enAnalisis ||
        request.status == SolicitudPipelineStatus.aprobada ||
        request.status == SolicitudPipelineStatus.desembolsada ||
        request.status == SolicitudPipelineStatus.rechazada) {
      events.add(
        RequestTimelineEvent(
          title: 'Transmitida al comite',
          description: 'Back office recibio la solicitud para evaluacion.',
          timestamp: request.updatedAt ?? request.createdAt,
          responsible: 'Sistema central',
        ),
      );
    }

    if (request.status == SolicitudPipelineStatus.enAnalisis ||
        request.assignedAnalyst != null) {
      events.add(
        RequestTimelineEvent(
          title: 'En evaluacion',
          description: request.assignedAnalyst == null
              ? 'Esperando asignacion de analista.'
              : 'Analista ${request.assignedAnalyst} revisando el expediente.',
          timestamp: request.updatedAt,
          responsible: request.assignedAnalyst ?? 'Comite de credito',
          isCompleted: request.status != SolicitudPipelineStatus.transmitida,
          isFuture: request.status == SolicitudPipelineStatus.transmitida,
        ),
      );
    }

    switch (request.status) {
      case SolicitudPipelineStatus.aprobada:
        events.add(
          RequestTimelineEvent(
            title: 'Credito aprobado',
            description: request.approvedAmount == null
                ? 'Comite aprobo la solicitud.'
                : 'Monto aprobado: S/ ${request.approvedAmount!.toStringAsFixed(2)}.',
            timestamp: request.updatedAt,
            responsible: request.assignedAnalyst ?? 'Comite de credito',
          ),
        );
      case SolicitudPipelineStatus.rechazada:
        events.add(
          RequestTimelineEvent(
            title: 'Solicitud rechazada',
            description: request.rejectionReason ?? 'Comite rechazo la solicitud.',
            timestamp: request.updatedAt,
            responsible: request.assignedAnalyst ?? 'Comite de credito',
          ),
        );
      case SolicitudPipelineStatus.desembolsada:
        events.add(
          RequestTimelineEvent(
            title: 'Credito desembolsado',
            description: 'Cliente puede retirar en agencia.',
            timestamp: request.updatedAt,
            responsible: 'Operaciones',
          ),
        );
      default:
        break;
    }

    if (!request.status.isClosed &&
        request.status != SolicitudPipelineStatus.rechazada) {
      events.addAll(const [
        RequestTimelineEvent(
          title: 'Desembolso en agencia',
          description: 'Pendiente de confirmacion operativa.',
          timestamp: null,
          responsible: 'Operaciones',
          isCompleted: false,
          isFuture: true,
        ),
      ]);
    }

    return events;
  }
}
