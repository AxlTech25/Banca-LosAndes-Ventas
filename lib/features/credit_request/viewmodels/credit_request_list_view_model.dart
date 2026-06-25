import 'package:flutter/foundation.dart';

import '../data/credit_request_repository.dart';
import '../models/credit_request_models.dart';

class CreditRequestListViewModel extends ChangeNotifier {
  CreditRequestListViewModel({required CreditRequestRepository repository})
    : _repository = repository;

  final CreditRequestRepository _repository;

  final List<CreditRequestDraft> _drafts = [];
  bool isLoading = false;
  int localPendingCount = 0;
  String? errorMessage;

  List<CreditRequestDraft> get drafts => List.unmodifiable(_drafts);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.loadDrafts();
      _drafts
        ..clear()
        ..addAll(fetched);
      localPendingCount = await _repository.countLocalPendingSync();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDraft(String localId) async {
    await _repository.deleteDraft(localId);
    await load();
  }
}
