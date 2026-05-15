import 'package:flutter/material.dart';

enum DailyClientType { renewal, newClient, collection }

enum DailyClientStatus { pending, visited }

class DailyClient {
  const DailyClient({
    required this.name,
    required this.type,
    required this.status,
  });

  final String name;
  final DailyClientType type;
  final DailyClientStatus status;

  String get typeLabel {
    return switch (type) {
      DailyClientType.renewal => 'Renovaci\u00F3n',
      DailyClientType.newClient => 'Nuevo',
      DailyClientType.collection => 'Cobranza',
    };
  }

  IconData get typeIcon {
    return switch (type) {
      DailyClientType.renewal => Icons.autorenew,
      DailyClientType.newClient => Icons.person_add_alt_1_outlined,
      DailyClientType.collection => Icons.payments_outlined,
    };
  }

  String get statusLabel {
    return switch (status) {
      DailyClientStatus.pending => 'Pendiente',
      DailyClientStatus.visited => 'Visitado',
    };
  }

  IconData get statusIcon {
    return switch (status) {
      DailyClientStatus.pending => Icons.schedule,
      DailyClientStatus.visited => Icons.check_circle_outline,
    };
  }
}
