import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../../credit_request/models/credit_request_models.dart';
import '../../credit_request/services/credit_request_gatekeeper.dart';
import '../data/prospection_repository.dart';
import '../models/pre_evaluation_models.dart';
import '../viewmodels/pre_evaluation_view_model.dart';

class PreEvaluationView extends StatefulWidget {
  const PreEvaluationView({super.key, required this.session});

  final AuthSession session;

  @override
  State<PreEvaluationView> createState() => _PreEvaluationViewState();
}

class _PreEvaluationViewState extends State<PreEvaluationView> {
  PreEvaluationViewModel? _viewModel;
  final _purposeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final viewModel = PreEvaluationViewModel(
      repository: ProspectionRepository(
        client: supabase.Supabase.instance.client,
        advisorId: widget.session.advisorId,
        preferences: preferences,
      ),
    )..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
  }

  @override
  void dispose() {
    _viewModel
      ?..removeListener(_onChanged)
      ..dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickBirthDate() async {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      viewModel.birthDate = picked;
      viewModel.resetResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final result = viewModel.result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Pre-evaluacion en campo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (viewModel.validationError != null)
            _MessageBox(text: viewModel.validationError!, isError: true),
          if (result != null) ...[
            _ResultCard(
              result: result,
              onStartRequest: result.status == PreEvaluationStatus.apto
                  ? () {
                      CreditRequestGatekeeper.openFromLaunch(
                        context,
                        session: widget.session,
                        launch: CreditRequestLaunchData.fromProspect(
                          ProspectFormData(
                            documentNumber: viewModel.documentNumber.trim(),
                            firstName: viewModel.firstName.trim(),
                            lastName: viewModel.lastName.trim(),
                            birthDate: viewModel.birthDate!,
                            businessType: viewModel.businessType,
                            businessAgeYears: viewModel.businessAgeYears,
                            businessAgeMonths: viewModel.businessAgeMonths,
                            estimatedIncome: viewModel.estimatedIncome,
                            monthlyExpenses: viewModel.monthlyExpenses,
                            requestedAmount: viewModel.requestedAmount,
                            termMonths: viewModel.termMonths,
                            creditPurpose: viewModel.creditPurpose.trim(),
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                viewModel.resetResult();
                _purposeController.clear();
              },
              child: const Text('Nueva pre-evaluacion'),
            ),
            const SizedBox(height: 24),
          ],
          if (result == null) ...[
            _FieldLabel('Documento (8 digitos)'),
            TextField(
              keyboardType: TextInputType.number,
              maxLength: 8,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Ej. 87654321'),
              onChanged: (value) {
                viewModel.documentNumber = value;
                viewModel.resetResult();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Nombres'),
                      TextField(
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: _inputDecoration('Nombres'),
                        onChanged: (value) {
                          viewModel.firstName = value;
                          viewModel.resetResult();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Apellidos'),
                      TextField(
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: _inputDecoration('Apellidos'),
                        onChanged: (value) {
                          viewModel.lastName = value;
                          viewModel.resetResult();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Fecha de nacimiento'),
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                viewModel.birthDate == null
                    ? 'Seleccionar fecha'
                    : _formatDate(viewModel.birthDate!),
              ),
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Tipo de negocio'),
            DropdownButtonFormField<String>(
              initialValue: viewModel.businessType,
              dropdownColor: AppColors.surfaceContainer,
              style: const TextStyle(color: AppColors.onSurface),
              items: [
                for (final type in PreEvaluationViewModel.businessTypes)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) {
                if (value != null) {
                  viewModel.businessType = value;
                  viewModel.resetResult();
                }
              },
              decoration: _inputDecoration('Tipo de negocio'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Antiguedad (anos)'),
                      TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: _inputDecoration('0'),
                        onChanged: (value) {
                          viewModel.businessAgeYears = int.tryParse(value) ?? 0;
                          viewModel.resetResult();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Meses'),
                      TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: _inputDecoration('0'),
                        onChanged: (value) {
                          viewModel.businessAgeMonths =
                              int.tryParse(value) ?? 0;
                          viewModel.resetResult();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Ingresos estimados mensuales'),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('S/ 2500'),
              onChanged: (value) {
                viewModel.estimatedIncome = double.tryParse(value) ?? 0;
                viewModel.resetResult();
              },
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Gastos mensuales del negocio'),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration(
                'S/ 0 = estimar 40% de ingresos',
              ),
              onChanged: (value) {
                viewModel.monthlyExpenses = double.tryParse(value) ?? 0;
                viewModel.resetResult();
              },
            ),
            const SizedBox(height: 12),
            _FieldLabel('Plazo: ${viewModel.termMonths} meses'),
            Slider(
              value: viewModel.termMonths.toDouble(),
              min: 3,
              max: 36,
              divisions: 33,
              label: '${viewModel.termMonths}',
              onChanged: (value) {
                viewModel.termMonths = value.round();
                viewModel.resetResult();
              },
            ),
            const SizedBox(height: 12),
            _FieldLabel(
              'Monto solicitado: ${formatCurrency(viewModel.requestedAmount)}',
            ),
            Slider(
              value: viewModel.requestedAmount,
              min: 500,
              max: 50000,
              divisions: 99,
              label: formatCurrency(viewModel.requestedAmount),
              onChanged: (value) {
                viewModel.requestedAmount = value;
                viewModel.resetResult();
              },
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Destino del credito'),
            TextField(
              controller: _purposeController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Describe el destino del credito'),
              onChanged: (value) {
                viewModel.creditPurpose = value;
                viewModel.resetResult();
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: viewModel.canSubmit ? viewModel.submit : null,
              icon: viewModel.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('Pre-evaluar'),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFF4D4D) : AppColors.primary,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, this.onStartRequest});

  final PreEvaluationResult result;
  final VoidCallback? onStartRequest;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForStatus(result.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.status.label,
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.reason,
            style: const TextStyle(color: AppColors.onSurface),
          ),
          if (result.estimatedScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'Puntaje estimado: ${result.estimatedScore}',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
          if (result.pendingSync) ...[
            const SizedBox(height: 8),
            const Text(
              'Pendiente de sincronizacion',
              style: TextStyle(color: AppColors.primary, fontSize: 12),
            ),
          ],
          if (onStartRequest != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onStartRequest,
              child: const Text('Iniciar solicitud formal'),
            ),
          ] else if (result.status == PreEvaluationStatus.revisar) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Registrar observaciones'),
            ),
          ] else if (result.status == PreEvaluationStatus.noProcede) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Informar al cliente'),
            ),
          ],
        ],
      ),
    );
  }

  _ResultColors _colorsForStatus(PreEvaluationStatus status) {
    return switch (status) {
      PreEvaluationStatus.apto => const _ResultColors(
        background: Color(0xFF1A3D2E),
        border: Color(0xFF27C46B),
        text: Color(0xFF27C46B),
      ),
      PreEvaluationStatus.revisar => const _ResultColors(
        background: Color(0xFF3D341A),
        border: Color(0xFFFFC857),
        text: Color(0xFFFFC857),
      ),
      PreEvaluationStatus.noProcede => const _ResultColors(
        background: Color(0xFF3D1A1A),
        border: Color(0xFFFF4D4D),
        text: Color(0xFFFF4D4D),
      ),
      PreEvaluationStatus.pending => const _ResultColors(
        background: Color(0xFF1C2B3C),
        border: Color(0xFF89D9FF),
        text: Color(0xFF89D9FF),
      ),
    };
  }
}

class _ResultColors {
  const _ResultColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}
