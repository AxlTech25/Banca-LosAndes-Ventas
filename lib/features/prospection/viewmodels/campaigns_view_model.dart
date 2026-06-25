import 'package:flutter/foundation.dart';

import '../data/campaigns_repository.dart';
import '../models/pre_evaluation_models.dart';

class CampaignsViewModel extends ChangeNotifier {
  CampaignsViewModel({required CampaignsRepository repository})
    : _repository = repository;

  final CampaignsRepository _repository;

  final List<ActiveCampaign> _campaigns = [];
  bool isLoading = false;
  String? errorMessage;

  List<ActiveCampaign> get campaigns => List.unmodifiable(_campaigns);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchActiveCampaigns();
      _campaigns
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
