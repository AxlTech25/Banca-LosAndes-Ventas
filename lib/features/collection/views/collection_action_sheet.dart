import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/collection_models.dart';
import '../viewmodels/collection_board_view_model.dart';

class CollectionActionSheet extends StatefulWidget {
  const CollectionActionSheet({super.key, required this.client});

  final OverdueClientEntry client;

  @override
  State<CollectionActionSheet> createState() => _CollectionActionSheetState();
}

class _CollectionActionSheetState extends State<CollectionActionSheet> {
  final _viewModel = CollectionActionViewModel();
  final _observationsController = TextEditingController();

  @override
  void dispose() {
    _viewModel.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _pickCommitmentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      _viewModel.setCommitmentDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final form = _viewModel.buildForm();
        final validation = form.validate();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gestion de cobranza · ${widget.client.clientName}',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.client.daysPastDue} dias de mora · '
                '${formatCurrency(widget.client.overdueAmount)}',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CollectionManagementType>(
                initialValue: _viewModel.managementType,
                dropdownColor: AppColors.surfaceContainer,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: _decoration('Tipo de gestion'),
                items: [
                  for (final type in CollectionManagementType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _viewModel.setManagementType(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CollectionResultType>(
                initialValue: _viewModel.result,
                dropdownColor: AppColors.surfaceContainer,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: _decoration('Resultado'),
                items: [
                  for (final type in CollectionResultType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _viewModel.setResult(value);
                  }
                },
              ),
              if (_viewModel.result.requiresPaymentAmount) ...[
                const SizedBox(height: 12),
                _SliderField(
                  label: 'Monto pagado',
                  value: _viewModel.amountPaid,
                  min: 0,
                  max: widget.client.overdueAmount * 1.2,
                  display: formatCurrency(_viewModel.amountPaid),
                  onChanged: _viewModel.setAmountPaid,
                ),
              ],
              if (_viewModel.result.requiresCommitment) ...[
                const SizedBox(height: 12),
                _SliderField(
                  label: 'Monto compromiso',
                  value: _viewModel.commitmentAmount,
                  min: 0,
                  max: widget.client.overdueAmount,
                  display: formatCurrency(_viewModel.commitmentAmount),
                  onChanged: _viewModel.setCommitmentAmount,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickCommitmentDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _viewModel.commitmentDate == null
                        ? 'Fecha de compromiso'
                        : 'Compromiso: ${_formatDate(_viewModel.commitmentDate!)}',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _observationsController,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: _decoration('Observaciones'),
                onChanged: _viewModel.setObservations,
              ),
              if (validation != null) ...[
                const SizedBox(height: 8),
                Text(
                  validation,
                  style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: validation == null
                    ? () => Navigator.of(context).pop(form)
                    : null,
                child: const Text('Registrar gestion'),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= min ? min + 100 : max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
        Text(
          display,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        Slider(
          value: value.clamp(min, safeMax),
          min: min,
          max: safeMax,
          divisions: 20,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
