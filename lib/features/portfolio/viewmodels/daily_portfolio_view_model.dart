import 'package:flutter/foundation.dart';

import '../models/daily_client.dart';

class DailyPortfolioViewModel extends ChangeNotifier {
  final List<DailyClient> clients = const [
    DailyClient(
      name: 'Ricardo Alva',
      type: DailyClientType.renewal,
      status: DailyClientStatus.pending,
    ),
    DailyClient(
      name: 'Luc\u00EDa M\u00E9ndez',
      type: DailyClientType.newClient,
      status: DailyClientStatus.visited,
    ),
    DailyClient(
      name: 'Jorge Castillo',
      type: DailyClientType.collection,
      status: DailyClientStatus.pending,
    ),
    DailyClient(
      name: 'Martha Ruiz',
      type: DailyClientType.renewal,
      status: DailyClientStatus.pending,
    ),
    DailyClient(
      name: 'Carlos Tenorio',
      type: DailyClientType.collection,
      status: DailyClientStatus.visited,
    ),
  ];

  int get totalVisits => clients.length;

  int get visitedCount {
    return clients
        .where((client) => client.status == DailyClientStatus.visited)
        .length;
  }
}
