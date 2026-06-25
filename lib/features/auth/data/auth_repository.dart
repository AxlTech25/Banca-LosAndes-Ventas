import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/auth_session.dart';
import '../models/user_role.dart';

class AuthRepository {
  AuthRepository({
    required bool isSupabaseConfigured,
    supabase.SupabaseClient? client,
    FlutterSecureStorage? secureStorage,
  }) : _isSupabaseConfigured = isSupabaseConfigured,
       _client = client,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const int maxFailedAttempts = 5;
  static const Duration lockDuration = Duration(minutes: 30);
  static const Duration inactivityLimit = Duration(hours: 8);

  static const String _internalEmailDomain = 'losandes.internal';
  static const String _failedAttemptsKey = 'auth_failed_attempts';
  static const String _lockedUntilKey = 'auth_locked_until';
  static const String _lastActivityKey = 'auth_last_activity_at';

  final bool _isSupabaseConfigured;
  final supabase.SupabaseClient? _client;
  final FlutterSecureStorage _secureStorage;

  supabase.SupabaseClient get _supabaseClient {
    if (!_isSupabaseConfigured || _client == null) {
      throw const SupabaseNotConfiguredException();
    }
    return _client;
  }

  Future<AuthSession?> restoreSession() async {
    if (!_isSupabaseConfigured || _client == null) {
      return null;
    }

    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      await clearSession();
      return null;
    }

    final lastActivityAt = await _readLastActivityAt();
    if (lastActivityAt != null &&
        DateTime.now().difference(lastActivityAt) > inactivityLimit) {
      await signOut();
      return null;
    }

    final refreshed = await _refreshSessionIfNeeded(session);
    final authSession = await _toAuthSession(refreshed);
    if (authSession == null) {
      await signOut();
      return null;
    }
    await markActivity(authSession);
    return authSession;
  }

  Future<AuthSession> signIn({
    required String employeeCode,
    required String password,
  }) async {
    final lockUntil = await currentLockUntil();
    if (lockUntil != null && lockUntil.isAfter(DateTime.now())) {
      throw AuthBlockedException(lockUntil);
    }

    final normalizedCode = employeeCode.trim();
    if (!RegExp(r'^\d+$').hasMatch(normalizedCode)) {
      throw const AuthFailureException();
    }

    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: _internalEmailFor(normalizedCode),
        password: password,
      );
      final session = response.session;
      if (session == null) {
        throw const AuthFailureException();
      }

      await _clearFailedAttempts();
      final authSession = await _toAuthSession(session);
      if (authSession == null) {
        await signOut();
        throw const AccountDisabledException();
      }
      await markActivity(authSession);
      return authSession;
    } on supabase.AuthException catch (_) {
      final lock = await _registerFailedAttempt();
      if (lock != null) {
        throw AuthBlockedException(lock);
      }
      throw const AuthFailureException();
    }
  }

  Future<void> markActivity(AuthSession session) async {
    await _secureStorage.write(
      key: _lastActivityKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<void> signOut() async {
    if (_isSupabaseConfigured && _client != null) {
      await _client.auth.signOut();
    }
    await clearSession();
    await clearCachedSensitiveData();
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _lastActivityKey);
  }

  Future<void> clearCachedSensitiveData() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where(
      (key) =>
          key.startsWith('cartera_') ||
          key.startsWith('visitas_pendientes_') ||
          key.startsWith('credit_request_') ||
          key.startsWith('consultas_buro_pendientes_') ||
          key.startsWith('prospection_pending_') ||
          key.startsWith('collection_pending_'),
    );
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabaseClient.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('weak') || message.contains('password')) {
        throw const WeakPasswordException();
      }
      throw AuthPasswordUpdateException(error.message);
    }
  }

  Future<int> pendingSyncCount() async {
    if (!_isSupabaseConfigured || _client == null) {
      return 0;
    }

    final advisorId = await _currentAdvisorId();
    if (advisorId == null) {
      return 0;
    }

    try {
      final rows = await _supabaseClient
          .from('solicitudes_credito')
          .select('id')
          .eq('asesor_id', advisorId)
          .eq('pendiente_sync', true);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> _currentAdvisorId() async {
    final user = _client?.auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final profile = await _supabaseClient
          .from('asesores_negocio')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      return profile?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> currentLockUntil() async {
    final lockedUntilValue = await _secureStorage.read(key: _lockedUntilKey);
    if (lockedUntilValue == null) {
      return null;
    }

    final lockedUntil = DateTime.tryParse(lockedUntilValue);
    if (lockedUntil == null || lockedUntil.isBefore(DateTime.now())) {
      await _clearFailedAttempts();
      return null;
    }
    return lockedUntil;
  }

  Future<DateTime?> _readLastActivityAt() async {
    final value = await _secureStorage.read(key: _lastActivityKey);
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<supabase.Session> _refreshSessionIfNeeded(
    supabase.Session session,
  ) async {
    if (!session.isExpired) {
      return session;
    }

    final response = await _supabaseClient.auth.refreshSession();
    return response.session ?? session;
  }

  Future<AuthSession?> _toAuthSession(supabase.Session session) async {
    final user = session.user;
    final email = user.email ?? '';
    final now = DateTime.now();
    final expiresAt = session.expiresAt == null
        ? now.add(const Duration(hours: 1))
        : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);

    final profile = await _profileForUser(user);
    if (profile != null && profile.activo == false) {
      return null;
    }
    if (profile == null) {
      throw const UserProfileNotFoundException();
    }

    return AuthSession(
      advisorId: profile.id,
      agencyId: profile.agenciaId,
      employeeCode: _employeeCodeFromProfileOrUser(profile, user, email),
      displayName: profile.displayName,
      internalEmail: email,
      role: _roleFromProfileOrUser(profile, user),
      token: session.accessToken,
      createdAt: DateTime.tryParse(user.createdAt) ?? now,
      expiresAt: expiresAt,
      lastActivityAt: now,
    );
  }

  Future<_AdvisorProfile?> _profileForUser(supabase.User user) async {
    try {
      final profile = await _supabaseClient
          .from('asesores_negocio')
          .select(
            'id, perfil, activo, codigo_empleado, nombres, apellidos, agencia_id',
          )
          .eq('user_id', user.id)
          .maybeSingle();
      if (profile == null) {
        return null;
      }
      return _AdvisorProfile.fromJson(profile);
    } on supabase.PostgrestException catch (error) {
      throw UserProfileReadException(error.message);
    } catch (error) {
      throw UserProfileReadException(error.toString());
    }
  }

  String _internalEmailFor(String employeeCode) {
    return '$employeeCode@$_internalEmailDomain';
  }

  String _employeeCodeFromProfileOrUser(
    _AdvisorProfile? profile,
    supabase.User user,
    String email,
  ) {
    final profileEmployeeCode = profile?.codigoEmpleado;
    if (profileEmployeeCode != null && profileEmployeeCode.trim().isNotEmpty) {
      return profileEmployeeCode;
    }

    final metadataValue =
        user.appMetadata['employee_code'] ??
        user.appMetadata['codigo_empleado'] ??
        user.userMetadata?['employee_code'] ??
        user.userMetadata?['codigo_empleado'];
    if (metadataValue != null) {
      return metadataValue.toString();
    }

    if (email.contains('@')) {
      return email.split('@').first;
    }
    return user.id;
  }

  UserRole _roleFromProfileOrUser(_AdvisorProfile? profile, supabase.User user) {
    final profileRole = profile?.perfil;
    if (profileRole != null && profileRole.trim().isNotEmpty) {
      return UserRole.fromCode(profileRole);
    }

    final roleValue =
        user.appMetadata['role'] ??
        user.appMetadata['perfil'] ??
        user.appMetadata['profile'] ??
        user.userMetadata?['role'] ??
        user.userMetadata?['perfil'] ??
        user.userMetadata?['profile'];
    if (roleValue == null) {
      return UserRole.operator;
    }
    return UserRole.fromCode(roleValue.toString());
  }

  Future<DateTime?> _registerFailedAttempt() async {
    final attemptsValue = await _secureStorage.read(key: _failedAttemptsKey);
    final attempts = (int.tryParse(attemptsValue ?? '0') ?? 0) + 1;
    final lockedUntil = attempts >= maxFailedAttempts
        ? DateTime.now().add(lockDuration)
        : null;

    await _secureStorage.write(
      key: _failedAttemptsKey,
      value: attempts.toString(),
    );
    if (lockedUntil != null) {
      await _secureStorage.write(
        key: _lockedUntilKey,
        value: lockedUntil.toIso8601String(),
      );
    }
    return lockedUntil;
  }

  Future<void> _clearFailedAttempts() async {
    await _secureStorage.delete(key: _failedAttemptsKey);
    await _secureStorage.delete(key: _lockedUntilKey);
  }
}

class AuthFailureException implements Exception {
  const AuthFailureException();
}

class AuthBlockedException implements Exception {
  const AuthBlockedException(this.lockedUntil);

  final DateTime lockedUntil;
}

class SupabaseNotConfiguredException implements Exception {
  const SupabaseNotConfiguredException();
}

class AccountDisabledException implements Exception {
  const AccountDisabledException();
}

class UserProfileNotFoundException implements Exception {
  const UserProfileNotFoundException();
}

class UserProfileReadException implements Exception {
  const UserProfileReadException(this.message);

  final String message;
}

class WeakPasswordException implements Exception {
  const WeakPasswordException();
}

class AuthPasswordUpdateException implements Exception {
  const AuthPasswordUpdateException(this.message);

  final String message;
}

class _AdvisorProfile {
  const _AdvisorProfile({
    required this.id,
    required this.perfil,
    required this.activo,
    required this.codigoEmpleado,
    required this.nombres,
    required this.apellidos,
    required this.agenciaId,
  });

  final String id;
  final String? perfil;
  final bool? activo;
  final String? codigoEmpleado;
  final String nombres;
  final String apellidos;
  final String agenciaId;

  String get displayName => '$nombres $apellidos'.trim();

  static _AdvisorProfile fromJson(Map<String, dynamic> json) {
    return _AdvisorProfile(
      id: json['id'].toString(),
      perfil: json['perfil'] as String?,
      activo: json['activo'] as bool?,
      codigoEmpleado: json['codigo_empleado'] as String?,
      nombres: (json['nombres'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? '').toString(),
      agenciaId: json['agencia_id'].toString(),
    );
  }
}
