import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../../credit_request/data/credit_pipeline_repository.dart';
import '../../credit_request/models/pipeline_models.dart';
import '../../credit_request/views/credit_request_detail_view.dart';
import '../viewmodels/field_committee_view_model.dart';

class FieldCommitteeView extends StatefulWidget {
  const FieldCommitteeView({super.key, required this.session});

  final AuthSession session;

  @override
  State<FieldCommitteeView> createState() => _FieldCommitteeViewState();
}

class _FieldCommitteeViewState extends State<FieldCommitteeView> {
  FieldCommitteeViewModel? _viewModel;

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
    final viewModel = FieldCommitteeViewModel(
      repository: CreditPipelineRepository(
        client: supabase.Supabase.instance.client,
        advisorId: widget.session.advisorId,
        preferences: preferences,
      ),
      role: widget.session.role,
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

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Comite en campo'),
      ),
      body: viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    viewModel.isAgencyWide
                        ? 'Expedientes en evaluacion de toda la agencia'
                        : 'Tus solicitudes enviadas al comite',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: viewModel.updateSearch,
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente, expediente o asesor',
                      hintStyle:
                          const TextStyle(color: AppColors.onSurfaceVariant),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                  ),
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      viewModel.errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF4D4D)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (viewModel.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (viewModel.filteredRequests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'No hay expedientes pendientes de comite.',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ...viewModel.filteredRequests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommitteeRequestCard(
                          request: request,
                          showAdvisor: viewModel.isAgencyWide,
                          onTap: () => CreditRequestDetailView.open(
                            context,
                            session: widget.session,
                            solicitudId: request.id,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CommitteeRequestCard extends StatelessWidget {
  const _CommitteeRequestCard({
    required this.request,
    required this.showAdvisor,
    required this.onTap,
  });

  final SubmittedCreditRequest request;
  final bool showAdvisor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(request.status.colorValue);

    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.clientName,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      request.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${request.expedienteNumber} · S/ ${request.requestedAmount.toStringAsFixed(0)} · ${request.daysSinceSubmission} dias',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              if (showAdvisor && request.advisorName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Asesor: ${request.advisorName}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (request.assignedAnalyst != null &&
                  request.assignedAnalyst!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Analista: ${request.assignedAnalyst}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
