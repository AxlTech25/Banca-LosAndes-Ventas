import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/supervision_repository.dart';
import '../models/supervision_models.dart';

class CoverageMonitorViewModel extends ChangeNotifier {
  CoverageMonitorViewModel({required SupervisionRepository repository})
    : _repository = repository;

  final SupervisionRepository _repository;

  List<AdvisorCoverageSnapshot> snapshots = const [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;
  supabase.RealtimeChannel? _channel;
  GoogleMapController? mapController;

  static const _markerColors = <Color>[
    Color(0xFF89D9FF),
    Color(0xFF27C46B),
    Color(0xFFFF9F1C),
    Color(0xFFFF4D4D),
    Color(0xFF9B5DE5),
    Color(0xFF6ED2FF),
  ];

  int get totalAssigned =>
      snapshots.fold(0, (sum, row) => sum + row.totalAssigned);

  int get totalVisited =>
      snapshots.fold(0, (sum, row) => sum + row.visitedCount);

  int get agencyCoveragePercent =>
      totalAssigned == 0 ? 0 : ((totalVisited / totalAssigned) * 100).round();

  Set<Marker> get markers {
    final markers = <Marker>{};
    for (var index = 0; index < snapshots.length; index++) {
      final snapshot = snapshots[index];
      if (!snapshot.hasMapPosition) {
        continue;
      }
      final hue = _markerColors[index % _markerColors.length];
      markers.add(
        Marker(
          markerId: MarkerId(snapshot.advisor.id),
          position: LatLng(snapshot.lastLatitude!, snapshot.lastLongitude!),
          infoWindow: InfoWindow(
            title: snapshot.advisor.displayName,
            snippet:
                '${snapshot.coverageLabel} visitas · ${snapshot.coveragePercent}%',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            HSVColor.fromColor(hue).hue,
          ),
        ),
      );
    }
    return markers;
  }

  LatLng? get initialCameraTarget {
    for (final snapshot in snapshots) {
      if (snapshot.hasMapPosition) {
        return LatLng(snapshot.lastLatitude!, snapshot.lastLongitude!);
      }
    }
    return const LatLng(-12.046374, -77.042793);
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      snapshots = await _repository.fetchCoverageForDate(selectedDate);
      _subscribeRealtime();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      snapshots = await _repository.fetchCoverageForDate(selectedDate);
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> pickDate(DateTime date) async {
    selectedDate = DateTime(date.year, date.month, date.day);
    await load();
  }

  void bindMapController(GoogleMapController controller) {
    mapController = controller;
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = _repository.subscribeToCoverageChanges(() {
      refresh();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    mapController?.dispose();
    super.dispose();
  }
}
