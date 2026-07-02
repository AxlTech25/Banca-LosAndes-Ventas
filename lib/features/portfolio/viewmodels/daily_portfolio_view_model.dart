import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/daily_portfolio_repository.dart';
import '../models/daily_client.dart';

enum PortfolioFilter {
  all('Todos'),
  renewals('Renovaciones'),
  newRequests('Nuevas'),
  overdue('En mora'),
  visited('Visitados');

  const PortfolioFilter(this.label);

  final String label;
}

class DailyPortfolioViewModel extends ChangeNotifier {
  DailyPortfolioViewModel({required DailyPortfolioRepository repository})
    : _repository = repository;

  final DailyPortfolioRepository _repository;

  final List<DailyClient> _clients = [];
  PortfolioFilter selectedFilter = PortfolioFilter.all;
  String searchQuery = '';
  bool isLoading = false;
  String? errorMessage;
  Timer? _searchDebounce;

  List<DailyClient> get clients => List.unmodifiable(_clients);

  DailyClient? findByClientId(String clientId) {
    for (final client in _clients) {
      if (client.clientId == clientId) {
        return client;
      }
    }
    return null;
  }

  DateTime? get lastSyncAt => _repository.lastSyncAt;

  List<DailyClient> get filteredClients {
    final query = searchQuery.trim().toLowerCase();
    final filtered = _clients.where((client) {
      final matchesFilter = switch (selectedFilter) {
        PortfolioFilter.all => true,
        PortfolioFilter.renewals =>
          client.managementType == ManagementType.renewal,
        PortfolioFilter.newRequests =>
          client.managementType == ManagementType.newRequest,
        PortfolioFilter.overdue =>
          client.managementType == ManagementType.recovery,
        PortfolioFilter.visited => client.isVisited,
      };

      if (!matchesFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return client.clientName.toLowerCase().contains(query) ||
          client.maskedDocument.toLowerCase().contains(query) ||
          client.documentNumber.endsWith(query);
    }).toList();

    filtered.sort((a, b) {
      if (a.isVisited != b.isVisited) {
        return a.isVisited ? 1 : -1;
      }
      return 0;
    });
    return filtered;
  }

  int get totalCount => filteredClients.length;

  int get visitedCount {
    return filteredClients.where((client) => client.isVisited).length;
  }

  int get pendingCount => totalCount - visitedCount;

  double get progress {
    if (totalCount == 0) {
      return 0;
    }
    return visitedCount / totalCount;
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final cached = await _repository.loadCachedPortfolio();
      _clients
        ..clear()
        ..addAll(cached);
      notifyListeners();

      final refreshed = await _repository.refreshTodayPortfolio();
      _clients
        ..clear()
        ..addAll(refreshed);
      await _repository.syncPendingVisits();
    } catch (error) {
      if (_clients.isEmpty) {
        errorMessage = 'No se pudo actualizar la cartera. Sin cache local.';
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final refreshed = await _repository.refreshTodayPortfolio();
      _clients
        ..clear()
        ..addAll(refreshed);
      await _repository.syncPendingVisits();
    } catch (_) {
      errorMessage = 'No se pudo actualizar. Se mantiene la cache local.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterCaseAssignment() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final refreshed = await _repository.refreshAfterCaseAssignment();
      _clients
        ..clear()
        ..addAll(refreshed);
      await _repository.syncPendingVisits();
    } catch (_) {
      errorMessage = 'No se pudo actualizar la cartera tras tomar el caso.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectFilter(PortfolioFilter filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  void updateSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      searchQuery = value;
      notifyListeners();
    });
  }

  Future<void> reorderFiltered(int oldIndex, int newIndex) async {
    final visible = filteredClients;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);

    final visibleIds = visible.map((client) => client.id).toList();
    _clients.sort((a, b) {
      final aIndex = visibleIds.indexOf(a.id);
      final bIndex = visibleIds.indexOf(b.id);
      if (aIndex >= 0 && bIndex >= 0) {
        return aIndex.compareTo(bIndex);
      }
      if (aIndex >= 0) {
        return -1;
      }
      if (bIndex >= 0) {
        return 1;
      }
      return 0;
    });
    await _repository.saveManualOrder(_clients);
    notifyListeners();
  }

  Future<bool> isInsideWorkZone() => _repository.isInsideWorkZone();

  Future<void> saveVisitResult({
    required DailyClient client,
    required VisitStatus status,
    required String observation,
  }) async {
    await _repository.saveVisitResult(
      client: client,
      status: status,
      observation: observation,
    );

    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index >= 0) {
      _clients[index] = _clients[index].copyWith(
        visitStatus: status,
        observation: observation,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
