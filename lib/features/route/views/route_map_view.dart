import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/maps_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../../client_profile/views/client_profile_view.dart';
import '../../portfolio/data/daily_portfolio_repository.dart';
import '../../portfolio/models/daily_client.dart';
import '../../route/data/geofence_repository.dart';
import '../viewmodels/route_map_view_model.dart';

class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.session,
    this.embedded = false,
  });

  final AuthSession session;
  final bool embedded;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  RouteMapViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final repository = DailyPortfolioRepository(
      client: supabase.Supabase.instance.client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final viewModel = RouteMapViewModel(
      portfolioRepository: repository,
      geofenceRepository: GeofenceRepository(
        client: supabase.Supabase.instance.client,
      ),
      advisorId: widget.session.advisorId,
    )..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
    await viewModel.load();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openClientProfile(DailyClient client) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientProfileView(
          session: widget.session,
          dailyClient: client,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final selected = viewModel?.selectedClient;
    final mappableClients =
        viewModel?.clients.where((client) => client.hasCoordinates).length ?? 0;

    final content = viewModel == null || viewModel.isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (!MapsConfig.isConfigured)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppColors.surfaceContainerHighest,
                  child: const Text(
                    'Mapa sin cargar: agrega GOOGLE_MAPS_API_KEY en el archivo .env '
                    'y vuelve a compilar la app (flutter run).',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              if (viewModel.assignedZoneLabel != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: AppColors.surfaceContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: viewModel.outsideWorkZone
                            ? const Color(0xFFFFB020)
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          viewModel.outsideWorkZone
                              ? 'Zona asignada: ${viewModel.assignedZoneLabel}. '
                                  'Si registras visita fuera de ella, se pedira confirmacion.'
                              : 'Zona asignada: ${viewModel.assignedZoneLabel}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (viewModel.locationDenied)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppColors.surfaceContainerHighest,
                  child: const Text(
                    'Sin permiso de ubicacion: el mapa funciona, pero no hay optimizacion desde tu posicion.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: Color(0xFFFF4D4D)),
                  ),
                ),
              Expanded(
                child: mappableClients == 0
                    ? const Center(
                        child: Text(
                          'No hay clientes con coordenadas GPS.\n'
                          'Actualiza la ubicacion desde la ficha del cliente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: viewModel.currentPosition ??
                              LatLng(
                                viewModel.clients.first.latitude ?? -12.046374,
                                viewModel.clients.first.longitude ?? -77.042793,
                              ),
                          zoom: 13,
                        ),
                        myLocationEnabled: !viewModel.locationDenied,
                        myLocationButtonEnabled: !viewModel.locationDenied,
                        markers: viewModel.markers,
                        polylines: viewModel.polylines,
                        polygons: viewModel.zonePolygons,
                        onMapCreated: viewModel.bindMapController,
                      ),
              ),
              if (selected != null)
                _ClientQuickSheet(
                  client: selected,
                  onOpenProfile: () => _openClientProfile(selected),
                  onClose: viewModel.clearSelectedClient,
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: viewModel.isOptimizing
                            ? null
                            : viewModel.optimizeRoute,
                        icon: viewModel.isOptimizing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.route),
                        label: const Text('Optimizar ruta'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: viewModel.orderedRoute.isEmpty
                            ? null
                            : viewModel.navigateToFirstDestination,
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('Navegar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Ruta del dia'),
      ),
      body: content,
    );
  }
}

class _ClientQuickSheet extends StatelessWidget {
  const _ClientQuickSheet({
    required this.client,
    required this.onOpenProfile,
    required this.onClose,
  });

  final DailyClient client;
  final VoidCallback onOpenProfile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.clientName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  client.managementType.label,
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onClose, child: const Text('Cerrar')),
          FilledButton(
            onPressed: onOpenProfile,
            child: const Text('Ver ficha'),
          ),
        ],
      ),
    );
  }
}
