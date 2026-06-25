class BlacklistEntry {
  const BlacklistEntry({
    required this.documentNumber,
    required this.reason,
    required this.source,
  });

  final String documentNumber;
  final String reason;
  final String source;

  factory BlacklistEntry.fromJson(Map<String, dynamic> json) {
    return BlacklistEntry(
      documentNumber: (json['numero_documento'] ?? '').toString(),
      reason: (json['motivo'] ?? 'Restriccion activa').toString(),
      source: (json['fuente'] ?? 'interna').toString(),
    );
  }
}
