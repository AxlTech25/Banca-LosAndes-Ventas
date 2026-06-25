import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pre_evaluation_models.dart';

class DeserterFormSheet extends StatefulWidget {
  const DeserterFormSheet({super.key, required this.clientName});

  final String clientName;

  @override
  State<DeserterFormSheet> createState() => _DeserterFormSheetState();
}

class _DeserterFormSheetState extends State<DeserterFormSheet> {
  static const _reasons = [
    'Cambio de rubro',
    'Cierre temporal del negocio',
    'Migracion a otra entidad',
    'Problemas de salud',
    'Otro',
  ];

  String _reason = _reasons.first;
  String _returnProbability = 'Media';
  final _institutionController = TextEditingController();
  final _observationsController = TextEditingController();

  @override
  void dispose() {
    _institutionController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'Registro de desercion · ${widget.clientName}',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            dropdownColor: AppColors.surfaceContainer,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: _decoration('Motivo de desercion'),
            items: [
              for (final reason in _reasons)
                DropdownMenuItem(value: reason, child: Text(reason)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _reason = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _institutionController,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: _decoration('Institucion a la que migro (opcional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _returnProbability,
            dropdownColor: AppColors.surfaceContainer,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: _decoration('Probabilidad de retorno'),
            items: const [
              DropdownMenuItem(value: 'Alta', child: Text('Alta')),
              DropdownMenuItem(value: 'Media', child: Text('Media')),
              DropdownMenuItem(value: 'Baja', child: Text('Baja')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _returnProbability = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observationsController,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: _decoration('Observaciones'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                DeserterFormData(
                  reason: _reason,
                  migratedInstitution: _institutionController.text.trim(),
                  returnProbability: _returnProbability,
                  observations: _observationsController.text.trim(),
                ),
              );
            },
            child: const Text('Guardar registro'),
          ),
        ],
      ),
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
}
