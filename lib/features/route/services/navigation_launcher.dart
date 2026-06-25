import 'package:url_launcher/url_launcher.dart';

class NavigationLauncher {
  Future<bool> openNavigation({
    required double latitude,
    required double longitude,
  }) async {
    final wazeUri = Uri.parse(
      'waze://?ll=$latitude,$longitude&navigate=yes',
    );
    if (await canLaunchUrl(wazeUri)) {
      return launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    }

    final mapsUri = Uri.parse(
      'google.navigation:q=$latitude,$longitude',
    );
    if (await canLaunchUrl(mapsUri)) {
      return launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }

    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
