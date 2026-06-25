import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapsConfig {
  MapsConfig._();

  static String get apiKey => dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';

  static bool get isConfigured =>
      apiKey.isNotEmpty && apiKey != 'TU_GOOGLE_MAPS_API_KEY';
}
