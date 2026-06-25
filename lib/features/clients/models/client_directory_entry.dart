enum ClientDirectorySource {
  portfolio('Cartera'),
  request('Solicitud'),
  overdue('Mora');

  const ClientDirectorySource(this.label);

  final String label;
}

class ClientDirectoryEntry {
  const ClientDirectoryEntry({
    required this.clientId,
    required this.fullName,
    required this.documentNumber,
    required this.phone,
    required this.businessName,
    required this.businessType,
    required this.sources,
  });

  final String clientId;
  final String fullName;
  final String documentNumber;
  final String phone;
  final String businessName;
  final String businessType;
  final Set<ClientDirectorySource> sources;

  String get maskedDocument {
    final digits = documentNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) {
      return '***$digits';
    }
    return '***${digits.substring(digits.length - 4)}';
  }
}
