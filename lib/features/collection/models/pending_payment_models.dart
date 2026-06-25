class PendingClientPayment {
  const PendingClientPayment({
    required this.id,
    required this.creditoId,
    required this.clienteId,
    required this.clientName,
    required this.documentNumber,
    required this.monto,
    required this.tipo,
    required this.metodoPago,
    required this.referencia,
    required this.createdAt,
    this.producto,
    this.saldoCredito,
  });

  factory PendingClientPayment.fromJson(Map<String, dynamic> json) {
    final credito = json['creditos'];
    final cliente = json['clientes'];

    var clientName = 'Cliente';
    var documentNumber = '';
    if (cliente is Map) {
      final nombres = (cliente['nombres'] ?? '').toString().trim();
      final apellidos = (cliente['apellidos'] ?? '').toString().trim();
      clientName = '$nombres $apellidos'.trim();
      documentNumber = (cliente['numero_documento'] ?? '').toString();
    }

    var creditoId = '';
    String? producto;
    double? saldoCredito;
    if (credito is Map) {
      creditoId = credito['id'].toString();
      producto = credito['producto']?.toString();
      final saldo = credito['saldo_actual'];
      if (saldo is num) {
        saldoCredito = saldo.toDouble();
      } else {
        saldoCredito = double.tryParse(saldo?.toString() ?? '');
      }
    }

    return PendingClientPayment(
      id: json['id'].toString(),
      creditoId: creditoId,
      clienteId: json['cliente_id']?.toString() ?? '',
      clientName: clientName.isEmpty ? 'Cliente' : clientName,
      documentNumber: documentNumber,
      monto: _asDouble(json['monto']),
      tipo: (json['tipo'] ?? 'cuota').toString(),
      metodoPago: (json['metodo_pago'] ?? '').toString(),
      referencia: (json['referencia'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      producto: producto,
      saldoCredito: saldoCredito,
    );
  }

  final String id;
  final String creditoId;
  final String clienteId;
  final String clientName;
  final String documentNumber;
  final double monto;
  final String tipo;
  final String metodoPago;
  final String referencia;
  final DateTime createdAt;
  final String? producto;
  final double? saldoCredito;

  String get metodoLabel => switch (metodoPago) {
    'yape' => 'Yape',
    'transferencia' => 'Transferencia',
    'agente' => 'Agente / ventanilla',
    _ => metodoPago,
  };

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
