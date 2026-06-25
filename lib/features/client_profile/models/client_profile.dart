import '../../../shared/widgets/risk_semaphore.dart';

enum PaymentMonthStatus { onTime, late, noInstallment }

class PaymentBehaviorMonth {
  const PaymentBehaviorMonth({
    required this.month,
    required this.status,
    required this.amountPaid,
  });

  final DateTime month;
  final PaymentMonthStatus status;
  final double amountPaid;
}

class CreditHistoryItem {
  const CreditHistoryItem({
    required this.amount,
    required this.termMonths,
    required this.tea,
    required this.status,
    required this.punctualPaymentRate,
    required this.disbursementDate,
  });

  final double amount;
  final int termMonths;
  final double tea;
  final String status;
  final double punctualPaymentRate;
  final DateTime? disbursementDate;
}

class ClientPosition {
  const ClientPosition({
    required this.totalDebt,
    required this.activeAccounts,
    required this.overdueAccounts,
    required this.maxHistoricalOverdueDays,
    required this.lastPaymentDate,
    required this.onTimeInstallments,
    required this.overdueInstallments,
  });

  final double totalDebt;
  final int activeAccounts;
  final int overdueAccounts;
  final int maxHistoricalOverdueDays;
  final DateTime? lastPaymentDate;
  final int onTimeInstallments;
  final int overdueInstallments;
}

class PreapprovedOffer {
  const PreapprovedOffer({
    required this.maxAmount,
    required this.suggestedTermMonths,
    required this.referenceTea,
    required this.confidenceScore,
    required this.expirationDate,
  });

  final double maxAmount;
  final int suggestedTermMonths;
  final double referenceTea;
  final int confidenceScore;
  final DateTime expirationDate;

  bool get isValid => expirationDate.isAfter(DateTime.now());
}

class ClientProfile {
  const ClientProfile({
    required this.clientId,
    required this.fullName,
    required this.documentNumber,
    required this.phone,
    required this.email,
    required this.address,
    required this.businessType,
    required this.businessName,
    required this.businessAgeMonths,
    required this.sbsRating,
    required this.latitude,
    required this.longitude,
    required this.position,
    required this.creditHistory,
    required this.paymentBehavior,
    this.preapproved,
  });

  final String clientId;
  final String fullName;
  final String documentNumber;
  final String phone;
  final String? email;
  final String address;
  final String businessType;
  final String businessName;
  final int businessAgeMonths;
  final SbsRating sbsRating;
  final double? latitude;
  final double? longitude;
  final ClientPosition position;
  final List<CreditHistoryItem> creditHistory;
  final List<PaymentBehaviorMonth> paymentBehavior;
  final PreapprovedOffer? preapproved;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  double get punctualPaymentPercentage {
    final withInstallment = paymentBehavior
        .where((month) => month.status != PaymentMonthStatus.noInstallment)
        .toList();
    if (withInstallment.isEmpty) {
      return 0;
    }
    final onTime = withInstallment
        .where((month) => month.status == PaymentMonthStatus.onTime)
        .length;
    return (onTime / withInstallment.length) * 100;
  }

  double get averageLateDays {
    final lateMonths = paymentBehavior
        .where((month) => month.status == PaymentMonthStatus.late)
        .length;
    if (lateMonths == 0) {
      return 0;
    }
    return position.maxHistoricalOverdueDays / lateMonths;
  }

  double get totalPaidAmount {
    return paymentBehavior.fold(0, (sum, month) => sum + month.amountPaid);
  }
}

class ProfileLoadResult {
  const ProfileLoadResult({
    required this.profile,
    required this.fromCache,
  });

  final ClientProfile profile;
  final bool fromCache;
}
