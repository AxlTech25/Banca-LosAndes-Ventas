import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../models/credit_request_models.dart';
import '../services/credit_request_gatekeeper.dart';

class CreditSimulatorView extends StatefulWidget {
  const CreditSimulatorView({super.key, required this.session});

  final AuthSession session;

  @override
  State<CreditSimulatorView> createState() => _CreditSimulatorViewState();
}

class _CreditSimulatorViewState extends State<CreditSimulatorView> {
  double _amount = 5000;
  int _termMonths = 12;
  double _tea = 68.5;

  @override
  Widget build(BuildContext context) {
    final installment = estimateInstallment(_amount, _termMonths, _tea);
    final totalPay = installment * _termMonths;
    final financialCost = totalPay - _amount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Simulador de credito'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Calcula cuota sin conexion. Ideal para responder al cliente en campo.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text(
            'Monto: S/ ${_amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: _amount,
            min: 500,
            max: 50000,
            divisions: 99,
            label: _amount.toStringAsFixed(0),
            onChanged: (value) => setState(() => _amount = value),
          ),
          const SizedBox(height: 8),
          const Text(
            'Plazo (meses)',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final term in const [3, 6, 12, 18, 24, 36])
                ChoiceChip(
                  label: Text('$term'),
                  selected: _termMonths == term,
                  onSelected: (_) => setState(() => _termMonths = term),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _MetricCard(
            label: 'Cuota mensual',
            value: 'S/ ${installment.toStringAsFixed(2)}',
            highlight: true,
          ),
          const SizedBox(height: 8),
          _MetricCard(
            label: 'Total a pagar',
            value: 'S/ ${totalPay.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _MetricCard(
            label: 'Costo financiero',
            value: 'S/ ${financialCost.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              CreditRequestGatekeeper.openFromLaunch(
                context,
                session: widget.session,
                launch: CreditRequestLaunchData(
                  documentNumber: '',
                  clientFirstName: '',
                  clientLastName: '',
                  requestedAmount: _amount,
                  termMonths: _termMonths,
                  referenceTea: _tea,
                  creditPurpose: 'Simulacion en campo',
                  source: 'simulator',
                ),
              );
            },
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Crear solicitud con estos datos'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryContainer.withValues(alpha: 0.35)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.primary : AppColors.onSurface,
              fontSize: highlight ? 22 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
