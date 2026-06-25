import 'package:flutter/foundation.dart';

import '../data/supervision_repository.dart';
import '../models/supervision_models.dart';
import '../services/productivity_pdf_service.dart';

class ProductivityReportViewModel extends ChangeNotifier {
  ProductivityReportViewModel({required SupervisionRepository repository})
    : _repository = repository;

  final SupervisionRepository _repository;

  AgencyProductivityReport? report;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool isLoading = false;
  bool isExporting = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      report = await _repository.fetchProductivityForMonth(selectedMonth);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickMonth(DateTime month) async {
    selectedMonth = DateTime(month.year, month.month);
    await load();
  }

  Future<void> exportPdf() async {
    final currentReport = report;
    if (currentReport == null) {
      return;
    }

    isExporting = true;
    notifyListeners();

    try {
      await ProductivityPdfService.shareReport(currentReport);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }
}
