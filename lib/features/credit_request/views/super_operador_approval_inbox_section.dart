import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/pipeline_view_models.dart';

class SuperOperadorApprovalInboxSection extends StatelessWidget {
  const SuperOperadorApprovalInboxSection({
    super.key,
    required this.viewModel,
    required this.onOpenRequest,
  });

  final SuperOperadorApprovalInboxViewModel viewModel;
  final Future<void> Function(PendingApprovalItem item) onOpenRequest;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.requests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && viewModel.requests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF4D4D)),
          const SizedBox(height: 16),
          const Text(
            'No se pudo cargar la bandeja de aprobacion.',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.errorMessage!,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (viewModel.requests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 48),
          Icon(Icons.verified_outlined, size: 48, color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'No hay solicitudes en evaluacion en su agencia.',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Cuando un asesor complete visita, pre-evaluacion APTO y buro, '
            'la solicitud aparecera aqui para su aprobacion.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final readyCount = viewModel.readyCount;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.requests.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HeaderBanner(readyCount: readyCount);
        }

        final item = viewModel.requests[index - 1];
        return _ApprovalCard(
          item: item,
          onOpen: () => onOpenRequest(item),
        );
      },
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.readyCount});

  final int readyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              readyCount > 0
                  ? '$readyCount solicitud(es) lista(s) para aprobar. '
                      'Revise el expediente y confirme el monto.'
                  : 'Hay solicitudes en evaluacion pendientes de checklist '
                      'por parte del asesor.',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.onOpen,
  });

  final PendingApprovalItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final request = item.request;
    final ready = item.isReadyForApproval;

    return Card(
      color: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: ready
            ? BorderSide(color: const Color(0xFF27C46B).withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.clientName,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.expedienteNumber} · DNI ${request.documentNumber}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (request.advisorName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Asesor: ${request.advisorName}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (ready ? const Color(0xFF27C46B) : const Color(0xFFFF9800))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ready ? 'Lista' : 'En preparacion',
                    style: TextStyle(
                      color: ready ? const Color(0xFF27C46B) : const Color(0xFFFF9800),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${formatCurrency(request.requestedAmount)} · ${request.termMonths} meses',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _ChecklistRow(
              visitDone: item.visitCompleted,
              preEvalDone: item.preEvalApto,
              preEvalScore: item.preEvalScore,
              bureauDone: item.hasBureau,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: Icon(ready ? Icons.check_circle_outline : Icons.visibility_outlined),
                label: Text(ready ? 'Revisar y aprobar' : 'Ver expediente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.visitDone,
    required this.preEvalDone,
    required this.bureauDone,
    this.preEvalScore,
  });

  final bool visitDone;
  final bool preEvalDone;
  final bool bureauDone;
  final int? preEvalScore;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _Chip(
          done: visitDone,
          label: 'Visita',
        ),
        _Chip(
          done: preEvalDone,
          label: preEvalDone && preEvalScore != null
              ? 'Pre-eval $preEvalScore'
              : 'Pre-eval',
        ),
        _Chip(
          done: bureauDone,
          label: 'Buro',
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF27C46B).withValues(alpha: 0.12)
            : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: done ? const Color(0xFF27C46B) : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: done ? const Color(0xFF27C46B) : AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
