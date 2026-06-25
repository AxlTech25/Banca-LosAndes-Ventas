import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum SbsRating {
  normal('Normal', Color(0xFF27C46B), 'Sin observaciones'),
  cpp('CPP', Color(0xFFFFC857), 'Requiere atencion'),
  deficient('Deficiente', Color(0xFFFF9F1C), 'Requiere comite especial'),
  doubtful('Dudoso', Color(0xFFFF4D4D), 'Alto riesgo'),
  loss('Perdida', Color(0xFF4A5568), 'No procede evaluacion');

  const SbsRating(this.label, this.color, this.description);

  final String label;
  final Color color;
  final String description;

  static SbsRating fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      'cpp' || 'con problemas potenciales' => SbsRating.cpp,
      'deficiente' => SbsRating.deficient,
      'dudoso' => SbsRating.doubtful,
      'perdida' || 'pérdida' => SbsRating.loss,
      _ => SbsRating.normal,
    };
  }
}

class RiskSemaphore extends StatelessWidget {
  const RiskSemaphore({super.key, required this.rating, this.compact = false});

  final SbsRating rating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: rating.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rating.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: rating.color, size: compact ? 10 : 12),
          SizedBox(width: compact ? 6 : 8),
          Text(
            compact ? rating.label : '${rating.label} · ${rating.description}',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
