import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/client_directory_entry.dart';

class ClientsDirectoryRepository {
  ClientsDirectoryRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
  }) : _client = client,
       _advisorId = advisorId;

  final supabase.SupabaseClient _client;
  final String _advisorId;

  Future<List<ClientDirectoryEntry>> fetchDirectory() async {
    final byId = <String, _MutableEntry>{};

    await _mergeClients(
      byId,
      await _client
          .from('cartera_diaria')
          .select('cliente_id, clientes ( id, nombres, apellidos, numero_documento, telefono, nombre_negocio, tipo_negocio )')
          .eq('asesor_id', _advisorId),
      ClientDirectorySource.portfolio,
    );

    await _mergeClients(
      byId,
      await _client
          .from('solicitudes_credito')
          .select('cliente_id, clientes ( id, nombres, apellidos, numero_documento, telefono, nombre_negocio, tipo_negocio )')
          .eq('asesor_id', _advisorId),
      ClientDirectorySource.request,
    );

    await _mergeClients(
      byId,
      await _client
          .from('cartera_vencida')
          .select('cliente_id, clientes ( id, nombres, apellidos, numero_documento, telefono, nombre_negocio, tipo_negocio )')
          .eq('asesor_id', _advisorId),
      ClientDirectorySource.overdue,
    );

    final entries = byId.values
        .map((entry) => entry.toModel())
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    return entries;
  }

  Future<void> _mergeClients(
    Map<String, _MutableEntry> byId,
    List<dynamic> rows,
    ClientDirectorySource source,
  ) async {
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final cliente = _nestedMap(row['clientes']);
      if (cliente == null) {
        continue;
      }

      final clientId = (cliente['id'] ?? row['cliente_id'] ?? '').toString();
      if (clientId.isEmpty) {
        continue;
      }

      final existing = byId[clientId];
      if (existing != null) {
        existing.sources.add(source);
        continue;
      }

      byId[clientId] = _MutableEntry(
        clientId: clientId,
        nombres: (cliente['nombres'] ?? '').toString(),
        apellidos: (cliente['apellidos'] ?? '').toString(),
        documentNumber: (cliente['numero_documento'] ?? '').toString(),
        phone: (cliente['telefono'] ?? '').toString(),
        businessName: (cliente['nombre_negocio'] ?? '').toString(),
        businessType: (cliente['tipo_negocio'] ?? '').toString(),
        sources: {source},
      );
    }
  }

  Map<String, dynamic>? _nestedMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }
}

class _MutableEntry {
  _MutableEntry({
    required this.clientId,
    required this.nombres,
    required this.apellidos,
    required this.documentNumber,
    required this.phone,
    required this.businessName,
    required this.businessType,
    required this.sources,
  });

  final String clientId;
  final String nombres;
  final String apellidos;
  final String documentNumber;
  final String phone;
  final String businessName;
  final String businessType;
  final Set<ClientDirectorySource> sources;

  ClientDirectoryEntry toModel() {
    return ClientDirectoryEntry(
      clientId: clientId,
      fullName: '$nombres $apellidos'.trim(),
      documentNumber: documentNumber,
      phone: phone,
      businessName: businessName,
      businessType: businessType,
      sources: Set.unmodifiable(sources),
    );
  }
}
