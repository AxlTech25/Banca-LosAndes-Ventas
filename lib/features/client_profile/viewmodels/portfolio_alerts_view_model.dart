import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../notifications/data/advisor_notifications_repository.dart';
import '../../notifications/models/advisor_inbox_item.dart';
import '../../notifications/models/advisor_notification_models.dart';
import '../data/portfolio_alerts_repository.dart';
import '../models/portfolio_alert.dart';

class PortfolioAlertsViewModel extends ChangeNotifier {
  PortfolioAlertsViewModel({
    required PortfolioAlertsRepository repository,
    AdvisorNotificationsRepository? appNotificationsRepository,
  }) : _repository = repository,
       _appNotificationsRepository = appNotificationsRepository;

  final PortfolioAlertsRepository _repository;
  final AdvisorNotificationsRepository? _appNotificationsRepository;

  final List<PortfolioAlert> _alerts = [];
  final List<AdvisorNotification> _appNotifications = [];
  supabase.RealtimeChannel? _channel;
  supabase.RealtimeChannel? _appChannel;
  bool isLoading = false;

  List<PortfolioAlert> get alerts => List.unmodifiable(_alerts);

  List<PortfolioAlert> get unreadAlerts =>
      _alerts.where((alert) => !alert.isRead).toList();

  List<AdvisorInboxItem> get inboxItems {
    final items = <AdvisorInboxItem>[
      ..._alerts.map(AdvisorInboxItem.portfolio),
      ..._appNotifications.map(AdvisorInboxItem.appCliente),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(items);
  }

  int get unreadCount =>
      _alerts.where((alert) => !alert.isRead).length +
      _appNotifications.where((notification) => !notification.isRead).length;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      final appRepo = _appNotificationsRepository;
      if (appRepo != null) {
        final results = await Future.wait([
          _repository.fetchAlerts(),
          appRepo.fetchNotifications(),
        ]);
        _alerts
          ..clear()
          ..addAll(results[0] as List<PortfolioAlert>);
        _appNotifications
          ..clear()
          ..addAll(results[1] as List<AdvisorNotification>);
      } else {
        final fetched = await _repository.fetchAlerts();
        _alerts
          ..clear()
          ..addAll(fetched);
        _appNotifications.clear();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void startRealtime() {
    _channel?.unsubscribe();
    _channel = _repository.subscribeToInserts(() {
      load();
    });

    final appRepo = _appNotificationsRepository;
    if (appRepo != null) {
      _appChannel?.unsubscribe();
      _appChannel = appRepo.subscribeToChanges(() {
        load();
      });
    }
  }

  Future<void> markAsRead(PortfolioAlert alert) async {
    if (alert.isRead) {
      return;
    }

    final index = _alerts.indexWhere((item) => item.id == alert.id);
    if (index >= 0) {
      _alerts[index] = alert.copyWith(isRead: true);
      notifyListeners();
    }

    try {
      await _repository.markAsRead(alert.id);
    } catch (_) {
      if (index >= 0) {
        _alerts[index] = alert;
        notifyListeners();
      }
    }
  }

  Future<void> markAppNotificationAsRead(
    AdvisorNotification notification,
  ) async {
    if (notification.isRead) {
      return;
    }

    final index = _appNotifications.indexWhere(
      (item) => item.id == notification.id,
    );
    if (index >= 0) {
      _appNotifications[index] = notification.copyWith(isRead: true);
      notifyListeners();
    }

    try {
      await _appNotificationsRepository?.markAsRead(notification);
    } catch (_) {
      if (index >= 0) {
        _appNotifications[index] = notification;
        notifyListeners();
      }
    }
  }

  Future<void> markInboxItemAsRead(AdvisorInboxItem item) async {
    switch (item.source) {
      case AdvisorInboxSource.portfolio:
        await markAsRead(item.alert!);
      case AdvisorInboxSource.appCliente:
        await markAppNotificationAsRead(item.notification!);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _appChannel?.unsubscribe();
    super.dispose();
  }
}
