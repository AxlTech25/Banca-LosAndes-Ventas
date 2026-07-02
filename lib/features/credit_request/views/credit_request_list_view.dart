import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/web_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/credit_pipeline_repository.dart';
import '../data/credit_request_repository.dart';
import '../data/status_notification_repository.dart';
import '../models/credit_request_models.dart';
import '../models/pipeline_models.dart';
import '../services/credit_request_gatekeeper.dart';
import '../viewmodels/credit_request_list_view_model.dart';
import '../viewmodels/pipeline_view_models.dart';
import '../viewmodels/status_notifications_view_model.dart';
import 'super_operador_approval_inbox_section.dart';
import 'client_app_inbox_section.dart';
import 'credit_request_detail_view.dart';
import 'credit_request_wizard_view.dart';
import 'request_status_board_section.dart';
import 'status_notifications_sheet.dart';

class CreditRequestListView extends StatefulWidget {
  const CreditRequestListView({
    super.key,
    required this.session,
    this.initialTabIndex = 0,
    this.embedded = false,
  });

  final AuthSession session;
  final int initialTabIndex;
  final bool embedded;

  @override
  State<CreditRequestListView> createState() => _CreditRequestListViewState();
}

class _CreditRequestListViewState extends State<CreditRequestListView>
    with SingleTickerProviderStateMixin {
  CreditRequestListViewModel? _draftsViewModel;
  SubmittedRequestsViewModel? _submittedViewModel;
  ClientAppInboxViewModel? _clientAppInboxViewModel;
  SuperOperadorApprovalInboxViewModel? _approvalInboxViewModel;
  RequestStatusBoardViewModel? _trackingViewModel;
  StatusNotificationsViewModel? _notificationsViewModel;
  CreditRequestRepository? _repository;
  late final TabController _tabController;

  bool get _showApprovalInbox =>
      widget.session.role.canApproveClientAppRequests;

  bool get _hideDraftsTab => widget.embedded && kIsWeb;

  int get _tabCount {
    final base = _showApprovalInbox ? 4 : 3;
    return _hideDraftsTab ? base : base + 1;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabCount - 1),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _draftsViewModel?.dispose();
    _submittedViewModel?.dispose();
    _clientAppInboxViewModel?.dispose();
    _approvalInboxViewModel?.dispose();
    _trackingViewModel?.dispose();
    _notificationsViewModel?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final client = supabase.Supabase.instance.client;
    final repository = CreditRequestRepository(
      client: client,
      advisorId: widget.session.advisorId,
      agencyId: widget.session.agencyId,
      preferences: preferences,
    );
    final pipelineRepository = CreditPipelineRepository(
      client: client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final draftsViewModel = CreditRequestListViewModel(repository: repository)
      ..addListener(_onChanged);
    final submittedViewModel = SubmittedRequestsViewModel(
      repository: pipelineRepository,
    )..addListener(_onChanged);
    final clientAppInboxViewModel = ClientAppInboxViewModel(
      repository: pipelineRepository,
      agencyId: widget.session.agencyId,
    )..addListener(_onChanged);
    SuperOperadorApprovalInboxViewModel? approvalInboxViewModel;
    if (widget.session.role.canApproveClientAppRequests) {
      approvalInboxViewModel = SuperOperadorApprovalInboxViewModel(
        repository: pipelineRepository,
        agencyId: widget.session.agencyId,
      )..addListener(_onChanged);
    }
    final notificationsViewModel = StatusNotificationsViewModel(
      repository: StatusNotificationRepository(preferences: preferences),
    )..addListener(_onChanged);
    final trackingViewModel = RequestStatusBoardViewModel(
      repository: pipelineRepository,
      notificationsViewModel: notificationsViewModel,
    )..addListener(_onChanged);
    if (!mounted) {
      draftsViewModel.dispose();
      submittedViewModel.dispose();
      clientAppInboxViewModel.dispose();
      approvalInboxViewModel?.dispose();
      trackingViewModel.dispose();
      notificationsViewModel.dispose();
      return;
    }
    setState(() {
      _repository = repository;
      _draftsViewModel = draftsViewModel;
      _submittedViewModel = submittedViewModel;
      _clientAppInboxViewModel = clientAppInboxViewModel;
      _approvalInboxViewModel = approvalInboxViewModel;
      _trackingViewModel = trackingViewModel;
      _notificationsViewModel = notificationsViewModel;
    });
    notificationsViewModel.load();
    final loads = <Future<void>>[
      draftsViewModel.load(),
      submittedViewModel.load(),
      clientAppInboxViewModel.load(),
      trackingViewModel.load(),
    ];
    if (approvalInboxViewModel != null) {
      loads.add(approvalInboxViewModel.load());
    }
    await Future.wait(loads);
    trackingViewModel.startRealtime();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _draftsViewModel?.load() ?? Future.value(),
      _submittedViewModel?.load() ?? Future.value(),
      _clientAppInboxViewModel?.load() ?? Future.value(),
      _approvalInboxViewModel?.load() ?? Future.value(),
      _trackingViewModel?.load() ?? Future.value(),
    ]);
  }

  Future<void> _openNewRequest() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    final draft = await repository.createDraft(
      const CreditRequestLaunchData(
        documentNumber: '',
        clientFirstName: '',
        clientLastName: '',
      ),
    );
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreditRequestWizardView(
          session: widget.session,
          draft: draft,
        ),
      ),
    );
    await _refreshAll();
  }

  Future<void> _openDraft(CreditRequestDraft draft) async {
    if (draft.documentNumber.trim().length == 8) {
      final blocked = await CreditRequestGatekeeper.checkDocumentAndBlock(
        context,
        draft.documentNumber,
      );
      if (!mounted || blocked) {
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreditRequestWizardView(
          session: widget.session,
          draft: draft,
        ),
      ),
    );
    await _refreshAll();
  }

  Future<void> _takeClientAppCase(SubmittedCreditRequest request) async {
    final viewModel = _clientAppInboxViewModel;
    if (viewModel == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tomar caso'),
        content: Text(
          'Asignar la solicitud de ${request.clientName} '
          '(${request.expedienteNumber}) a su cartera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tomar caso'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final assigned = await viewModel.takeCase(request.id);
    if (!mounted) {
      return;
    }

    if (!assigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'No se pudo asignar la solicitud.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Caso asignado: ${request.clientName}. Ya aparece en su cartera del dia.',
        ),
      ),
    );

    await CreditRequestDetailView.open(
      context,
      session: widget.session,
      solicitudId: request.id,
    );
    await _submittedViewModel?.load();
    await _trackingViewModel?.load();
  }

  Future<void> _openApprovalItem(PendingApprovalItem item) async {
    await CreditRequestDetailView.open(
      context,
      session: widget.session,
      solicitudId: item.request.id,
    );
    await _approvalInboxViewModel?.load();
    await _submittedViewModel?.load();
    await _trackingViewModel?.load();
  }

  Future<void> _openSubmitted(SubmittedCreditRequest request) async {
    await CreditRequestDetailView.open(
      context,
      session: widget.session,
      solicitudId: request.id,
    );
    await _submittedViewModel?.load();
    await _trackingViewModel?.load();
  }

  Future<void> _openNotification(StatusChangeNotification notification) async {
    await CreditRequestDetailView.open(
      context,
      session: widget.session,
      solicitudId: notification.solicitudId,
    );
    await _trackingViewModel?.load();
  }

  void _openNotificationsSheet() {
    final viewModel = _notificationsViewModel;
    if (viewModel == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      isScrollControlled: true,
      builder: (context) => StatusNotificationsSheet(
        viewModel: viewModel,
        onOpenRequest: _openNotification,
      ),
    );
  }

  List<Widget> _buildTabs(ClientAppInboxViewModel? clientAppInboxViewModel) {
    final tabs = <Widget>[];

    if (!_hideDraftsTab) {
      tabs.add(const Tab(text: 'Borradores'));
    }

    tabs.add(
      Tab(
        child: _AppClientesTabLabel(
          assignableCount: clientAppInboxViewModel?.assignableCount ?? 0,
        ),
      ),
    );

    if (_showApprovalInbox) {
      tabs.add(
        Tab(
          child: _ApprovalTabLabel(
            readyCount: _approvalInboxViewModel?.readyCount ?? 0,
          ),
        ),
      );
    }

    tabs.addAll(const [
      Tab(text: 'Enviadas'),
      Tab(text: 'Estado'),
    ]);

    return tabs;
  }

  List<Widget> _buildTabViews({
    required CreditRequestListViewModel draftsViewModel,
    required ClientAppInboxViewModel clientAppInboxViewModel,
    required SubmittedRequestsViewModel submittedViewModel,
    required RequestStatusBoardViewModel trackingViewModel,
  }) {
    final views = <Widget>[];

    if (!_hideDraftsTab) {
      views.add(
        RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (draftsViewModel.localPendingCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    '${draftsViewModel.localPendingCount} solicitud(es) '
                    'pendiente(s) de sincronizar.',
                    style: const TextStyle(color: AppColors.onSurface),
                  ),
                ),
              if (draftsViewModel.drafts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      'No hay borradores guardados.',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final draft in draftsViewModel.drafts)
                  Card(
                    color: AppColors.surfaceContainer,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        draft.clientFullName.isEmpty
                            ? 'Borrador sin titular'
                            : draft.clientFullName,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${formatCurrency(draft.requestedAmount)} · '
                        'Paso ${draft.currentStep + 1}/4 · '
                        '${draft.status.label}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await draftsViewModel.deleteDraft(
                              draft.localId,
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar borrador'),
                          ),
                        ],
                      ),
                      onTap: () => _openDraft(draft),
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    views.add(
      RefreshIndicator(
        onRefresh: _refreshAll,
        child: ClientAppInboxSection(
          viewModel: clientAppInboxViewModel,
          onTakeCase: _takeClientAppCase,
        ),
      ),
    );

    if (_showApprovalInbox && _approvalInboxViewModel != null) {
      views.add(
        RefreshIndicator(
          onRefresh: _refreshAll,
          child: SuperOperadorApprovalInboxSection(
            viewModel: _approvalInboxViewModel!,
            onOpenRequest: _openApprovalItem,
          ),
        ),
      );
    }

    views.add(
      RefreshIndicator(
        onRefresh: _refreshAll,
        child: submittedViewModel.isLoading &&
                submittedViewModel.requests.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : submittedViewModel.requests.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 48),
                  Center(
                    child: Text(
                      'No hay solicitudes enviadas.\n'
                      'Complete y envie una solicitud desde Borradores.',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: submittedViewModel.requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request = submittedViewModel.requests[index];
                  final statusColor = Color(request.status.colorValue);
                  return Card(
                    color: AppColors.surfaceContainer,
                    child: ListTile(
                      title: Text(
                        request.clientName,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.expedienteNumber} · '
                            '${formatCurrency(request.requestedAmount)}',
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.hasBureauConsult
                                ? 'Buró registrado · ${request.status.label}'
                                : 'Pendiente consulta buró · ${request.status.label}',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onTap: () => _openSubmitted(request),
                    ),
                  );
                },
              ),
      ),
    );

    views.add(
      RequestStatusBoardSection(
        viewModel: trackingViewModel,
        onOpenRequest: _openSubmitted,
      ),
    );

    return views;
  }

  @override
  Widget build(BuildContext context) {
    final draftsViewModel = _draftsViewModel;
    final submittedViewModel = _submittedViewModel;
    final clientAppInboxViewModel = _clientAppInboxViewModel;
    final trackingViewModel = _trackingViewModel;
    final notificationsViewModel = _notificationsViewModel;

    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.onSurface,
              title: const Text('Solicitudes de credito'),
              actions: [
                if (notificationsViewModel != null &&
                    notificationsViewModel.unreadCount > 0)
                  IconButton(
                    onPressed: _openNotificationsSheet,
                    icon: Badge(
                      label: Text('${notificationsViewModel.unreadCount}'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _openNotificationsSheet,
                    icon: const Icon(Icons.notifications_outlined),
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.onSurface,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                tabs: _buildTabs(clientAppInboxViewModel),
              ),
            ),
      floatingActionButton: !widget.embedded && _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openNewRequest,
              icon: const Icon(Icons.add),
              label: const Text('Nueva solicitud'),
            )
          : null,
      body: draftsViewModel == null ||
              submittedViewModel == null ||
              clientAppInboxViewModel == null ||
              trackingViewModel == null ||
              (_showApprovalInbox && _approvalInboxViewModel == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.embedded)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (kIsWeb)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Solicitudes de credito',
                                      style: TextStyle(
                                        color: WebTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${widget.session.displayName} · '
                                      '${widget.session.role.label}',
                                      style: const TextStyle(
                                        color: WebTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _openNewRequest,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Nueva solicitud'),
                              ),
                            ],
                          ),
                        ),
                      Material(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorColor: WebTheme.brandCyanDark,
                          labelColor: WebTheme.textPrimary,
                          unselectedLabelColor: WebTheme.navInactive,
                          tabs: _buildTabs(clientAppInboxViewModel),
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _buildTabViews(
                      draftsViewModel: draftsViewModel,
                      clientAppInboxViewModel: clientAppInboxViewModel,
                      submittedViewModel: submittedViewModel,
                      trackingViewModel: trackingViewModel,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ApprovalTabLabel extends StatelessWidget {
  const _ApprovalTabLabel({required this.readyCount});

  final int readyCount;

  @override
  Widget build(BuildContext context) {
    const label = 'Por aprobar';

    if (readyCount <= 0) {
      return const Text(label);
    }

    return Badge(
      label: Text('$readyCount'),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label),
      ),
    );
  }
}

class _AppClientesTabLabel extends StatelessWidget {
  const _AppClientesTabLabel({required this.assignableCount});

  final int assignableCount;

  @override
  Widget build(BuildContext context) {
    const label = 'App clientes';

    if (assignableCount <= 0) {
      return const Text(label);
    }

    return Badge(
      label: Text('$assignableCount'),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label),
      ),
    );
  }
}
