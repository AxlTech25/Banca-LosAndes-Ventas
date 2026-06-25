import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'portfolio_nightly_sync_task.dart';

class PortfolioNightlySyncService {
  PortfolioNightlySyncService._();

  static const advisorIdKey = 'nightly_sync_advisor_id';

  static Future<void> initialize() async {
    await Workmanager().initialize(portfolioNightlySyncDispatcher);
  }

  static Future<void> registerForAdvisor(String advisorId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(advisorIdKey, advisorId);
    await scheduleNextRun();
  }

  static const _retryNames = [
    'portfolio-nightly-sync-0',
    'portfolio-nightly-sync-1',
    'portfolio-nightly-sync-2',
  ];

  static Future<void> cancel() async {
    for (final name in _retryNames) {
      await Workmanager().cancelByUniqueName(name);
    }
    await Workmanager().cancelByUniqueName('portfolio-nightly-sync');
  }

  static Future<void> scheduleNextRun() async {
    final now = DateTime.now();
    final slots = [
      DateTime(now.year, now.month, now.day, 22),
      DateTime(now.year, now.month, now.day, 22, 30),
      DateTime(now.year, now.month, now.day, 23),
    ];

    for (var i = 0; i < slots.length; i++) {
      var target = slots[i];
      if (!target.isAfter(now)) {
        target = target.add(const Duration(days: 1));
      }
      await Workmanager().registerOneOffTask(
        _retryNames[i],
        portfolioNightlySyncTaskName,
        initialDelay: target.difference(now),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }
}
