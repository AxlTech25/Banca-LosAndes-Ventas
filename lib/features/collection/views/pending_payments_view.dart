import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/pending_payments_repository.dart';
import '../models/pending_payment_models.dart';
import '../viewmodels/pending_payments_view_model.dart';

class PendingPaymentsView extends StatefulWidget {
  const PendingPaymentsView({super.key, required this.session});

  final AuthSession session;

  @override
  State<PendingPaymentsView> createState() => _PendingPaymentsViewState();
}

class _PendingPaymentsViewState extends State<PendingPaymentsView> {
  PendingPaymentsViewModel? _viewModel;

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
    final viewModel = PendingPaymentsViewModel(
      repository: PendingPaymentsRepository(
        client: Supabase.instance.client,
        advisorId: widget.session.advisorId,
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
    if (mounted) setState(() {});
  }

  Future<void> _confirm(PendingClientPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          'Confirmar el pago de ${formatCurrency(payment.monto)} '
          'via ${payment.metodoLabel} de ${payment.clientName}?',
        ),
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

    if (confirmed != true || !mounted) return;

    final ok = await _viewModel!.confirm(payment);
    if (!mounted) return;
    _showFeedback(ok);
  }

  Future<void> _reject(PendingClientPayment payment) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar pago'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ej. No se encontro el abono en el banco',
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

    if (confirmed != true || !mounted) return;

    final ok = await _viewModel!.reject(payment, motivo: motivo.isEmpty ? null : motivo);
    if (!mounted) return;
    _showFeedback(ok);
  }

  void _showFeedback(bool ok) {
    final viewModel = _viewModel;
    if (viewModel == null) return;

    final message = ok ? viewModel.successMessage : viewModel.errorMessage;
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Pagos pendientes'),
      ),
      body: viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: _buildBody(viewModel),
            ),
    );
  }

  Widget _buildBody(PendingPaymentsViewModel viewModel) {
    if (viewModel.isLoading && viewModel.payments.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && viewModel.payments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.error_outline, color: Color(0xFFFF4D4D), size: 48),
          const SizedBox(height: 16),
          Text(
            viewModel.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      );
    }

    if (viewModel.payments.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 48),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay pagos pendientes de confirmacion desde la app de clientes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final payment = viewModel.payments[index];
        final isProcessing = viewModel.processingId == payment.id;

        return Card(
          color: AppColors.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.clientName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DNI ${payment.documentNumber}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  formatCurrency(payment.monto),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${payment.metodoLabel} · ${payment.tipo} · '
                  '${payment.producto ?? 'Credito'}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                if (payment.referencia.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ref: ${payment.referencia}',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: viewModel.isProcessing || isProcessing
                            ? null
                            : () => _reject(payment),
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: viewModel.isProcessing || isProcessing
                            ? null
                            : () => _confirm(payment),
                        child: isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
