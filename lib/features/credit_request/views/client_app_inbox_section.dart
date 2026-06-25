import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/pipeline_view_models.dart';

class ClientAppInboxSection extends StatelessWidget {
  const ClientAppInboxSection({
    super.key,
    required this.viewModel,
    required this.onTakeCase,
  });

  final ClientAppInboxViewModel viewModel;
  final Future<void> Function(SubmittedCreditRequest request) onTakeCase;

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
          Icon(Icons.error_outline, size: 48, color: Color(0xFFFF4D4D)),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar la bandeja de app clientes.',
            style: const TextStyle(
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
        children: const [
          SizedBox(height: 48),
          Center(
            child: Text(
              'No hay solicitudes pendientes desde la app de clientes.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = viewModel.requests[index];
        final canAssign = request.status == SolicitudPipelineStatus.pendiente;
        final isAssigning = viewModel.assigningId == request.id;
        final statusColor = Color(request.status.colorValue);

        return Card(
          color: AppColors.surfaceContainer,
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
                            'DNI ${request.documentNumber}',
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        request.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${request.expedienteNumber} · '
                  '${formatCurrency(request.requestedAmount)} · '
                  '${request.termMonths} meses',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recibida hace ${request.daysSinceSubmission} dia(s)',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: !canAssign || viewModel.isAssigning
                        ? null
                        : () => onTakeCase(request),
                    icon: isAssigning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                      canAssign ? 'Tomar caso' : 'Esperando envio',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
