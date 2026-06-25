import 'package:flutter/foundation.dart';

import '../data/pending_payments_repository.dart';
import '../models/pending_payment_models.dart';

class PendingPaymentsViewModel extends ChangeNotifier {
  PendingPaymentsViewModel({required PendingPaymentsRepository repository})
    : _repository = repository;

  final PendingPaymentsRepository _repository;

  final List<PendingClientPayment> _payments = [];
  bool isLoading = false;
  bool isProcessing = false;
  String? processingId;
  String? errorMessage;
  String? successMessage;

  List<PendingClientPayment> get payments => List.unmodifiable(_payments);
  int get pendingCount => _payments.length;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchPendingPayments();
      _payments
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirm(PendingClientPayment payment) async {
    isProcessing = true;
    processingId = payment.id;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.confirmPayment(payment.id);
      _payments.removeWhere((item) => item.id == payment.id);
      successMessage =
          'Pago de ${payment.clientName} confirmado (S/ ${payment.monto.toStringAsFixed(2)}).';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isProcessing = false;
      processingId = null;
      notifyListeners();
    }
  }

  Future<bool> reject(
    PendingClientPayment payment, {
    String? motivo,
  }) async {
    isProcessing = true;
    processingId = payment.id;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _repository.rejectPayment(pagoId: payment.id, motivo: motivo);
      _payments.removeWhere((item) => item.id == payment.id);
      successMessage = 'Pago rechazado. El cliente fue notificado.';
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isProcessing = false;
      processingId = null;
      notifyListeners();
    }
  }
}
