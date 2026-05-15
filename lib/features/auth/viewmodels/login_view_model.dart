import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  String employeeCode = '';
  String password = '';
  bool rememberDevice = false;

  bool get canSubmit => employeeCode.trim().isNotEmpty && password.isNotEmpty;

  void updateEmployeeCode(String value) {
    employeeCode = value;
    notifyListeners();
  }

  void updatePassword(String value) {
    password = value;
    notifyListeners();
  }

  void updateRememberDevice(bool value) {
    rememberDevice = value;
    notifyListeners();
  }

  bool submit() {
    if (!canSubmit) {
      return false;
    }

    // Aqui se conectara el caso de uso de autenticacion con Supabase.
    return true;
  }
}
