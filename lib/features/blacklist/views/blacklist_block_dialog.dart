import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/blacklist_entry.dart';

class BlacklistBlockDialog extends StatelessWidget {
  const BlacklistBlockDialog({super.key, required this.entry});

  final BlacklistEntry entry;

  static Future<void> show(BuildContext context, BlacklistEntry entry) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlacklistBlockDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A0F12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFF4D4D)),
      ),
      icon: const Icon(Icons.block, color: Color(0xFFFF4D4D), size: 40),
      title: const Text(
        'Cliente en lista negra',
        style: TextStyle(color: Color(0xFFFF4D4D)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DNI ${entry.documentNumber} tiene restriccion activa.',
            style: const TextStyle(color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          Text(
            entry.reason,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Fuente: ${entry.source}',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No puede abrir ni continuar una solicitud de credito para este cliente.',
            style: TextStyle(
              color: Color(0xFFFF4D4D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D4D),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
