import 'package:flutter/foundation.dart';

import '../../auth/models/user_role.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_summary.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required DashboardRepository repository,
    required UserRole role,
  }) : _repository = repository,
       _role = role;

  final DashboardRepository _repository;
  final UserRole _role;

  DashboardSummary? summary;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      summary = await _repository.fetchSummary(
        includeAgencyApproval: _role.canApproveClientAppRequests,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
