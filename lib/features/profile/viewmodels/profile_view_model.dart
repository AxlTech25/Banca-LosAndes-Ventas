import 'package:flutter/foundation.dart';

import '../../auth/data/auth_repository.dart';
import '../../portfolio/data/daily_portfolio_repository.dart';
import '../data/profile_repository.dart';
import '../models/advisor_profile_details.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required ProfileRepository profileRepository,
    required DailyPortfolioRepository portfolioRepository,
    required AuthRepository authRepository,
  }) : _profileRepository = profileRepository,
       _portfolioRepository = portfolioRepository,
       _authRepository = authRepository;

  final ProfileRepository _profileRepository;
  final DailyPortfolioRepository _portfolioRepository;
  final AuthRepository _authRepository;

  AdvisorProfileDetails? profile;
  ProfileSyncStats? syncStats;
  bool isLoading = false;
  bool isSavingProfile = false;
  bool isChangingPassword = false;
  String? errorMessage;
  String? successMessage;

  Future<void> load({required int pendingLocalDrafts}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _profileRepository.fetchProfile();
      final pendingRemote = await _authRepository.pendingSyncCount();
      syncStats = ProfileSyncStats(
        lastPortfolioSyncAt: _portfolioRepository.lastSyncAt,
        pendingRemoteSync: pendingRemote,
        pendingLocalDrafts: pendingLocalDrafts,
      );
    } catch (_) {
      errorMessage = 'No se pudo cargar tu perfil.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required String firstName,
    required String lastName,
  }) async {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      errorMessage = 'Nombres y apellidos son obligatorios.';
      notifyListeners();
      return false;
    }

    isSavingProfile = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      profile = await _profileRepository.updateProfile(
        firstName: firstName,
        lastName: lastName,
      );
      successMessage = 'Datos actualizados correctamente.';
      return true;
    } catch (_) {
      errorMessage = 'No se pudieron guardar tus datos.';
      return false;
    } finally {
      isSavingProfile = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword.length < 8) {
      errorMessage = 'La contraseña debe tener al menos 8 caracteres.';
      notifyListeners();
      return false;
    }
    if (newPassword != confirmPassword) {
      errorMessage = 'Las contraseñas no coinciden.';
      notifyListeners();
      return false;
    }

    isChangingPassword = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _authRepository.updatePassword(newPassword);
      successMessage = 'Contraseña actualizada correctamente.';
      return true;
    } on WeakPasswordException catch (_) {
      errorMessage = 'La contraseña no cumple los requisitos de seguridad.';
      return false;
    } on AuthPasswordUpdateException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'No se pudo cambiar la contraseña.';
      return false;
    } finally {
      isChangingPassword = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
