import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/auth_session.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  String employeeCode = '';
  String password = '';
  bool isPasswordVisible = false;
  bool isLoading = false;
  DateTime? lockedUntil;
  String? errorMessage;

  bool get isBlocked {
    final currentLock = lockedUntil;
    return currentLock != null && currentLock.isAfter(DateTime.now());
  }

  Duration get remainingLockTime {
    final currentLock = lockedUntil;
    if (currentLock == null) {
      return Duration.zero;
    }
    final remaining = currentLock.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canSubmit {
    return employeeCode.trim().isNotEmpty &&
        password.isNotEmpty &&
        !isLoading &&
        !isBlocked;
  }

  Future<void> loadLockState() async {
    lockedUntil = await _authRepository.currentLockUntil();
    notifyListeners();
  }

  void updateEmployeeCode(String value) {
    employeeCode = value;
    errorMessage = null;
    notifyListeners();
  }

  void updatePassword(String value) {
    password = value;
    errorMessage = null;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  Future<AuthSession?> submit() async {
    if (!canSubmit) {
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _authRepository.signIn(
        employeeCode: employeeCode,
        password: password,
      );
    } on AuthBlockedException catch (error) {
      lockedUntil = error.lockedUntil;
      errorMessage = 'Acceso bloqueado temporalmente.';
      return null;
    } on AuthFailureException {
      await loadLockState();
      errorMessage = isBlocked
          ? 'Acceso bloqueado temporalmente.'
          : 'Codigo de empleado o contrasena incorrectos.';
      return null;
    } on SupabaseNotConfiguredException {
      errorMessage =
          'Configura SUPABASE_URL y SUPABASE_ANON_KEY para conectar Supabase.';
      return null;
    } on AccountDisabledException {
      errorMessage = 'Tu usuario esta inactivo. Contacta al administrador.';
      return null;
    } on UserProfileNotFoundException {
      errorMessage =
          'No se encontro tu perfil en asesores_negocio. '
          'Crea el usuario Auth y vinculalo con el seed demo.';
      return null;
    } on UserProfileReadException catch (error) {
      errorMessage = 'No se pudo leer tu perfil: ${error.message}';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
