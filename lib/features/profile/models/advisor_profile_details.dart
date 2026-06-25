class AdvisorProfileDetails {
  const AdvisorProfileDetails({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.agencyName,
    required this.internalEmail,
  });

  final String id;
  final String employeeCode;
  final String firstName;
  final String lastName;
  final String role;
  final String agencyName;
  final String internalEmail;

  String get displayName => '$firstName $lastName'.trim();
}

class ProfileSyncStats {
  const ProfileSyncStats({
    required this.lastPortfolioSyncAt,
    required this.pendingRemoteSync,
    required this.pendingLocalDrafts,
  });

  final DateTime? lastPortfolioSyncAt;
  final int pendingRemoteSync;
  final int pendingLocalDrafts;

  int get totalPending => pendingRemoteSync + pendingLocalDrafts;
}
