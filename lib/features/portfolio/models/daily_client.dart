import 'package:flutter/material.dart';

enum ManagementType {
  renewal('RENOVACION', 'Renovacion', Color(0xFF00A8FF)),
  extension('AMPLIACION', 'Ampliacion', Color(0xFF27C46B)),
  newRequest('NUEVA_SOLICITUD', 'Nueva solicitud', Color(0xFFFF9F1C)),
  followUp('SEGUIMIENTO', 'Seguimiento', Color(0xFF86929A)),
  recovery('RECUPERACION_MORA', 'Recuperacion mora', Color(0xFFFF4D4D)),
  deserter('DESERTOR', 'Desertor', Color(0xFF9B5DE5));

  const ManagementType(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static ManagementType fromCode(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_');
    return ManagementType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => ManagementType.followUp,
    );
  }
}

enum VisitStatus {
  pending('pendiente', 'Pendiente'),
  visited('visitado', 'Visitado'),
  notFound('no_encontrado', 'No encontrado'),
  rescheduled('reagendar', 'Reagendar'),
  closedBusiness('negocio_cerrado', 'Negocio cerrado');

  const VisitStatus(this.code, this.label);

  final String code;
  final String label;

  bool get isCompleted => this != VisitStatus.pending;

  static VisitStatus fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return VisitStatus.values.firstWhere(
      (status) => status.code == normalized,
      orElse: () => VisitStatus.pending,
    );
  }
}

enum PriorityLevel {
  high('ALTA'),
  medium('MEDIA'),
  normal('NORMAL');

  const PriorityLevel(this.label);

  final String label;

  static PriorityLevel fromScore(int score) {
    if (score >= 70) {
      return PriorityLevel.high;
    }
    if (score >= 35) {
      return PriorityLevel.medium;
    }
    return PriorityLevel.normal;
  }
}

class DailyClient {
  const DailyClient({
    required this.id,
    required this.clientId,
    required this.advisorId,
    required this.clientName,
    required this.documentNumber,
    required this.managementType,
    required this.creditAmount,
    required this.priorityScore,
    required this.visitStatus,
    required this.assignmentDate,
    this.creditId,
    this.daysPastDue = 0,
    this.latitude,
    this.longitude,
    this.localOrder,
    this.observation,
    this.solicitudId,
  });

  final String id;
  final String clientId;
  final String advisorId;
  final String clientName;
  final String documentNumber;
  final ManagementType managementType;
  final double creditAmount;
  final int priorityScore;
  final VisitStatus visitStatus;
  final DateTime assignmentDate;
  final String? creditId;
  final int daysPastDue;
  final double? latitude;
  final double? longitude;
  final int? localOrder;
  final String? observation;
  final String? solicitudId;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isVisited => visitStatus.isCompleted;

  PriorityLevel get priorityLevel => PriorityLevel.fromScore(priorityScore);

  String get maskedDocument {
    final digits = documentNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) {
      return '***$digits';
    }
    return '***${digits.substring(digits.length - 4)}';
  }

  DailyClient copyWith({
    VisitStatus? visitStatus,
    double? latitude,
    double? longitude,
    int? localOrder,
    String? observation,
    String? solicitudId,
  }) {
    return DailyClient(
      id: id,
      clientId: clientId,
      advisorId: advisorId,
      clientName: clientName,
      documentNumber: documentNumber,
      managementType: managementType,
      creditAmount: creditAmount,
      priorityScore: priorityScore,
      visitStatus: visitStatus ?? this.visitStatus,
      assignmentDate: assignmentDate,
      creditId: creditId,
      daysPastDue: daysPastDue,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      localOrder: localOrder ?? this.localOrder,
      observation: observation ?? this.observation,
      solicitudId: solicitudId ?? this.solicitudId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'cliente_id': clientId,
      'asesor_id': advisorId,
      'cliente_nombre': clientName,
      'documento': documentNumber,
      'tipo_gestion': managementType.code,
      'monto_credito': creditAmount,
      'score_prioridad': priorityScore,
      'estado_visita': visitStatus.code,
      'fecha_asignacion': _dateOnly(assignmentDate),
      'dias_mora': daysPastDue,
      'orden_local': localOrder,
      'observacion_visita': observation,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (solicitudId != null) 'solicitud_id': solicitudId,
    };
  }

  static DailyClient fromJson(Map<String, dynamic> json) {
    final cliente = _nestedMap(json['clientes']);
    final credito = _nestedMap(json['creditos']);
    final score = _intValue(json['score_prioridad']);
    final daysPastDue = credito == null
        ? _intValue(json['dias_mora'])
        : _intValue(credito['dias_mora']);
    final creditAmount = credito == null
        ? _doubleValue(json['monto_credito'] ?? json['monto'])
        : _doubleValue(
            credito['saldo_actual'] ?? credito['monto_desembolsado'],
          );
    final clientName = _clientNameFrom(json, cliente);
    final documentNumber = _documentFrom(json, cliente);
    final clientId = (json['cliente_id'] ?? cliente?['id'] ?? '').toString();
    final lat = _optionalDouble(cliente?['lat'] ?? json['lat']);
    final lng = _optionalDouble(cliente?['lng'] ?? json['lng']);

    return DailyClient(
      id: json['id'].toString(),
      clientId: clientId,
      advisorId: (json['asesor_id'] ?? '').toString(),
      creditId: json['credito_id']?.toString(),
      clientName: clientName,
      documentNumber: documentNumber,
      managementType: ManagementType.fromCode(
        (json['tipo_gestion'] ?? '').toString(),
      ),
      creditAmount: creditAmount,
      priorityScore: score > 0
          ? score
          : priorityScoreFromJson({
              ...json,
              'dias_mora': daysPastDue,
              'monto_credito': creditAmount,
            }),
      visitStatus: VisitStatus.fromCode(json['estado_visita']?.toString()),
      assignmentDate:
          DateTime.tryParse((json['fecha_asignacion'] ?? '').toString()) ??
          DateTime.now(),
      daysPastDue: daysPastDue,
      latitude: lat,
      longitude: lng,
      localOrder: json['orden_manual'] == null
          ? json['orden_local'] == null
                ? null
                : _intValue(json['orden_local'])
          : _intValue(json['orden_manual']),
      observation: json['observacion_visita']?.toString(),
      solicitudId: json['solicitud_id']?.toString(),
    );
  }

  static Map<String, dynamic>? _nestedMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  static String _clientNameFrom(
    Map<String, dynamic> json,
    Map<String, dynamic>? cliente,
  ) {
    if (cliente != null) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      final fullName = '$nombres $apellidos'.trim();
      if (fullName.isNotEmpty) {
        return fullName;
      }
    }
    return (json['cliente_nombre'] ?? json['nombre_cliente'] ?? 'Cliente')
        .toString();
  }

  static String _documentFrom(
    Map<String, dynamic> json,
    Map<String, dynamic>? cliente,
  ) {
    if (cliente != null) {
      final document = (cliente['numero_documento'] ?? '').toString();
      if (document.isNotEmpty) {
        return document;
      }
    }
    return (json['documento'] ?? json['documento_cliente'] ?? '').toString();
  }

  static int priorityScoreFromJson(Map<String, dynamic> json) {
    final type = ManagementType.fromCode(
      (json['tipo_gestion'] ?? '').toString(),
    );
    var score = switch (type) {
      ManagementType.recovery => 40 + _intValue(json['dias_mora']).clamp(0, 30),
      ManagementType.renewal =>
        _doubleValue(json['monto_credito'] ?? json['monto']) > 5000 ? 35 : 20,
      ManagementType.extension => 25,
      ManagementType.followUp => 10,
      ManagementType.newRequest => 5,
      ManagementType.deserter => 15,
    };
    return score.clamp(0, 100);
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _optionalDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
