import 'user_role.dart';

class AuthSession {
  const AuthSession({
    required this.advisorId,
    required this.agencyId,
    required this.employeeCode,
    required this.displayName,
    required this.internalEmail,
    required this.role,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    required this.lastActivityAt,
  });

  final String advisorId;
  final String agencyId;
  final String employeeCode;
  final String displayName;
  final String internalEmail;
  final UserRole role;
  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime lastActivityAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isInactive {
    return DateTime.now().difference(lastActivityAt) > const Duration(hours: 8);
  }

  AuthSession copyWith({DateTime? expiresAt, DateTime? lastActivityAt}) {
    return AuthSession(
      advisorId: advisorId,
      agencyId: agencyId,
      employeeCode: employeeCode,
      displayName: displayName,
      internalEmail: internalEmail,
      role: role,
      token: token,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'advisorId': advisorId,
      'agencyId': agencyId,
      'employeeCode': employeeCode,
      'displayName': displayName,
      'internalEmail': internalEmail,
      'role': role.name,
      'token': token,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'lastActivityAt': lastActivityAt.toIso8601String(),
    };
  }

  static AuthSession fromJson(Map<String, Object?> json) {
    return AuthSession(
      advisorId: json['advisorId'] as String,
      agencyId: json['agencyId'] as String,
      employeeCode: json['employeeCode'] as String,
      displayName: (json['displayName'] as String?) ?? json['employeeCode'] as String,
      internalEmail: json['internalEmail'] as String,
      role: UserRole.fromCode(json['role'] as String),
      token: json['token'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
    );
  }
}
