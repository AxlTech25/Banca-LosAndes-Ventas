import 'package:flutter/foundation.dart';

import '../../auth/models/user_role.dart';
import '../../credit_request/data/credit_pipeline_repository.dart';
import '../../credit_request/models/pipeline_models.dart';

class FieldCommitteeViewModel extends ChangeNotifier {
  FieldCommitteeViewModel({
    required CreditPipelineRepository repository,
    required UserRole role,
  }) : _repository = repository,
       _role = role;

  final CreditPipelineRepository _repository;
  final UserRole _role;

  final List<SubmittedCreditRequest> _requests = [];
  String searchQuery = '';
  bool isLoading = false;
  String? errorMessage;

  List<SubmittedCreditRequest> get requests => List.unmodifiable(_requests);

  bool get isAgencyWide =>
      _role == UserRole.supervisor || _role == UserRole.administrator;

  List<SubmittedCreditRequest> get filteredRequests {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return requests;
    }

    return requests.where((request) {
      return request.clientName.toLowerCase().contains(query) ||
          request.expedienteNumber.toLowerCase().contains(query) ||
          request.documentNumber.endsWith(query) ||
          (request.advisorName ?? '').toLowerCase().contains(query) ||
          (request.assignedAnalyst ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchCommitteeQueue(
        agencyWide: isAgencyWide,
      );
      _requests
        ..clear()
        ..addAll(fetched);
    } catch (_) {
      errorMessage = 'No se pudo cargar la cola del comite.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }
}
