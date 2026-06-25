import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../data/daily_portfolio_repository.dart';
import 'portfolio_nightly_sync_service.dart';
import 'portfolio_sync_notification_service.dart';

const portfolioNightlySyncTaskName = 'portfolioNightlySync';

@pragma('vm:entry-point')
void portfolioNightlySyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != portfolioNightlySyncTaskName) {
      return Future.value(true);
    }

    WidgetsFlutterBinding.ensureInitialized();

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    const dartDefineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const dartDefineSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final supabaseUrl = dartDefineSupabaseUrl.isNotEmpty
        ? dartDefineSupabaseUrl
        : dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dartDefineSupabaseAnonKey.isNotEmpty
        ? dartDefineSupabaseAnonKey
        : dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      await PortfolioNightlySyncService.scheduleNextRun();
      return Future.value(true);
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.isExpired) {
      await PortfolioNightlySyncService.scheduleNextRun();
      return Future.value(true);
    }

    final preferences = await SharedPreferences.getInstance();
    final advisorId = preferences.getString(
      PortfolioNightlySyncService.advisorIdKey,
    );
    if (advisorId == null || advisorId.isEmpty) {
      await PortfolioNightlySyncService.scheduleNextRun();
      return Future.value(true);
    }

    final repository = DailyPortfolioRepository(
      client: Supabase.instance.client,
      advisorId: advisorId,
      preferences: preferences,
    );

    final result = await repository.runFullNightlySync();
    if (result.portfolioClientCount > 0) {
      await PortfolioSyncNotificationService.showTomorrowPortfolioReady(
        clientCount: result.portfolioClientCount,
        assignmentDate: result.assignmentDate,
      );
    }

    await PortfolioNightlySyncService.scheduleNextRun();
    return Future.value(true);
  });
}
