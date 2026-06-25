import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

import '../../portfolio/data/daily_portfolio_repository.dart';
import '../../portfolio/models/daily_client.dart';
import '../data/geofence_repository.dart';
import '../services/navigation_launcher.dart';
import '../services/route_optimizer.dart';

class RouteMapViewModel extends ChangeNotifier {
  RouteMapViewModel({
    required DailyPortfolioRepository portfolioRepository,
    required GeofenceRepository geofenceRepository,
    required String advisorId,
    RouteOptimizer? optimizer,
    NavigationLauncher? navigationLauncher,
  }) : _portfolioRepository = portfolioRepository,
       _geofenceRepository = geofenceRepository,
       _advisorId = advisorId,
       _optimizer = optimizer ?? RouteOptimizer(),
       _navigationLauncher = navigationLauncher ?? NavigationLauncher();

  final DailyPortfolioRepository _portfolioRepository;
  final GeofenceRepository _geofenceRepository;
  final String _advisorId;
  final RouteOptimizer _optimizer;
  final NavigationLauncher _navigationLauncher;

  final List<DailyClient> _clients = [];
  List<DailyClient> orderedRoute = [];
  GoogleMapController? mapController;
  LatLng? currentPosition;
  DailyClient? selectedClient;
  bool isLoading = false;
  bool isOptimizing = false;
  bool locationDenied = false;
  String? errorMessage;
  List<WorkZone> workZones = [];
  bool outsideWorkZone = false;

  List<DailyClient> get clients => List.unmodifiable(_clients);

  Set<Polygon> get zonePolygons {
    return workZones.map((zone) {
      final color = _parseHexColor(zone.color);
      return Polygon(
        polygonId: PolygonId(zone.id),
        points: zone.polygon
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(),
        strokeColor: color,
        fillColor: color.withValues(alpha: 0.18),
        strokeWidth: 2,
      );
    }).toSet();
  }

  Set<Marker> get markers {
    final routeIndex = {
      for (var i = 0; i < orderedRoute.length; i++) orderedRoute[i].id: i,
    };

    return _clients.where((client) => client.hasCoordinates).map((client) {
      final order = routeIndex[client.id];
      final hue = client.isVisited
          ? BitmapDescriptor.hueAzure
          : switch (client.priorityLevel) {
              PriorityLevel.high => BitmapDescriptor.hueRed,
              PriorityLevel.medium => BitmapDescriptor.hueYellow,
              PriorityLevel.normal => BitmapDescriptor.hueGreen,
            };

      return Marker(
        markerId: MarkerId(client.id),
        position: LatLng(client.latitude!, client.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        alpha: client.isVisited ? 0.55 : 1,
        infoWindow: InfoWindow(
          title: client.clientName,
          snippet: order == null
              ? client.managementType.label
              : '#${order + 1} · ${client.managementType.label}',
        ),
        onTap: () {
          selectedClient = client;
          notifyListeners();
        },
      );
    }).toSet();
  }

  Set<Polyline> get polylines {
    if (orderedRoute.length < 2) {
      return {};
    }

    final points = <LatLng>[];
    if (currentPosition != null) {
      points.add(currentPosition!);
    }
    points.addAll(
      orderedRoute
          .where((client) => client.hasCoordinates)
          .map((client) => LatLng(client.latitude!, client.longitude!)),
    );

    if (points.length < 2) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('optimized_route'),
        color: const Color(0xFF00C1F9),
        width: 4,
        points: points,
      ),
    };
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _resolveCurrentPosition();
      final cached = await _portfolioRepository.loadCachedPortfolio();
      _clients
        ..clear()
        ..addAll(cached);

      final refreshed = await _portfolioRepository.refreshTodayPortfolio();
      _clients
        ..clear()
        ..addAll(refreshed);
      orderedRoute = _clients.where((client) => client.hasCoordinates).toList();
      if (orderedRoute.isEmpty) {
        orderedRoute = List<DailyClient>.from(_clients);
      }
      workZones = await _geofenceRepository.fetchZonesForAdvisor(_advisorId);
      _refreshGeofenceStatus();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> optimizeRoute() async {
    if (_clients.isEmpty) {
      return;
    }

    isOptimizing = true;
    notifyListeners();

    try {
      await _resolveCurrentPosition();
      final startLat = currentPosition?.latitude ?? _clients.first.latitude!;
      final startLng = currentPosition?.longitude ?? _clients.first.longitude!;
      orderedRoute = _optimizer.nearestNeighbor(
        startLat: startLat,
        startLng: startLng,
        clients: _clients,
      );
      await _fitCameraToRoute();
    } finally {
      isOptimizing = false;
      notifyListeners();
    }
  }

  Future<void> navigateToFirstDestination() async {
    final destination = orderedRoute.firstWhere(
      (client) => client.hasCoordinates && !client.isVisited,
      orElse: () => orderedRoute.firstWhere(
        (client) => client.hasCoordinates,
        orElse: () => throw Exception('No hay clientes con coordenadas.'),
      ),
    );

    final launched = await _navigationLauncher.openNavigation(
      latitude: destination.latitude!,
      longitude: destination.longitude!,
    );
    if (!launched) {
      errorMessage = 'No se pudo abrir la app de navegacion.';
      notifyListeners();
    }
  }

  void bindMapController(GoogleMapController controller) {
    mapController = controller;
    _fitCameraToRoute();
  }

  void clearSelectedClient() {
    selectedClient = null;
    notifyListeners();
  }

  Future<void> _resolveCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationDenied = true;
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationDenied = true;
        return;
      }

      locationDenied = false;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      currentPosition = LatLng(position.latitude, position.longitude);
      _refreshGeofenceStatus();
    } catch (_) {
      locationDenied = true;
    }
  }

  void _refreshGeofenceStatus() {
    final position = currentPosition;
    if (position == null || workZones.isEmpty) {
      outsideWorkZone = false;
      return;
    }
    outsideWorkZone = !_geofenceRepository.isInsideAnyZone(
      position.latitude,
      position.longitude,
      workZones,
    );
  }

  String? get assignedZoneLabel {
    if (workZones.isEmpty) {
      return null;
    }
    if (workZones.length == 1) {
      return workZones.first.name;
    }
    return '${workZones.length} zonas asignadas';
  }

  Color _parseHexColor(String hex) {
    final normalized = hex.replaceAll('#', '');
    if (normalized.length != 6) {
      return const Color(0xFF00C1F9);
    }
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) {
      return const Color(0xFF00C1F9);
    }
    return Color(0xFF000000 | value);
  }

  Future<void> _fitCameraToRoute() async {
    final controller = mapController;
    if (controller == null) {
      return;
    }

    final points = _clients
        .where((client) => client.hasCoordinates)
        .map((client) => LatLng(client.latitude!, client.longitude!))
        .toList();
    for (final zone in workZones) {
      for (final point in zone.polygon) {
        points.add(LatLng(point.latitude, point.longitude));
      }
    }
    if (currentPosition != null) {
      points.add(currentPosition!);
    }
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        48,
      ),
    );
  }
}
