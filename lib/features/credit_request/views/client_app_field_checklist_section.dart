import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'credit_detail_colors.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/pipeline_view_models.dart';

class ClientAppFieldChecklistSection extends StatelessWidget {
  const ClientAppFieldChecklistSection({
    super.key,
    required this.viewModel,
    required this.detail,
    required this.onConsultBureau,
    required this.bureauLoading,
  });

  final CreditRequestDetailViewModel viewModel;
  final CreditRequestDetail detail;
  final VoidCallback? onConsultBureau;
  final bool bureauLoading;

  @override
  Widget build(BuildContext context) {
    final preEval = detail.preEvaluation;
    final bureau = detail.bureauConsult;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CreditDetailColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checklist de evaluacion en campo',
            style: CreditDetailColors.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Completa visita, pre-evaluacion y buro antes de la aprobacion.',
            style: CreditDetailColors.sectionSubtitle,
          ),
          const SizedBox(height: 16),
          _ChecklistStep(
            done: detail.visitCompleted,
            title: 'Visita en campo',
            subtitle: detail.visitCompleted
                ? 'Visita registrada con coordenadas.'
                : 'Registra la visita al negocio del cliente.',
            actionLabel: detail.visitCompleted ? null : 'Registrar visita',
            actionBusy: viewModel.isRegisteringVisit,
            onAction: detail.visitCompleted
                ? null
                : () => _registerVisit(context),
          ),
          const SizedBox(height: 12),
          _ChecklistStep(
            done: preEval?.isApto == true,
            title: 'Pre-evaluacion',
            subtitle: preEval == null
                ? 'Ejecuta la pre-evaluacion con los datos de la solicitud.'
                : '${preEval.calificacion}${preEval.puntaje != null ? ' · puntaje ${preEval.puntaje}' : ''}',
            actionLabel: preEval?.isApto == true ? null : 'Ejecutar pre-evaluacion',
            actionBusy: viewModel.isRunningPreEvaluation,
            onAction: preEval?.isApto == true
                ? null
                : () => _runPreEvaluation(context),
          ),
          if (preEval != null && !preEval.isApto) ...[
            const SizedBox(height: 4),
            Text(
              preEval.motivo,
              style: const TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _ChecklistStep(
            done: bureau != null,
            title: 'Consulta de buro',
            subtitle: bureau == null
                ? 'Consulta el historial crediticio del cliente.'
                : '${bureau.rating.label} · ${bureau.debtEntities} entidad(es) · '
                    'S/ ${bureau.totalDebtPen.toStringAsFixed(2)}',
            actionLabel: bureau == null ? 'Consultar buro' : null,
            actionBusy: bureauLoading,
            onAction: bureau == null ? onConsultBureau : null,
          ),
        ],
      ),
    );
  }

  Future<void> _registerVisit(BuildContext context) async {
    Position? position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (_) {
      // GPS opcional: se registra visita sin coordenadas.
    }

    final ok = await viewModel.registerClientAppVisit(
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (!context.mounted) return;
    _showSnackBar(context, ok);
  }

  Future<void> _runPreEvaluation(BuildContext context) async {
    final ok = await viewModel.runPreEvaluation();
    if (!context.mounted) return;
    _showSnackBar(context, ok);
  }

  void _showSnackBar(BuildContext context, bool ok) {
    final message = ok
        ? viewModel.successMessage
        : viewModel.errorMessage;
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ChecklistStep extends StatelessWidget {
  const _ChecklistStep({
    required this.done,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionBusy = false,
    this.onAction,
  });

  final bool done;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final bool actionBusy;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? const Color(0xFF27C46B) : CreditDetailColors.textSecondary,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CreditDetailColors.valueText,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: CreditDetailColors.sectionSubtitle,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: actionBusy ? null : onAction,
                  child: actionBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
