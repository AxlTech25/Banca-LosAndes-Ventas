enum PortfolioAlertType {
  firstOverdueDay('primer_dia_mora', 'Primer dia de mora'),
  overdue30('mora_30d', 'Mora mayor a 30 dias'),
  overdue60('mora_60d', 'Mora mayor a 60 dias'),
  partialPayment('pago_parcial', 'Pago parcial'),
  fullPayment('pago_total', 'Pago total');

  const PortfolioAlertType(this.code, this.label);

  final String code;
  final String label;

  static PortfolioAlertType fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return PortfolioAlertType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => PortfolioAlertType.firstOverdueDay,
    );
  }
}

class PortfolioAlert {
  const PortfolioAlert({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final PortfolioAlertType type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  PortfolioAlert copyWith({bool? isRead}) {
    return PortfolioAlert(
      id: id,
      clientId: clientId,
      clientName: clientName,
      type: type,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  static PortfolioAlert fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'];
    String clientName = 'Cliente';
    if (cliente is Map) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      clientName = '$nombres $apellidos'.trim();
    }

    return PortfolioAlert(
      id: json['id'].toString(),
      clientId: json['cliente_id'].toString(),
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      type: PortfolioAlertType.fromCode(json['tipo_alerta']?.toString()),
      message: (json['mensaje'] ?? '').toString(),
      isRead: json['leida'] == true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
