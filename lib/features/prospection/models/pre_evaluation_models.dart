enum PreEvaluationStatus {
  apto('APTO', 'Puede continuar la evaluacion'),
  revisar('REVISAR', 'Requiere analisis adicional'),
  noProcede('NO PROCEDE', 'No cumple condiciones'),
  pending('PENDIENTE', 'Pendiente de procesar');

  const PreEvaluationStatus(this.code, this.label);

  final String code;
  final String label;

  static PreEvaluationStatus fromCode(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    return switch (normalized) {
      'APTO' => PreEvaluationStatus.apto,
      'REVISAR' => PreEvaluationStatus.revisar,
      'NO PROCEDE' || 'NO_PROCEDE' => PreEvaluationStatus.noProcede,
      _ => PreEvaluationStatus.revisar,
    };
  }
}

class ProspectFormData {
  const ProspectFormData({
    required this.documentNumber,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.businessType,
    required this.businessAgeYears,
    required this.businessAgeMonths,
    required this.estimatedIncome,
    required this.requestedAmount,
    required this.creditPurpose,
  });

  final String documentNumber;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String businessType;
  final int businessAgeYears;
  final int businessAgeMonths;
  final double estimatedIncome;
  final double requestedAmount;
  final String creditPurpose;

  int get businessAgeTotalMonths =>
      (businessAgeYears * 12) + businessAgeMonths;

  Map<String, dynamic> toJson() {
    return {
      'documento': documentNumber,
      'nombres': firstName,
      'apellidos': lastName,
      'fecha_nacimiento': _dateOnly(birthDate),
      'tipo_negocio': businessType,
      'antiguedad_anos': businessAgeYears,
      'antiguedad_meses': businessAgeMonths,
      'ingresos_estimados': estimatedIncome,
      'monto_solicitado': requestedAmount,
      'destino_credito': creditPurpose,
    };
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class PreEvaluationResult {
  const PreEvaluationResult({
    required this.status,
    required this.reason,
    this.estimatedScore,
    this.pendingSync = false,
  });

  final PreEvaluationStatus status;
  final String reason;
  final int? estimatedScore;
  final bool pendingSync;

  factory PreEvaluationResult.fromJson(Map<String, dynamic> json) {
    return PreEvaluationResult(
      status: PreEvaluationStatus.fromCode(json['calificacion']?.toString()),
      reason: (json['motivo'] ?? json['reason'] ?? '').toString(),
      estimatedScore: _intValue(json['puntaje_estimado'] ?? json['score']),
    );
  }

  static int? _intValue(Object? value) {
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
}

enum CampaignType {
  renewal('RENOVACION', 'Renovacion', 0xFF00A8FF),
  extension('AMPLIACION', 'Ampliacion', 0xFF27C46B),
  parallel('PRODUCTO_PARALELO', 'Producto paralelo', 0xFFFF9F1C);

  const CampaignType(this.code, this.label, this.colorValue);

  final String code;
  final String label;
  final int colorValue;

  static CampaignType fromCode(String? value) {
    final normalized = (value ?? '').trim().toUpperCase().replaceAll(' ', '_');
    return CampaignType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => CampaignType.renewal,
    );
  }
}

class ActiveCampaign {
  const ActiveCampaign({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.type,
    required this.offeredAmount,
    required this.expirationDate,
    required this.isActive,
  });

  final String id;
  final String clientId;
  final String clientName;
  final CampaignType type;
  final double offeredAmount;
  final DateTime expirationDate;
  final bool isActive;

  int get daysRemaining {
    final today = DateTime.now();
    final end = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    final start = DateTime(today.year, today.month, today.day);
    return end.difference(start).inDays;
  }

  bool get isExpired => daysRemaining < 0;

  static ActiveCampaign fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'];
    var clientName = 'Cliente';
    if (cliente is Map) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      clientName = '$nombres $apellidos'.trim();
    }

    return ActiveCampaign(
      id: json['id'].toString(),
      clientId: json['cliente_id'].toString(),
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      type: CampaignType.fromCode(json['tipo_campana']?.toString()),
      offeredAmount: _doubleValue(json['monto_ofertado']),
      expirationDate:
          DateTime.tryParse((json['fecha_vencimiento'] ?? '').toString()) ??
          DateTime.now(),
      isActive: json['activa'] != false,
    );
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class DeserterFormData {
  const DeserterFormData({
    required this.reason,
    required this.migratedInstitution,
    required this.returnProbability,
    required this.observations,
  });

  final String reason;
  final String migratedInstitution;
  final String returnProbability;
  final String observations;

  Map<String, dynamic> toJson() {
    return {
      'motivo_desercion': reason,
      'institucion_migracion': migratedInstitution,
      'probabilidad_retorno': returnProbability,
      'observaciones': observations,
    };
  }
}
