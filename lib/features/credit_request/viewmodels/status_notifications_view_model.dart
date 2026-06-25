import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/credit_pipeline_repository.dart';
import '../data/status_notification_repository.dart';
import '../models/pipeline_models.dart';

class StatusNotificationsViewModel extends ChangeNotifier {
  StatusNotificationsViewModel({
    required StatusNotificationRepository repository,
  }) : _repository = repository;

  final StatusNotificationRepository _repository;

  List<StatusChangeNotification> _notifications = [];

  List<StatusChangeNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((item) => !item.read).length;

  void load() {
    _notifications = _repository.loadAll();
    notifyListeners();
  }

  Future<void> markRead(String notificationId) async {
    await _repository.markRead(notificationId);
    load();
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    load();
  }

  Future<void> captureChanges({
    required List<SubmittedCreditRequest> previous,
    required List<SubmittedCreditRequest> current,
  }) async {
    await _repository.recordStatusChanges(
      previous: previous,
      current: current,
    );
    load();
  }
}

class RequestStatusBoardViewModel extends ChangeNotifier {
  RequestStatusBoardViewModel({
    required CreditPipelineRepository repository,
    StatusNotificationsViewModel? notificationsViewModel,
  }) : _repository = repository,
       _notificationsViewModel = notificationsViewModel;

  final CreditPipelineRepository _repository;
  final StatusNotificationsViewModel? _notificationsViewModel;

  final List<SubmittedCreditRequest> _requests = [];
  RequestStatusTab selectedTab = RequestStatusTab.enComite;
  RequestDateRangeFilter dateFilter = RequestDateRangeFilter.all;
  double? minAmount;
  double? maxAmount;
  bool isLoading = false;
  bool isOfflineData = false;
  String? errorMessage;
  RealtimeChannel? _channel;

  List<SubmittedCreditRequest> get requests => List.unmodifiable(_requests);

  RequestStatusSummary get summary =>
      RequestStatusSummary.fromRequests(_requests);

  List<SubmittedCreditRequest> get filteredRequests {
    final startDate = dateFilter.startDate;
    return _requests.where((request) {
      if (!selectedTab.matches(request.status)) {
        return false;
      }
      if (startDate != null && request.createdAt.isBefore(startDate)) {
        return false;
      }
      if (minAmount != null && request.requestedAmount < minAmount!) {
        return false;
      }
      if (maxAmount != null && request.requestedAmount > maxAmount!) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> load() async {
    final previous = List<SubmittedCreditRequest>.from(_requests);
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchTrackedRequests();
      _requests
        ..clear()
        ..addAll(fetched);
      isOfflineData = _repository.lastFetchWasCached;
      await _notificationsViewModel?.captureChanges(
        previous: previous,
        current: fetched,
      );
    } catch (error) {
      errorMessage = error.toString();
      isOfflineData = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setTab(RequestStatusTab tab) {
    selectedTab = tab;
    notifyListeners();
  }

  void setDateFilter(RequestDateRangeFilter filter) {
    dateFilter = filter;
    notifyListeners();
  }

  void setAmountRange({double? min, double? max}) {
    minAmount = min;
    maxAmount = max;
    notifyListeners();
  }

  void startRealtime() {
    _channel?.unsubscribe();
    _channel = _repository.subscribeToStatusChanges(() {
      load();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
