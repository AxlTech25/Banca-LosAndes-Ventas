import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/credit_request_repository.dart';
import '../models/credit_request_models.dart';
import '../services/credit_request_gatekeeper.dart';
import '../viewmodels/credit_request_wizard_view_model.dart';
import 'document_image_viewer.dart';
import 'credit_request_detail_view.dart';
import 'credit_signature_pad.dart';

class CreditRequestWizardView extends StatefulWidget {
  const CreditRequestWizardView({
    super.key,
    required this.session,
    required this.draft,
  });

  final AuthSession session;
  final CreditRequestDraft draft;

  static Future<bool?> openFromLaunch(
    BuildContext context, {
    required AuthSession session,
    required CreditRequestLaunchData launch,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final repository = CreditRequestRepository(
      client: supabase.Supabase.instance.client,
      advisorId: session.advisorId,
      agencyId: session.agencyId,
      preferences: preferences,
    );
    final draft = await repository.createDraft(launch);
    if (!context.mounted) {
      return null;
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreditRequestWizardView(
          session: session,
          draft: draft,
        ),
      ),
    );
  }

  @override
  State<CreditRequestWizardView> createState() =>
      _CreditRequestWizardViewState();
}

class _CreditRequestWizardViewState extends State<CreditRequestWizardView> {
  CreditRequestWizardViewModel? _viewModel;
  late final TextEditingController _documentController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _businessNameController;
  late final TextEditingController _purposeController;
  late final TextEditingController _spouseController;
  late final TextEditingController _guarantorController;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _documentController = TextEditingController(text: draft.documentNumber);
    _firstNameController = TextEditingController(text: draft.clientFirstName);
    _lastNameController = TextEditingController(text: draft.clientLastName);
    _businessNameController = TextEditingController(text: draft.businessName);
    _purposeController = TextEditingController(text: draft.creditPurpose);
    _spouseController = TextEditingController(text: draft.spouseName);
    _guarantorController = TextEditingController(text: draft.guarantorName);
    _initialize();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final viewModel = CreditRequestWizardViewModel(
      repository: CreditRequestRepository(
        client: supabase.Supabase.instance.client,
        advisorId: widget.session.advisorId,
        agencyId: widget.session.agencyId,
        preferences: preferences,
      ),
      draft: widget.draft,
    )..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    _documentController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _businessNameController.dispose();
    _purposeController.dispose();
    _spouseController.dispose();
    _guarantorController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _syncBusinessFields(CreditRequestWizardViewModel viewModel) {
    viewModel.updateBusiness(
      documentNumber: _documentController.text,
      clientFirstName: _firstNameController.text,
      clientLastName: _lastNameController.text,
      businessName: _businessNameController.text,
      spouseName: _spouseController.text,
      guarantorName: _guarantorController.text,
    );
  }

  Future<void> _next(CreditRequestWizardViewModel viewModel) async {
    if (viewModel.currentStep == 0) {
      _syncBusinessFields(viewModel);
      final blocked = await CreditRequestGatekeeper.checkDocumentAndBlock(
        context,
        _documentController.text,
      );
      if (blocked) {
        return;
      }
    } else if (viewModel.currentStep == 1) {
      viewModel.updateCredit(creditPurpose: _purposeController.text);
    }

    final advanced = await viewModel.nextStep();
    if (!advanced && mounted) {
      return;
    }
  }

  Future<void> _submit(CreditRequestWizardViewModel viewModel) async {
    _syncBusinessFields(viewModel);
    viewModel.updateCredit(creditPurpose: _purposeController.text);
    final result = await viewModel.submit();
    if (!mounted || result == null) {
      return;
    }
    if (result.isSuccess) {
      if (result.solicitudId != null && !result.offline) {
        Navigator.of(context).pop();
        await CreditRequestDetailView.open(
          context,
          session: widget.session,
          solicitudId: result.solicitudId!,
        );
      } else {
        Navigator.of(context).pop(true);
      }
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

    final draft = viewModel.draft;
    const stepTitles = [
      'Negocio',
      'Credito',
      'Documentos',
      'Firma y envio',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Solicitud formal'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                for (var index = 0; index < stepTitles.length; index++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: index <= draft.currentStep
                              ? AppColors.primary
                              : AppColors.surfaceContainerHighest,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index <= draft.currentStep
                                  ? AppColors.onPrimaryFixed
                                  : AppColors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stepTitles[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: index <= draft.currentStep
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < stepTitles.length - 1)
                    Container(
                      width: 12,
                      height: 2,
                      color: index < draft.currentStep
                          ? AppColors.primary
                          : AppColors.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
          if (viewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MessageBox(text: viewModel.errorMessage!, isError: true),
            ),
          if (viewModel.successMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MessageBox(text: viewModel.successMessage!),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                switch (draft.currentStep) {
                  0 => _BusinessStep(
                    viewModel: viewModel,
                    documentController: _documentController,
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    businessNameController: _businessNameController,
                    spouseController: _spouseController,
                    guarantorController: _guarantorController,
                    onChanged: () => _syncBusinessFields(viewModel),
                  ),
                  1 => _CreditStep(
                    viewModel: viewModel,
                    purposeController: _purposeController,
                  ),
                  2 => _DocumentsStep(viewModel: viewModel),
                  _ => _ReviewStep(viewModel: viewModel),
                },
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (draft.currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: viewModel.isSubmitting
                            ? null
                            : viewModel.previousStep,
                        child: const Text('Atras'),
                      ),
                    ),
                  if (draft.currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: viewModel.isSubmitting
                          ? null
                          : () {
                              if (draft.currentStep >= 3) {
                                _submit(viewModel);
                              } else {
                                _next(viewModel);
                              }
                            },
                      child: viewModel.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              draft.currentStep >= 3
                                  ? 'Enviar solicitud'
                                  : 'Continuar',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessStep extends StatelessWidget {
  const _BusinessStep({
    required this.viewModel,
    required this.documentController,
    required this.firstNameController,
    required this.lastNameController,
    required this.businessNameController,
    required this.spouseController,
    required this.guarantorController,
    required this.onChanged,
  });

  final CreditRequestWizardViewModel viewModel;
  final TextEditingController documentController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController businessNameController;
  final TextEditingController spouseController;
  final TextEditingController guarantorController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final draft = viewModel.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Datos del cliente y negocio'),
        _textField('Documento (8 digitos)', documentController, onChanged),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField('Nombres', firstNameController, onChanged),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _textField('Apellidos', lastNameController, onChanged),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.businessType,
          dropdownColor: AppColors.surfaceContainer,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: _decoration('Tipo de negocio'),
          items: [
            for (final type in CreditRequestWizardViewModel.businessTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) {
            if (value != null) {
              viewModel.updateBusiness(businessType: value);
            }
          },
        ),
        const SizedBox(height: 12),
        _textField('Nombre del negocio', businessNameController, onChanged),
        const SizedBox(height: 12),
        _SliderField(
          label: 'Antiguedad del negocio (meses)',
          value: draft.businessAgeMonths.toDouble(),
          min: 0,
          max: 120,
          divisions: 120,
          display: '${draft.businessAgeMonths} meses',
          onChanged: (value) =>
              viewModel.updateBusiness(businessAgeMonths: value.round()),
        ),
        _SliderField(
          label: 'Ingresos estimados mensuales',
          value: draft.estimatedIncome,
          min: 500,
          max: 30000,
          divisions: 59,
          display: formatCurrency(draft.estimatedIncome),
          onChanged: (value) => viewModel.updateBusiness(estimatedIncome: value),
        ),
        _SliderField(
          label: 'Gastos mensuales',
          value: draft.monthlyExpenses,
          min: 0,
          max: 15000,
          divisions: 30,
          display: formatCurrency(draft.monthlyExpenses),
          onChanged: (value) =>
              viewModel.updateBusiness(monthlyExpenses: value),
        ),
        _SliderField(
          label: 'Patrimonio estimado',
          value: draft.estimatedAssets,
          min: 0,
          max: 100000,
          divisions: 40,
          display: formatCurrency(draft.estimatedAssets),
          onChanged: (value) => viewModel.updateBusiness(estimatedAssets: value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Tiene conyuge',
            style: TextStyle(color: AppColors.onSurface),
          ),
          value: draft.hasSpouse,
          onChanged: (value) => viewModel.updateBusiness(hasSpouse: value),
        ),
        if (draft.hasSpouse)
          _textField('Nombre del conyuge', spouseController, onChanged),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Tiene garante',
            style: TextStyle(color: AppColors.onSurface),
          ),
          value: draft.hasGuarantor,
          onChanged: (value) => viewModel.updateBusiness(hasGuarantor: value),
        ),
        if (draft.hasGuarantor)
          _textField('Nombre del garante', guarantorController, onChanged),
      ],
    );
  }
}

class _CreditStep extends StatelessWidget {
  const _CreditStep({
    required this.viewModel,
    required this.purposeController,
  });

  final CreditRequestWizardViewModel viewModel;
  final TextEditingController purposeController;

  @override
  Widget build(BuildContext context) {
    final draft = viewModel.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Condiciones del credito'),
        _SliderField(
          label: 'Monto solicitado',
          value: draft.requestedAmount,
          min: 500,
          max: 50000,
          divisions: 99,
          display: formatCurrency(draft.requestedAmount),
          onChanged: (value) =>
              viewModel.updateCredit(requestedAmount: value),
        ),
        _SliderField(
          label: 'Plazo (meses)',
          value: draft.termMonths.toDouble(),
          min: 3,
          max: 36,
          divisions: 33,
          display: '${draft.termMonths} meses',
          onChanged: (value) =>
              viewModel.updateCredit(termMonths: value.round()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.guaranteeType,
          dropdownColor: AppColors.surfaceContainer,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: _decoration('Tipo de garantia'),
          items: [
            for (final type in CreditRequestWizardViewModel.guaranteeTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) {
            if (value != null) {
              viewModel.updateCredit(guaranteeType: value);
            }
          },
        ),
        const SizedBox(height: 12),
        _textField('Destino del credito', purposeController, () {
          viewModel.updateCredit(creditPurpose: purposeController.text);
        }),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuota estimada: ${formatCurrency(draft.estimatedInstallment)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TEA referencial ${draft.referenceTea.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({required this.viewModel});

  final CreditRequestWizardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Documentos requeridos'),
        const Text(
          'Captura fotos claras. DNI anverso y fachada del negocio son obligatorios.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final type in CreditDocumentType.values)
          _DocumentTile(
            type: type,
            attachment: viewModel.documentFor(type),
            required: type == CreditDocumentType.dniFront ||
                type == CreditDocumentType.dniBack ||
                type == CreditDocumentType.businessFacade ||
                type == CreditDocumentType.clientWithAdvisor,
            onCapture: () async {
              final attached = await viewModel.attachDocument(type);
              if (!context.mounted) {
                return;
              }
              if (!attached && viewModel.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(viewModel.errorMessage!)),
                );
              }
            },
            onRemove: () => viewModel.removeDocument(type),
          ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.viewModel});

  final CreditRequestWizardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final draft = viewModel.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Resumen y firma'),
        _SummaryRow('Cliente', draft.clientFullName),
        _SummaryRow('Documento', maskDocument(draft.documentNumber)),
        _SummaryRow('Negocio', draft.businessName),
        _SummaryRow('Monto', formatCurrency(draft.requestedAmount)),
        _SummaryRow('Plazo', '${draft.termMonths} meses'),
        _SummaryRow(
          'Cuota estimada',
          formatCurrency(draft.estimatedInstallment),
        ),
        _SummaryRow('Documentos', '${draft.documents.length} adjuntos'),
        const SizedBox(height: 16),
        const Text(
          'Firma del cliente',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CreditSignaturePad(
          initialValue: draft.signatureBase64,
          onChanged: viewModel.setSignature,
        ),
        const SizedBox(height: 12),
        if (draft.captureLatitude != null && draft.captureLongitude != null)
          Text(
            'Ubicacion capturada: '
            '${draft.captureLatitude!.toStringAsFixed(5)}, '
            '${draft.captureLongitude!.toStringAsFixed(5)}',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          )
        else
          OutlinedButton.icon(
            onPressed: viewModel.captureLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Capturar ubicacion GPS'),
          ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.attachment,
    required this.required,
    required this.onCapture,
    required this.onRemove,
  });

  final CreditDocumentType type;
  final CreditDocumentAttachment? attachment;
  final bool required;
  final Future<void> Function() onCapture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          if (attachment != null)
            GestureDetector(
              onTap: () => DocumentImageViewer.open(
                context,
                title: type.label,
                imagePath: attachment!.localPath,
                onRetake: () {
                  onCapture();
                },
                onDelete: onRemove,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(attachment!.localPath),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  required ? 'Obligatorio' : 'Opcional',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (attachment != null) ...[
                  Text(
                    '${attachment!.sizeKb} KB · nitidez '
                    '${attachment!.sharpnessScore.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: attachment!.isSharpEnough
                          ? const Color(0xFF27C46B)
                          : const Color(0xFFFF4D4D),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
          if (attachment != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
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
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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

Widget _textField(
  String label,
  TextEditingController controller,
  VoidCallback onChanged,
) {
  return TextField(
    controller: controller,
    style: const TextStyle(color: AppColors.onSurface),
    decoration: _decoration(label),
    onChanged: (_) => onChanged(),
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
