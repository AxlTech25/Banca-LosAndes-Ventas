import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/client_profile_repository.dart';
import '../models/client_profile.dart';

class ClientProfileViewModel extends ChangeNotifier {
  ClientProfileViewModel({required ClientProfileRepository repository})
    : _repository = repository;

  final ClientProfileRepository _repository;

  ClientProfile? profile;
  bool isLoading = false;
  bool isOfflineData = false;
  bool isUpdatingLocation = false;
  String? errorMessage;
  String? locationPreview;
  String? locationMessage;

  Future<void> load(String clientId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.loadProfile(clientId);
      profile = result.profile;
      isOfflineData = result.fromCache;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> captureBusinessLocation() async {
    final currentProfile = profile;
    if (currentProfile == null || isUpdatingLocation) {
      return;
    }

    isUpdatingLocation = true;
    locationMessage = null;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Activa el GPS del dispositivo.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Se requiere permiso de ubicacion.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      locationPreview = await _repository.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      notifyListeners();
    } catch (error) {
      locationMessage = error.toString();
    } finally {
      isUpdatingLocation = false;
      notifyListeners();
    }
  }

  Future<void> confirmCapturedLocation() async {
    final currentProfile = profile;
    final preview = locationPreview;
    if (currentProfile == null || preview == null) {
      return;
    }

    isUpdatingLocation = true;
    notifyListeners();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      profile = await _repository.updateBusinessLocation(
        profile: currentProfile,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      locationPreview = null;
      locationMessage = 'Ubicacion del negocio actualizada.';
    } catch (error) {
      locationMessage = error.toString();
    } finally {
      isUpdatingLocation = false;
      notifyListeners();
    }
  }

  void discardCapturedLocation() {
    locationPreview = null;
    notifyListeners();
  }
}
