import 'package:flutter/material.dart';

import '../../portfolio/models/daily_client.dart';

enum OverdueUrgency {
  preventive('Seguimiento preventivo', 0xFFFFC857),
  priority('Gestion prioritaria', 0xFFFF8C42),
  urgent('Recuperacion urgente', 0xFFFF4D4D);

  const OverdueUrgency(this.label, this.colorValue);

  final String label;
  final int colorValue;

  static OverdueUrgency fromDays(int daysPastDue) {
    if (daysPastDue > 60) {
      return OverdueUrgency.urgent;
    }
    if (daysPastDue > 30) {
      return OverdueUrgency.priority;
    }
    return OverdueUrgency.preventive;
  }

  Color get color => Color(colorValue);
}

enum CollectionManagementType {
  visit('visita', 'Visita en campo'),
  call('llamada', 'Llamada telefonica'),
  message('mensaje', 'Mensaje / WhatsApp');

  const CollectionManagementType(this.code, this.label);

  final String code;
  final String label;

  static CollectionManagementType fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return CollectionManagementType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => CollectionManagementType.visit,
    );
  }
}

enum CollectionResultType {
  fullPayment('pago_total', 'Pago total'),
  partialPayment('pago_parcial', 'Pago parcial'),
  paymentCommitment('compromiso_pago', 'Compromiso de pago'),
  noContact('no_contacto', 'No contactado'),
  refusal('rechazo_pago', 'Rechazo de pago'),
  renegotiation('renegociacion', 'Renegociacion');

  const CollectionResultType(this.code, this.label);

  final String code;
  final String label;

  static CollectionResultType fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return CollectionResultType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => CollectionResultType.noContact,
    );
  }

  bool get requiresPaymentAmount =>
      this == CollectionResultType.fullPayment ||
      this == CollectionResultType.partialPayment;

  bool get requiresCommitment =>
      this == CollectionResultType.paymentCommitment;
}

class OverdueClientEntry {
  const OverdueClientEntry({
    required this.id,
    required this.clientId,
    required this.creditId,
    required this.clientName,
    required this.documentNumber,
    required this.daysPastDue,
    required this.overdueAmount,
    this.lastContactDate,
    this.portfolioEntryId,
  });

  final String id;
  final String clientId;
  final String creditId;
  final String clientName;
  final String documentNumber;
  final int daysPastDue;
  final double overdueAmount;
  final DateTime? lastContactDate;
  final String? portfolioEntryId;

  factory OverdueClientEntry.fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'];
    var clientName = 'Cliente';
    var documentNumber = '';
    if (cliente is Map) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      clientName = '$nombres $apellidos'.trim();
      documentNumber = (cliente['numero_documento'] ?? '').toString();
    }

    final credito = json['creditos'];
    var daysPastDue = _intValue(json['dias_mora']) ?? 0;
    if (credito is Map) {
      daysPastDue = _intValue(credito['dias_mora']) ?? daysPastDue;
    }

    return OverdueClientEntry(
      id: json['id'].toString(),
      clientId: json['cliente_id'].toString(),
      creditId: json['credito_id'].toString(),
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      documentNumber: documentNumber,
      daysPastDue: daysPastDue,
      overdueAmount: _doubleValue(json['monto_vencido']),
      lastContactDate: DateTime.tryParse(
        (json['fecha_ultimo_contacto'] ?? '').toString(),
      ),
      portfolioEntryId: json['portfolio_entry_id']?.toString(),
    );
  }

  factory OverdueClientEntry.fromDailyClient(DailyClient client) {
    return OverdueClientEntry(
      id: client.clientId,
      clientId: client.clientId,
      creditId: client.creditId ?? '',
      clientName: client.clientName,
      documentNumber: client.documentNumber,
      daysPastDue: client.daysPastDue,
      overdueAmount: client.creditAmount,
      portfolioEntryId: client.id,
    );
  }

  OverdueUrgency get urgency => OverdueUrgency.fromDays(daysPastDue);
}

class CollectionActionRecord {
  const CollectionActionRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.managementType,
    required this.result,
    required this.registeredAt,
    this.amountPaid,
    this.commitmentDate,
    this.commitmentAmount,
    this.observations,
  });

  final String id;
  final String clientId;
  final String clientName;
  final CollectionManagementType managementType;
  final CollectionResultType result;
  final DateTime registeredAt;
  final double? amountPaid;
  final DateTime? commitmentDate;
  final double? commitmentAmount;
  final String? observations;

  factory CollectionActionRecord.fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'];
    var clientName = 'Cliente';
    if (cliente is Map) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      clientName = '$nombres $apellidos'.trim();
    }

    return CollectionActionRecord(
      id: json['id'].toString(),
      clientId: json['cliente_id'].toString(),
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      managementType: CollectionManagementType.fromCode(
        json['tipo_gestion']?.toString(),
      ),
      result: CollectionResultType.fromCode(json['resultado']?.toString()),
      registeredAt:
          DateTime.tryParse(json['timestamp_gestion']?.toString() ?? '') ??
          DateTime.now(),
      amountPaid: _doubleOrNull(json['monto_pagado']),
      commitmentDate: DateTime.tryParse(
        (json['fecha_compromiso'] ?? '').toString(),
      ),
      commitmentAmount: _doubleOrNull(json['monto_compromiso']),
      observations: json['observaciones']?.toString(),
    );
  }
}

class CollectionActionFormData {
  const CollectionActionFormData({
    required this.managementType,
    required this.result,
    required this.observations,
    this.amountPaid,
    this.commitmentDate,
    this.commitmentAmount,
  });

  final CollectionManagementType managementType;
  final CollectionResultType result;
  final String observations;
  final double? amountPaid;
  final DateTime? commitmentDate;
  final double? commitmentAmount;

  String? validate() {
    if (result.requiresPaymentAmount &&
        (amountPaid == null || amountPaid! <= 0)) {
      return 'Indica el monto pagado.';
    }
    if (result.requiresCommitment) {
      if (commitmentDate == null) {
        return 'Indica la fecha del compromiso.';
      }
      if (commitmentAmount == null || commitmentAmount! <= 0) {
        return 'Indica el monto del compromiso.';
      }
    }
    if (observations.trim().isEmpty) {
      return 'Agrega una observacion de la gestion.';
    }
    return null;
  }

  Map<String, dynamic> toPayload({
    required String advisorId,
    required String clientId,
    required String creditId,
    double? latitude,
    double? longitude,
  }) {
    return {
      'asesor_id': advisorId,
      'cliente_id': clientId,
      'credito_id': creditId,
      'tipo_gestion': managementType.code,
      'resultado': result.code,
      if (amountPaid != null) 'monto_pagado': amountPaid,
      if (commitmentDate != null)
        'fecha_compromiso': _dateOnly(commitmentDate!),
      if (commitmentAmount != null) 'monto_compromiso': commitmentAmount,
      'observaciones': observations.trim(),
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      'timestamp_gestion': DateTime.now().toIso8601String(),
    };
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class CollectionBoardSummary {
  const CollectionBoardSummary({
    required this.overdueClients,
    required this.totalOverdueAmount,
    required this.actionsToday,
  });

  final int overdueClients;
  final double totalOverdueAmount;
  final int actionsToday;
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
