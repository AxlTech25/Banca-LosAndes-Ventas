import 'package:flutter/foundation.dart';

import '../../portfolio/models/daily_client.dart';
import '../data/collection_repository.dart';
import '../models/collection_models.dart';

class CollectionBoardViewModel extends ChangeNotifier {
  CollectionBoardViewModel({
    required CollectionRepository repository,
    this.portfolioClients = const [],
  }) : _repository = repository;

  final CollectionRepository _repository;
  final List<DailyClient> portfolioClients;

  final List<OverdueClientEntry> _overdueClients = [];
  final List<CollectionActionRecord> _recentActions = [];
  CollectionBoardSummary? summary;
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  List<OverdueClientEntry> get overdueClients => List.unmodifiable(_overdueClients);
  List<CollectionActionRecord> get recentActions =>
      List.unmodifiable(_recentActions);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final overdue = await _repository.fetchOverduePortfolio(
        portfolioFallback: portfolioClients,
      );
      final actions = await _repository.fetchRecentActions();
      _overdueClients
        ..clear()
        ..addAll(overdue);
      _recentActions
        ..clear()
        ..addAll(actions);
      summary = await _repository.fetchSummary(
        overdueClients: overdue,
        recentActions: actions,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerAction({
    required OverdueClientEntry client,
    required CollectionActionFormData form,
  }) async {
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.registerAction(
        client: client,
        form: form,
        portfolioEntryId: client.portfolioEntryId,
      );
      await load();
      successMessage = 'Gestion de cobranza registrada.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      notifyListeners();
    }
  }
}

class CollectionActionViewModel extends ChangeNotifier {
  CollectionManagementType managementType = CollectionManagementType.visit;
  CollectionResultType result = CollectionResultType.paymentCommitment;
  double amountPaid = 0;
  double commitmentAmount = 0;
  DateTime? commitmentDate;
  String observations = '';
  bool isSubmitting = false;
  String? validationError;

  void setManagementType(CollectionManagementType value) {
    managementType = value;
    notifyListeners();
  }

  void setResult(CollectionResultType value) {
    result = value;
    notifyListeners();
  }

  void setAmountPaid(double value) {
    amountPaid = value;
    notifyListeners();
  }

  void setCommitmentAmount(double value) {
    commitmentAmount = value;
    notifyListeners();
  }

  void setCommitmentDate(DateTime? value) {
    commitmentDate = value;
    notifyListeners();
  }

  void setObservations(String value) {
    observations = value;
    notifyListeners();
  }

  CollectionActionFormData buildForm() {
    return CollectionActionFormData(
      managementType: managementType,
      result: result,
      observations: observations,
      amountPaid: result.requiresPaymentAmount ? amountPaid : null,
      commitmentDate: result.requiresCommitment ? commitmentDate : null,
      commitmentAmount: result.requiresCommitment ? commitmentAmount : null,
    );
  }
}
