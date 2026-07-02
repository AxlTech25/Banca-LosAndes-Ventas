import '../../credit_request/models/credit_request_models.dart';
import '../models/pre_evaluation_models.dart';

/// Reglas alineadas con casos 28-30 (media APTO = 85).
class PreEvaluationScoring {
  PreEvaluationScoring._();

  static const defaultTeaPercent = 43.92;
  static const aptoScore = 85;
  static const revisarCapacidadScore = 60;

  static PreEvaluationResult evaluate({
    required int businessAgeMonths,
    required double monthlyIncome,
    required double monthlyExpenses,
    required double requestedAmount,
    required int termMonths,
    double? estimatedInstallment,
    double teaPercent = defaultTeaPercent,
  }) {
    if (businessAgeMonths < 6) {
      return const PreEvaluationResult(
        status: PreEvaluationStatus.noProcede,
        reason: 'El negocio debe tener al menos 6 meses de antiguedad.',
        estimatedScore: 15,
      );
    }

    if (monthlyIncome <= 0) {
      return const PreEvaluationResult(
        status: PreEvaluationStatus.noProcede,
        reason: 'Ingresos estimados insuficientes para evaluar.',
        estimatedScore: 20,
      );
    }

    final gastos = monthlyExpenses > 0
        ? monthlyExpenses
        : monthlyIncome * 0.4;
    final netIncome = monthlyIncome - gastos;

    if (netIncome <= 0) {
      return const PreEvaluationResult(
        status: PreEvaluationStatus.noProcede,
        reason: 'Los gastos mensuales igualan o superan los ingresos.',
        estimatedScore: 20,
      );
    }

    final term = termMonths > 0 ? termMonths : 18;
    final installment = estimatedInstallment ??
        estimateInstallment(requestedAmount, term, teaPercent);
    final incomeRatio = requestedAmount / monthlyIncome;
    final paymentBurden = installment / netIncome;

    if (paymentBurden > 1.0 || incomeRatio > 5) {
      return PreEvaluationResult(
        status: PreEvaluationStatus.revisar,
        reason:
            'Capacidad de pago ajustada. La cuota estimada (S/ ${installment.toStringAsFixed(2)}) '
            'supera el margen disponible (S/ ${netIncome.toStringAsFixed(2)}). '
            'Se recomienda analisis adicional antes del comite.',
        estimatedScore: revisarCapacidadScore,
      );
    }

    return const PreEvaluationResult(
      status: PreEvaluationStatus.apto,
      reason: 'Perfil compatible con microcredito comercial. Puede continuar.',
      estimatedScore: aptoScore,
    );
  }

  static PreEvaluationResult evaluateFromProspect(ProspectFormData form) {
    return evaluate(
      businessAgeMonths: form.businessAgeTotalMonths,
      monthlyIncome: form.estimatedIncome,
      monthlyExpenses: form.monthlyExpenses,
      requestedAmount: form.requestedAmount,
      termMonths: form.termMonths,
      estimatedInstallment: form.estimatedInstallment,
      teaPercent: form.referenceTea,
    );
  }
}
