import 'package:flutter/material.dart';

import 'credit_detail_colors.dart';
import '../models/pipeline_models.dart';

class RequestTimelineSection extends StatelessWidget {
  const RequestTimelineSection({super.key, required this.events});

  final List<RequestTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CreditDetailColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Linea de tiempo', style: CreditDetailColors.sectionTitle),
          const SizedBox(height: 16),
          for (var index = 0; index < events.length; index++)
            _TimelineRow(
              event: events[index],
              isLast: index == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final RequestTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final lineColor = event.isFuture
        ? CreditDetailColors.border
        : CreditDetailColors.accent;
    final iconColor = event.isFuture
        ? CreditDetailColors.textSecondary
        : CreditDetailColors.accent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Icon(
                  event.isFuture
                      ? Icons.radio_button_unchecked
                      : Icons.check_circle_outline,
                  color: iconColor,
                  size: 20,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: event.isFuture
                          ? CreditDetailColors.border.withValues(alpha: 0.5)
                          : lineColor,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: CreditDetailColors.valueText.copyWith(
                      color: event.isFuture
                          ? CreditDetailColors.textSecondary
                          : CreditDetailColors.textPrimary,
                    ),
                  ),
                  Text(
                    event.description,
                    style: CreditDetailColors.mutedText,
                  ),
                  if (event.responsible != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.responsible!,
                      style: CreditDetailColors.labelText,
                    ),
                  ],
                  if (event.timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(event.timestamp!),
                      style: CreditDetailColors.labelText.copyWith(
                        color: CreditDetailColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
