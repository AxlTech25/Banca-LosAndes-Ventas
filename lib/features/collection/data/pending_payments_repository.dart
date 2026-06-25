import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/pending_payment_models.dart';

class PendingPaymentsRepository {
  PendingPaymentsRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
  }) : _client = client,
       _advisorId = advisorId;

  final supabase.SupabaseClient _client;
  final String _advisorId;

  static const _select = '''
    id,
    cliente_id,
    monto,
    tipo,
    metodo_pago,
    referencia,
    created_at,
    creditos!inner (
      id,
      producto,
      saldo_actual,
      asesor_id
    ),
    clientes (
      nombres,
      apellidos,
      numero_documento
    )
  ''';

  Future<List<PendingClientPayment>> fetchPendingPayments() async {
    final rows = await _client
        .from('pagos_credito')
        .select(_select)
        .eq('estado', 'pendiente')
        .inFilter('metodo_pago', ['yape', 'transferencia', 'agente'])
        .eq('creditos.asesor_id', _advisorId)
        .order('created_at', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PendingClientPayment.fromJson)
        .toList();
  }

  Future<int> countPendingPayments() async {
    final rows = await _client
        .from('pagos_credito')
        .select('id, creditos!inner(asesor_id)')
        .eq('estado', 'pendiente')
        .inFilter('metodo_pago', ['yape', 'transferencia', 'agente'])
        .eq('creditos.asesor_id', _advisorId);

    return (rows as List).length;
  }

  Future<void> confirmPayment(String pagoId) async {
    await _client.rpc(
      'asesor_confirmar_pago_credito',
      params: {'p_pago_id': pagoId},
    );
  }

  Future<void> rejectPayment({
    required String pagoId,
    String? motivo,
  }) async {
    await _client.rpc(
      'asesor_rechazar_pago_credito',
      params: {
        'p_pago_id': pagoId,
        'p_motivo': motivo,
      },
    );
  }
}
