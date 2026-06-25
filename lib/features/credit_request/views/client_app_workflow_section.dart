import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'credit_detail_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/pipeline_view_models.dart';

class ClientAppWorkflowSection extends StatelessWidget {
  const ClientAppWorkflowSection({
    super.key,
    required this.viewModel,
    required this.request,
    required this.detail,
    required this.canApprove,
  });

  final CreditRequestDetailViewModel viewModel;
  final SubmittedCreditRequest request;
  final CreditRequestDetail detail;
  final bool canApprove;

  @override
  Widget build(BuildContext context) {
    if (!request.isFromClientApp) {
      return const SizedBox.shrink();
    }

    final status = request.status;
    final isBusy = viewModel.isUpdatingClientAppStatus;
    final checklistReady = detail.clientAppChecklistComplete;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CreditDetailColors.cardDecoration(
        borderColor: CreditDetailColors.accent.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, color: CreditDetailColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Solicitud desde app clientes',
                  style: CreditDetailColors.sectionTitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(status.colorValue).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: Color(status.colorValue),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Gestiona el avance que vera el cliente en su app.',
            style: CreditDetailColors.sectionSubtitle,
          ),
          const SizedBox(height: 16),
          if (status == SolicitudPipelineStatus.pendiente)
            _ActionButton(
              label: 'Iniciar evaluacion',
              icon: Icons.play_arrow_outlined,
              isBusy: isBusy,
              onPressed: () => _confirmAndUpdate(
                context,
                title: 'Iniciar evaluacion',
                message:
                    'El cliente vera que un asesor esta revisando su solicitud.',
                nuevoEstado: 'en_evaluacion',
              ),
            ),
          if (status == SolicitudPipelineStatus.enEvaluacion) ...[
            _ActionButton(
              label: 'Solicitar documentos',
              icon: Icons.folder_open_outlined,
              isBusy: isBusy,
              onPressed: () => _showObservadaDialog(context),
            ),
            const SizedBox(height: 8),
            if (canApprove)
              _ActionButton(
                label: 'Aprobar solicitud',
                icon: Icons.check_circle_outline,
                isBusy: isBusy,
                filled: true,
                onPressed: checklistReady
                    ? () => _showAprobarDialog(context)
                    : null,
              )
            else
              const _InfoBanner(
                icon: Icons.admin_panel_settings_outlined,
                message:
                    'La aprobacion solo la realiza un super operador. '
                    'Completa el checklist y solicita la aprobacion.',
              ),
            if (canApprove && !checklistReady) ...[
              const SizedBox(height: 8),
              const _InfoBanner(
                icon: Icons.checklist_outlined,
                message:
                    'Completa visita, pre-evaluacion APTO y consulta de buro '
                    'antes de aprobar.',
              ),
            ],
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Rechazar solicitud',
              icon: Icons.cancel_outlined,
              isBusy: isBusy,
              destructive: true,
              onPressed: () => _showRechazarDialog(context),
            ),
          ],
          if (status == SolicitudPipelineStatus.observada)
            _ActionButton(
              label: 'Reanudar evaluacion',
              icon: Icons.refresh_outlined,
              isBusy: isBusy,
              onPressed: () => _confirmAndUpdate(
                context,
                title: 'Reanudar evaluacion',
                message:
                    'Indica al cliente que retomaste la revision de su solicitud.',
                nuevoEstado: 'en_evaluacion',
              ),
            ),
          if (status == SolicitudPipelineStatus.aprobada)
            _ActionButton(
              label: 'Marcar desembolsada',
              icon: Icons.account_balance_wallet_outlined,
              isBusy: isBusy,
              filled: true,
              onPressed: () => _confirmAndUpdate(
                context,
                title: 'Confirmar desembolso',
                message:
                    'El cliente vera el credito como desembolsado en su app.',
                nuevoEstado: 'desembolsada',
              ),
            ),
          if (status.isClosed ||
              status == SolicitudPipelineStatus.desembolsada)
            Text(
              'Esta solicitud ya fue cerrada en el flujo de app clientes.',
              style: CreditDetailColors.sectionSubtitle,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndUpdate(
    BuildContext context, {
    required String title,
    required String message,
    required String nuevoEstado,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await viewModel.updateClientAppStatus(nuevoEstado: nuevoEstado);
    if (!context.mounted) return;
    _showResult(context, ok);
  }

  Future<void> _showObservadaDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: 'Sube los documentos faltantes desde la app.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar documentos'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Mensaje para el cliente (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    final nota = controller.text.trim();
    controller.dispose();

    if (confirmed != true || !context.mounted) return;

    final ok = await viewModel.updateClientAppStatus(
      nuevoEstado: 'observada',
      condicionAdicional: nota.isEmpty ? null : nota,
    );
    if (!context.mounted) return;
    _showResult(context, ok);
  }

  Future<void> _showAprobarDialog(BuildContext context) async {
    final montoController = TextEditingController(
      text: request.requestedAmount.toStringAsFixed(2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar solicitud'),
        content: TextField(
          controller: montoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Monto aprobado (S/)',
            helperText:
                'Solicitado: ${formatCurrency(request.requestedAmount)}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      montoController.dispose();
      return;
    }

    final monto = double.tryParse(montoController.text.trim());
    montoController.dispose();

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto aprobado valido.')),
      );
      return;
    }

    final ok = await viewModel.updateClientAppStatus(
      nuevoEstado: 'aprobada',
      montoAprobado: monto,
    );
    if (!context.mounted) return;
    _showResult(context, ok);
  }

  Future<void> _showRechazarDialog(BuildContext context) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Motivo de rechazo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    final motivo = controller.text.trim();
    controller.dispose();

    if (confirmed != true || !context.mounted) return;

    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes indicar el motivo de rechazo.')),
      );
      return;
    }

    final ok = await viewModel.updateClientAppStatus(
      nuevoEstado: 'rechazada',
      motivoRechazo: motivo,
    );
    if (!context.mounted) return;
    _showResult(context, ok);
  }

  void _showResult(BuildContext context, bool ok) {
    final message = ok
        ? viewModel.successMessage
        : viewModel.errorMessage;
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CreditDetailColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: CreditDetailColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: CreditDetailColors.sectionSubtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isBusy,
    this.filled = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final child = isBusy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18);

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isBusy ? null : onPressed,
          icon: child,
          label: Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: child,
        label: Text(label),
        style: destructive
            ? OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF4D4D))
            : null,
      ),
    );
  }
}
