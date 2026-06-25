import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/risk_semaphore.dart';
import '../../../shell/web/web_shell_widgets.dart';
import '../../auth/models/auth_session.dart';
import '../data/credit_pipeline_repository.dart';
import '../models/pipeline_models.dart';
import '../services/request_status_pdf_service.dart';
import '../services/request_timeline_builder.dart';
import '../services/document_storage_service.dart';
import '../services/transmission_checklist.dart';
import '../services/transmission_progress_service.dart';
import '../viewmodels/pipeline_view_models.dart';
import 'client_app_field_checklist_section.dart';
import 'client_app_workflow_section.dart';
import 'credit_detail_colors.dart';
import 'credit_signature_pad.dart';
import 'request_timeline_section.dart';
import 'solicitud_chat_view.dart';
import 'web_credit_request_detail_layout.dart';
import 'stored_credit_document_gallery.dart';

class CreditRequestDetailView extends StatefulWidget {
  const CreditRequestDetailView({
    super.key,
    required this.session,
    required this.solicitudId,
  });

  final AuthSession session;
  final String solicitudId;

  static Future<void> open(
    BuildContext context, {
    required AuthSession session,
    required String solicitudId,
  }) {
    final page = CreditRequestDetailView(
      session: session,
      solicitudId: solicitudId,
    );

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => kIsWeb ? WebEmbeddedTheme(child: page) : page,
      ),
    );
  }

  @override
  State<CreditRequestDetailView> createState() =>
      _CreditRequestDetailViewState();
}

class _CreditRequestDetailViewState extends State<CreditRequestDetailView> {
  CreditRequestDetailViewModel? _viewModel;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;
    final viewModel = CreditRequestDetailViewModel(
      repository: CreditPipelineRepository(
        client: client,
        advisorId: widget.session.advisorId,
        preferences: preferences,
      ),
      transmissionService: TransmissionProgressService(
        storageService: DocumentStorageService(client: client),
      ),
      solicitudId: widget.solicitudId,
    )..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
    await viewModel.load();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openBureauConsent() async {
    final viewModel = _viewModel;
    if (viewModel == null || viewModel.detail == null) {
      return;
    }

    final signature = kIsWeb
        ? await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Consentimiento consulta buró'),
              content: SizedBox(
                width: 480,
                child: _BureauConsentSheet(
                  clientName: viewModel.detail!.request.clientName,
                  documentNumber: viewModel.detail!.request.documentNumber,
                ),
              ),
            ),
          )
        : await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: CreditDetailColors.cardBg,
            builder: (context) => _BureauConsentSheet(
              clientName: viewModel.detail!.request.clientName,
              documentNumber: viewModel.detail!.request.documentNumber,
            ),
          );

    if (signature == null || signature.isEmpty) {
      return;
    }

    await viewModel.consultBureau(signature);
  }

  Future<void> _transmit() async {
    final viewModel = _viewModel;
    if (viewModel == null || viewModel.detail == null) {
      return;
    }

    final checklist = TransmissionChecklist.evaluate(viewModel.detail!);
    if (!checklist.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete el checklist: '
            '${checklist.pendingItems.map((item) => item.label).join(', ')}.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transmitir solicitud'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Verifique el checklist obligatorio antes de enviar al back office:',
              ),
              const SizedBox(height: 12),
              for (final item in checklist.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.isComplete
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: item.isComplete
                            ? const Color(0xFF27C46B)
                            : const Color(0xFFFF4D4D),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.detail == null
                              ? item.label
                              : '${item.label}\n${item.detail}',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transmitir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final progress = ValueNotifier<(TransmissionStep?, int, int)>((null, 0, 5));

    if (!mounted) {
      return;
    }

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) {
            final (step, current, total) = value;
            final stepProgress = total == 0 ? null : current / total;
            return AlertDialog(
              title: const Text('Transmitiendo solicitud'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: stepProgress),
                  const SizedBox(height: 16),
                  Text(step?.label ?? 'Preparando transmision...'),
                  if (total > 0)
                    Text(
                      'Paso $current de $total',
                      style: TextStyle(
                        color: CreditDetailColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    final success = await viewModel.transmit(
      onProgress: (step, current, total) {
        progress.value = (step, current, total);
      },
    );

    progress.dispose();
    if (mounted) {
      Navigator.of(context).pop();
    }
    await dialogFuture;

    if (!mounted) {
      return;
    }

    final message = success
        ? viewModel.successMessage
        : viewModel.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _shareStatusPdf(SubmittedCreditRequest request) async {
    try {
      await RequestStatusPdfService.shareStatusSheet(request);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _saveInternalNote() async {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }

    final saved = await viewModel.addInternalNote(_noteController.text);
    if (!mounted) {
      return;
    }
    if (saved) {
      _noteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.successMessage ?? 'Nota guardada.')),
      );
    } else if (viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage!)),
      );
    }
  }

  Future<void> _openChat(SubmittedCreditRequest request) async {
    await SolicitudChatView.open(
      context,
      session: widget.session,
      solicitudId: widget.solicitudId,
      clienteId: request.clientId,
      expedienteNumber: request.expedienteNumber,
      clientName: request.clientName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final detail = viewModel?.detail;
    final isWeb = kIsWeb;

    Widget scaffold = Scaffold(
      backgroundColor: CreditDetailColors.scaffoldBg,
      appBar: isWeb
          ? null
          : AppBar(
              backgroundColor: CreditDetailColors.scaffoldBg,
              foregroundColor: CreditDetailColors.textPrimary,
              title: const Text('Detalle de solicitud'),
              actions: [
                if (detail != null)
                  IconButton(
                    onPressed: () => _openChat(detail.request),
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Chat con cliente',
                  ),
                if (detail != null)
                  IconButton(
                    onPressed: () => _shareStatusPdf(detail.request),
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Compartir estado',
                  ),
              ],
            ),
      body: viewModel == null || viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? Center(
              child: Text(
                'No se encontro la solicitud.',
                style: TextStyle(color: CreditDetailColors.textSecondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWeb)
                  WebCreditRequestDetailHeader(
                    expedienteNumber: detail.request.expedienteNumber,
                    clientName: detail.request.clientName,
                    statusLabel: detail.request.status.label,
                    statusColor: Color(detail.request.status.colorValue),
                    operatorName: widget.session.displayName,
                  ),
                if (isWeb)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openChat(detail.request),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Chat'),
                        ),
                        TextButton.icon(
                          onPressed: () => _shareStatusPdf(detail.request),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Compartir'),
                        ),
                        IconButton(
                          onPressed: viewModel.load,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualizar',
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: viewModel.load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isWeb ? 24 : 16),
                      child: isWeb
                          ? WebCreditRequestDetailLayout(
                              primarySections: _primarySections(
                                viewModel: viewModel,
                                detail: detail,
                              ),
                              secondarySections: _secondarySections(
                                viewModel: viewModel,
                                detail: detail,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ..._primarySections(
                                  viewModel: viewModel,
                                  detail: detail,
                                ),
                                const SizedBox(height: 16),
                                ..._secondarySections(
                                  viewModel: viewModel,
                                  detail: detail,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );

    return scaffold;
  }

  List<Widget> _primarySections({
    required CreditRequestDetailViewModel viewModel,
    required CreditRequestDetail detail,
  }) {
    return [
      if (viewModel.errorMessage != null)
        _MessageBox(text: viewModel.errorMessage!, isError: true),
      if (viewModel.successMessage != null)
        _MessageBox(text: viewModel.successMessage!),
      _HeaderCard(request: detail.request),
      if (detail.request.isFromClientApp) ...[
        ClientAppFieldChecklistSection(
          viewModel: viewModel,
          detail: detail,
          onConsultBureau: detail.bureauConsult == null &&
                  !viewModel.isConsultingBureau
              ? _openBureauConsent
              : null,
          bureauLoading: viewModel.isConsultingBureau,
        ),
        ClientAppWorkflowSection(
          viewModel: viewModel,
          request: detail.request,
          detail: detail,
          canApprove: widget.session.role.canApproveClientAppRequests,
        ),
      ],
      if (detail.request.hasResolution ||
          detail.request.status.isTrackable)
        _ResolutionSection(request: detail.request),
      if (!detail.request.isFromClientApp)
        _BureauSection(
          consult: detail.bureauConsult,
          onConsult: detail.bureauConsult == null &&
                  !viewModel.isConsultingBureau
              ? _openBureauConsent
              : null,
          isLoading: viewModel.isConsultingBureau,
        ),
      if (detail.request.status.canTransmit &&
          !detail.request.isFromClientApp)
        _TransmissionChecklistSection(detail: detail),
      if (detail.request.status.canTransmit &&
          !detail.request.isFromClientApp)
        FilledButton.icon(
          onPressed: viewModel.isTransmitting ||
                  !TransmissionChecklist.evaluate(detail).isReady
              ? null
              : _transmit,
          icon: viewModel.isTransmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: const Text('Transmitir al back office'),
        ),
    ];
  }

  List<Widget> _secondarySections({
    required CreditRequestDetailViewModel viewModel,
    required CreditRequestDetail detail,
  }) {
    return [
      _DocumentsSection(documents: detail.documents),
      _ClientChatCard(
        clientName: detail.request.clientName,
        onOpen: () => _openChat(detail.request),
      ),
      RequestTimelineSection(
        events: RequestTimelineBuilder.build(detail),
      ),
      _AddInternalNoteSection(
        controller: _noteController,
        isSaving: viewModel.isSavingNote,
        onSave: _saveInternalNote,
      ),
      if (detail.internalNotes.isNotEmpty)
        _InternalNotesSection(notes: detail.internalNotes),
    ];
  }
}

class _BureauConsentSheet extends StatefulWidget {
  const _BureauConsentSheet({
    required this.clientName,
    required this.documentNumber,
  });

  final String clientName;
  final String documentNumber;

  @override
  State<_BureauConsentSheet> createState() => _BureauConsentSheetState();
}

class _BureauConsentSheetState extends State<_BureauConsentSheet> {
  String? _signature;

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
            'Consentimiento consulta buró',
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.clientName} autoriza la consulta de su historial '
            'crediticio (DNI ${maskDocument(widget.documentNumber)}) '
            'en el buró de creditos.',
            style: TextStyle(color: CreditDetailColors.textSecondary),
          ),
          const SizedBox(height: 16),
          CreditSignaturePad(
            onChanged: (value) => setState(() => _signature = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _signature == null || _signature!.isEmpty
                ? null
                : () => Navigator.of(context).pop(_signature),
            child: const Text('Consultar buró'),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.request});

  final SubmittedCreditRequest request;

  @override
  Widget build(BuildContext context) {
    final color = Color(request.status.colorValue);
    final isWeb = kIsWeb;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: CreditDetailColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWeb) ...[
            Text(
              request.expedienteNumber,
              style: TextStyle(
                color: CreditDetailColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            request.clientName,
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontSize: isWeb ? 20 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'DNI ${maskDocument(request.documentNumber)}',
            style: TextStyle(color: CreditDetailColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _HeaderMetric(
                label: 'Monto solicitado',
                value: formatCurrency(request.requestedAmount),
              ),
              _HeaderMetric(
                label: 'Plazo',
                value: '${request.termMonths} meses',
              ),
              if (request.isFromClientApp)
                _HeaderMetric(
                  label: 'Origen',
                  value: 'App clientes',
                ),
            ],
          ),
          if (!isWeb) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color),
              ),
              child: Text(
                request.status.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (request.pendingSync) ...[
            const SizedBox(height: 8),
            Text(
              'Pendiente de sincronizacion',
              style: TextStyle(color: CreditDetailColors.accent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: CreditDetailColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: CreditDetailColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _BureauSection extends StatelessWidget {
  const _BureauSection({
    required this.consult,
    required this.onConsult,
    required this.isLoading,
  });

  final BureauConsultResult? consult;
  final VoidCallback? onConsult;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CreditDetailColors.cardBgLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CreditDetailColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consulta buró',
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (consult == null) ...[
            Text(
              'Registre el consentimiento del cliente antes de transmitir.',
              style: TextStyle(color: CreditDetailColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onConsult,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Consultar buró'),
            ),
          ] else ...[
            RiskSemaphore(rating: consult!.rating),
            const SizedBox(height: 12),
            _MetricRow('Entidades con deuda', '${consult!.debtEntities}'),
            _MetricRow(
              'Deuda total',
              formatCurrency(consult!.totalDebtPen),
            ),
            _MetricRow(
              'Mayor deuda',
              formatCurrency(consult!.largestDebt),
            ),
            _MetricRow(
              'Mayor mora',
              '${consult!.maxOverdueDays} dias',
            ),
            if (consult!.pendingSync)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Consulta pendiente de sincronizacion',
                  style: TextStyle(color: CreditDetailColors.accent, fontSize: 12),
                ),
              ),
            if (consult!.blocksTransmission)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Calificacion restrictiva: no se puede transmitir.',
                  style: TextStyle(color: Color(0xFFFF4D4D)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TransmissionChecklistSection extends StatelessWidget {
  const _TransmissionChecklistSection({required this.detail});

  final CreditRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final checklist = TransmissionChecklist.evaluate(detail);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CreditDetailColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checklist.isReady
              ? const Color(0xFF27C46B).withValues(alpha: 0.4)
              : const Color(0xFFFF4D4D).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                checklist.isReady
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                color: checklist.isReady
                    ? const Color(0xFF27C46B)
                    : const Color(0xFFFF4D4D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  checklist.isReady
                      ? 'Checklist listo para transmitir'
                      : 'Checklist obligatorio pendiente',
                  style: TextStyle(
                    color: CreditDetailColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in checklist.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isComplete
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: item.isComplete
                        ? const Color(0xFF27C46B)
                        : CreditDetailColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: item.isComplete
                                ? CreditDetailColors.textPrimary
                                : const Color(0xFFFF4D4D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.detail != null)
                          Text(
                            item.detail!,
                            style: TextStyle(
                              color: CreditDetailColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientChatCard extends StatelessWidget {
  const _ClientChatCard({
    required this.clientName,
    required this.onOpen,
  });

  final String clientName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CreditDetailColors.cardBg,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: CreditDetailColors.accentContainer,
          child: Icon(Icons.chat_bubble_outline, color: CreditDetailColors.onAccentContainer),
        ),
        title: Text(
          'Chat con cliente',
          style: TextStyle(
            color: CreditDetailColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Conversacion con $clientName sobre esta solicitud.',
          style: TextStyle(color: CreditDetailColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: CreditDetailColors.textSecondary,
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.documents});

  final List<StoredCreditDocument> documents;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CreditDetailColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos adjuntos',
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty)
            Text(
              'Sin documentos registrados.',
              style: TextStyle(color: CreditDetailColors.textSecondary),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 700
                    ? 3
                    : constraints.maxWidth > 420
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    return _DocumentPreviewCard(
                      document: document,
                      documents: documents,
                      index: index,
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DocumentPreviewCard extends StatelessWidget {
  const _DocumentPreviewCard({
    required this.document,
    required this.documents,
    required this.index,
  });

  final StoredCreditDocument document;
  final List<StoredCreditDocument> documents;
  final int index;

  void _openGallery(BuildContext context) {
    StoredCreditDocumentGallery.open(
      context,
      documents: documents,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGallery(context),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: CreditDetailColors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CreditDetailColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: CreditDocumentThumbnail(url: document.storageUrl),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.typeLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CreditDetailColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (document.sharpnessScore != null)
                      Text(
                        '${document.sizeKb} KB · nitidez '
                        '${document.sharpnessScore!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: CreditDetailColors.textSecondary,
                          fontSize: 11,
                        ),
                      )
                    else
                      Text(
                        '${document.sizeKb} KB · tocar para ampliar',
                        style: TextStyle(
                          color: CreditDetailColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolutionSection extends StatelessWidget {
  const _ResolutionSection({required this.request});

  final SubmittedCreditRequest request;

  @override
  Widget build(BuildContext context) {
    final status = request.status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CreditDetailColors.cardBgLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CreditDetailColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resolucion del analista',
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (request.assignedAnalyst != null &&
              request.assignedAnalyst!.isNotEmpty)
            _MetricRow('Analista', request.assignedAnalyst!),
          if (status == SolicitudPipelineStatus.aprobada &&
              request.approvedAmount != null)
            _MetricRow(
              'Monto aprobado',
              formatCurrency(request.approvedAmount!),
            ),
          if (request.additionalCondition != null &&
              request.additionalCondition!.isNotEmpty)
            _MetricRow('Condicion', request.additionalCondition!),
          if (status == SolicitudPipelineStatus.rechazada &&
              request.rejectionReason != null &&
              request.rejectionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                request.rejectionReason!,
                style: TextStyle(color: Color(0xFFFF4D4D)),
              ),
            ),
          if (!request.hasResolution &&
              status == SolicitudPipelineStatus.transmitida)
            Text(
              'En espera de asignacion y respuesta del analista.',
              style: TextStyle(color: CreditDetailColors.textSecondary),
            ),
          if (status == SolicitudPipelineStatus.enAnalisis)
            Text(
              'El analista esta evaluando la solicitud.',
              style: TextStyle(color: CreditDetailColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _AddInternalNoteSection extends StatelessWidget {
  const _AddInternalNoteSection({
    required this.controller,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CreditDetailColors.cardBgLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CreditDetailColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Agregar nota interna',
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            style: TextStyle(color: CreditDetailColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Observacion privada para seguimiento interno',
              filled: true,
              fillColor: CreditDetailColors.cardBg,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: isSaving ? null : onSave,
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar nota'),
          ),
        ],
      ),
    );
  }
}

class _InternalNotesSection extends StatelessWidget {
  const _InternalNotesSection({required this.notes});

  final List<SolicitudInternalNote> notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notas internas',
          style: CreditDetailColors.sectionTitle,
        ),
        const SizedBox(height: 12),
        for (final note in notes)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CreditDetailColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CreditDetailColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.content,
                  style: TextStyle(color: CreditDetailColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(note.createdAt),
                  style: TextStyle(
                    color: CreditDetailColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: CreditDetailColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: CreditDetailColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CreditDetailColors.cardBgLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFF4D4D) : CreditDetailColors.accent,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(color: CreditDetailColors.textSecondary),
      ),
    );
  }
}
