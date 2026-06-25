import 'package:flutter/foundation.dart';

import '../data/prospection_repository.dart';
import '../models/pre_evaluation_models.dart';

class PreEvaluationViewModel extends ChangeNotifier {
  PreEvaluationViewModel({required ProspectionRepository repository})
    : _repository = repository;

  final ProspectionRepository _repository;

  String documentNumber = '';
  String firstName = '';
  String lastName = '';
  DateTime? birthDate;
  String businessType = 'Comercio';
  int businessAgeYears = 1;
  int businessAgeMonths = 0;
  double estimatedIncome = 2000;
  double requestedAmount = 5000;
  String creditPurpose = '';

  bool isSubmitting = false;
  String? validationError;
  PreEvaluationResult? result;

  static const businessTypes = [
    'Comercio',
    'Servicios',
    'Produccion',
    'Agropecuario',
  ];

  bool get canSubmit {
    return documentNumber.trim().length == 8 &&
        firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        birthDate != null &&
        creditPurpose.trim().isNotEmpty &&
        !isSubmitting;
  }

  Future<void> submit() async {
    validationError = null;
    result = null;

    if (!canSubmit) {
      validationError = 'Completa los campos obligatorios del formulario.';
      notifyListeners();
      return;
    }

    final age = DateTime.now().difference(birthDate!).inDays ~/ 365;
    if (age < 18 || age > 75) {
      validationError = 'La edad debe estar entre 18 y 75 anos.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    notifyListeners();

    try {
      result = await _repository.evaluateProspect(
        ProspectFormData(
          documentNumber: documentNumber.trim(),
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          birthDate: birthDate!,
          businessType: businessType,
          businessAgeYears: businessAgeYears,
          businessAgeMonths: businessAgeMonths,
          estimatedIncome: estimatedIncome,
          requestedAmount: requestedAmount,
          creditPurpose: creditPurpose.trim(),
        ),
      );
    } catch (error) {
      validationError = error.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void resetResult() {
    result = null;
    notifyListeners();
  }
}
