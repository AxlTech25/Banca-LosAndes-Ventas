import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/supervision_repository.dart';
import '../models/supervision_models.dart';
import '../viewmodels/coverage_monitor_view_model.dart';

class CoverageMonitorView extends StatefulWidget {
  const CoverageMonitorView({super.key, required this.session});

  final AuthSession session;

  @override
  State<CoverageMonitorView> createState() => _CoverageMonitorViewState();
}

class _CoverageMonitorViewState extends State<CoverageMonitorView> {
  CoverageMonitorViewModel? _viewModel;

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
    final viewModel = CoverageMonitorViewModel(
      repository: SupervisionRepository(
        client: supabase.Supabase.instance.client,
        agencyId: widget.session.agencyId,
      ),
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

  Future<void> _pickDate() async {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await viewModel.pickDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Monitor de cobertura'),
        actions: [
          IconButton(
            onPressed: viewModel == null || viewModel.isLoading
                ? null
                : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Cambiar fecha',
          ),
          IconButton(
            onPressed: viewModel == null || viewModel.isLoading
                ? null
                : viewModel.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: viewModel == null || viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _SummaryBanner(viewModel: viewModel),
                if (viewModel.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      viewModel.errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF4D4D)),
                    ),
                  ),
                Expanded(
                  flex: 5,
                  child: viewModel.markers.isEmpty
                      ? const Center(
                          child: Text(
                            'Sin posiciones GPS de visitas para esta fecha.\n'
                            'Los marcadores aparecen cuando un asesor registra visita con ubicacion.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: viewModel.initialCameraTarget!,
                            zoom: 12,
                          ),
                          markers: viewModel.markers,
                          onMapCreated: viewModel.bindMapController,
                        ),
                ),
                Expanded(
                  flex: 4,
                  child: _CoverageTable(snapshots: viewModel.snapshots),
                ),
              ],
            ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.viewModel});

  final CoverageMonitorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${viewModel.selectedDate.day.toString().padLeft(2, '0')}/'
        '${viewModel.selectedDate.month.toString().padLeft(2, '0')}/'
        '${viewModel.selectedDate.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cobertura del $dateLabel',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${viewModel.totalVisited} visitados de ${viewModel.totalAssigned} asignados',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${viewModel.agencyCoveragePercent}%',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageTable extends StatelessWidget {
  const _CoverageTable({required this.snapshots});

  final List<AdvisorCoverageSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return const Center(
        child: Text(
          'No hay asesores activos en la agencia.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Avance por asesor',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: snapshots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              return _CoverageRow(snapshot: snapshot);
            },
          ),
        ),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.snapshot});

  final AdvisorCoverageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final syncLabel = snapshot.lastSyncAt == null
        ? 'Sin sincronizacion'
        : _formatTime(snapshot.lastSyncAt!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snapshot.advisor.displayName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                snapshot.coverageLabel,
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cod. ${snapshot.advisor.employeeCode} · Ult. sync: $syncLabel',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: snapshot.coverageRatio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: _progressColor(snapshot.coveragePercent),
            ),
          ),
        ],
      ),
    );
  }

  static Color _progressColor(int percent) {
    if (percent >= 80) {
      return const Color(0xFF27C46B);
    }
    if (percent >= 50) {
      return const Color(0xFFFF9F1C);
    }
    return const Color(0xFFFF4D4D);
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
