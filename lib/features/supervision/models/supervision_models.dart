import '../../portfolio/models/daily_client.dart';

class AgencyAdvisor {
  const AgencyAdvisor({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String employeeCode;
  final String firstName;
  final String lastName;

  String get displayName => '$firstName $lastName'.trim();

  factory AgencyAdvisor.fromJson(Map<String, dynamic> json) {
    return AgencyAdvisor(
      id: json['id'].toString(),
      employeeCode: json['codigo_empleado'].toString(),
      firstName: json['nombres']?.toString() ?? '',
      lastName: json['apellidos']?.toString() ?? '',
    );
  }
}

class AdvisorCoverageSnapshot {
  const AdvisorCoverageSnapshot({
    required this.advisor,
    required this.totalAssigned,
    required this.visitedCount,
    this.lastSyncAt,
    this.lastLatitude,
    this.lastLongitude,
  });

  final AgencyAdvisor advisor;
  final int totalAssigned;
  final int visitedCount;
  final DateTime? lastSyncAt;
  final double? lastLatitude;
  final double? lastLongitude;

  double get coverageRatio =>
      totalAssigned == 0 ? 0 : visitedCount / totalAssigned;

  int get coveragePercent => (coverageRatio * 100).round();

  bool get hasMapPosition => lastLatitude != null && lastLongitude != null;

  String get coverageLabel => '$visitedCount / $totalAssigned';
}

class AdvisorProductivityRow {
  const AdvisorProductivityRow({
    required this.advisor,
    required this.submittedCount,
    required this.approvedCount,
    required this.disbursedCount,
    required this.disbursedAmount,
  });

  final AgencyAdvisor advisor;
  final int submittedCount;
  final int approvedCount;
  final int disbursedCount;
  final double disbursedAmount;

  double get conversionRate =>
      submittedCount == 0 ? 0 : disbursedCount / submittedCount;

  int get conversionPercent => (conversionRate * 100).round();
}

class AgencyProductivityReport {
  const AgencyProductivityReport({
    required this.month,
    required this.rows,
  });

  final DateTime month;
  final List<AdvisorProductivityRow> rows;

  int get totalSubmitted =>
      rows.fold(0, (sum, row) => sum + row.submittedCount);

  int get totalDisbursed =>
      rows.fold(0, (sum, row) => sum + row.disbursedCount);

  double get totalDisbursedAmount =>
      rows.fold(0, (sum, row) => sum + row.disbursedAmount);
}

class DailyPortfolioVisitRow {
  const DailyPortfolioVisitRow({
    required this.advisorId,
    required this.visitStatus,
    required this.timestampVisit,
    required this.latitude,
    required this.longitude,
  });

  final String advisorId;
  final VisitStatus visitStatus;
  final DateTime? timestampVisit;
  final double? latitude;
  final double? longitude;

  factory DailyPortfolioVisitRow.fromJson(Map<String, dynamic> json) {
    return DailyPortfolioVisitRow(
      advisorId: json['asesor_id'].toString(),
      visitStatus: VisitStatus.fromCode(json['estado_visita']?.toString()),
      timestampVisit: json['timestamp_visita'] == null
          ? null
          : DateTime.tryParse(json['timestamp_visita'].toString()),
      latitude: (json['lat_visita'] as num?)?.toDouble(),
      longitude: (json['lng_visita'] as num?)?.toDouble(),
    );
  }
}
