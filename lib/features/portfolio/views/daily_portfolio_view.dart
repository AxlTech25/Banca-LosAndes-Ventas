import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../auth/data/auth_repository.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/user_role.dart';
import '../../auth/views/login_view.dart';
import '../../client_profile/data/portfolio_alerts_repository.dart';
import '../../client_profile/models/portfolio_alert.dart';
import '../../client_profile/viewmodels/portfolio_alerts_view_model.dart';
import '../../client_profile/views/client_profile_view.dart';
import '../../client_profile/views/portfolio_alerts_sheet.dart';
import '../../credit_request/data/credit_pipeline_repository.dart';
import '../../credit_request/views/documents_hub_view.dart';
import '../../credit_request/data/credit_request_repository.dart';
import '../../credit_request/models/credit_request_models.dart';
import '../../credit_request/views/credit_request_detail_view.dart';
import '../../credit_request/views/credit_request_list_view.dart';
import '../../admin/views/admin_hub_views.dart';
import '../../blacklist/data/blacklist_repository.dart';
import '../../credit_request/views/solicitud_chat_view.dart';
import '../../notifications/data/advisor_notifications_repository.dart';
import '../../notifications/models/advisor_inbox_item.dart';
import '../../notifications/models/advisor_notification_models.dart';
import '../../notifications/data/push_token_repository.dart';
import '../../credit_request/services/credit_request_gatekeeper.dart';
import '../../credit_request/views/credit_simulator_view.dart';
import '../../collection/data/collection_repository.dart';
import '../../collection/models/collection_models.dart';
import '../../collection/views/collection_action_sheet.dart';
import '../../collection/views/collection_board_view.dart';
import '../../collection/views/pending_payments_view.dart';
import '../../collection/data/pending_payments_repository.dart';
import '../../prospection/data/campaigns_repository.dart';
import '../../prospection/data/prospection_repository.dart';
import '../../prospection/models/pre_evaluation_models.dart';
import '../../prospection/viewmodels/campaigns_view_model.dart';
import '../../prospection/views/active_campaigns_section.dart';
import '../../prospection/views/deserter_form_sheet.dart';
import '../../prospection/views/pre_evaluation_view.dart';
import '../../clients/data/clients_directory_repository.dart';
import '../../clients/viewmodels/clients_directory_view_model.dart';
import '../../clients/views/clients_directory_tab.dart';
import '../../clients/views/clients_directory_view.dart';
import '../../field_committee/views/field_committee_view.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/viewmodels/profile_view_model.dart';
import '../../profile/views/profile_tab.dart';
import '../../route/views/route_map_view.dart';
import '../../supervision/views/coverage_monitor_view.dart';
import '../../supervision/views/supervision_reports_hub_view.dart';
import '../services/portfolio_nightly_sync_service.dart';
import '../../../core/events/portfolio_refresh_signal.dart';
import '../data/daily_portfolio_repository.dart';
import '../models/daily_client.dart';
import '../viewmodels/daily_portfolio_view_model.dart';

class DailyPortfolioView extends StatefulWidget {
  const DailyPortfolioView({
    super.key,
    required this.authRepository,
    required this.session,
  });

  final AuthRepository authRepository;
  final AuthSession session;

  @override
  State<DailyPortfolioView> createState() => _DailyPortfolioViewState();
}

class _DailyPortfolioViewState extends State<DailyPortfolioView> {
  DailyPortfolioViewModel? _viewModel;
  PortfolioAlertsViewModel? _alertsViewModel;
  CampaignsViewModel? _campaignsViewModel;
  ProspectionRepository? _prospectionRepository;
  ClientsDirectoryViewModel? _clientsViewModel;
  ProfileViewModel? _profileViewModel;
  int _navIndex = 0;
  int _pendingPaymentsCount = 0;
  String _advisorDisplayName = '';

  static const background = Color(0xFF051424);
  static const surfaceDim = Color(0xFF051424);
  static const surfaceContainer = Color(0xFF122131);
  static const surfaceContainerLow = Color(0xFF0D1C2D);
  static const surfaceContainerLowest = Color(0xFF010F1F);
  static const surfaceContainerHighest = Color(0xFF273647);
  static const onSurface = Color(0xFFD4E4FA);
  static const onSurfaceVariant = Color(0xFFBCC8D0);
  static const outline = Color(0xFF86929A);
  static const outlineVariant = Color(0xFF3D484F);
  static const primary = Color(0xFF89D9FF);
  static const primaryContainer = Color(0xFF00C1F9);
  static const primaryFixedDim = Color(0xFF6ED2FF);
  static const onPrimaryFixed = Color(0xFF001F2A);
  static const secondaryContainer = Color(0xFF3E495D);
  static const onSecondaryContainer = Color(0xFFAEB9D0);

  @override
  void initState() {
    super.initState();
    _advisorDisplayName = widget.session.displayName;
    PortfolioRefreshSignal.instance.version.addListener(_onPortfolioRefreshSignal);
    _initializePortfolio();
  }

  @override
  void dispose() {
    PortfolioRefreshSignal.instance.version.removeListener(_onPortfolioRefreshSignal);
    _viewModel?.dispose();
    _alertsViewModel?.dispose();
    _campaignsViewModel?.dispose();
    _clientsViewModel?.dispose();
    _profileViewModel?.dispose();
    super.dispose();
  }

  Future<void> _initializePortfolio() async {
    final preferences = await SharedPreferences.getInstance();
    final client = supabase.Supabase.instance.client;
    final repository = DailyPortfolioRepository(
      client: client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final alertsRepository = PortfolioAlertsRepository(
      client: client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final prospectionRepository = ProspectionRepository(
      client: client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final campaignsRepository = CampaignsRepository(
      client: client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final creditRequestRepository = CreditRequestRepository(
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
    final collectionRepository = CollectionRepository(
      client: client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final clientsViewModel = ClientsDirectoryViewModel(
      repository: ClientsDirectoryRepository(
        client: client,
        advisorId: widget.session.advisorId,
      ),
    )..addListener(_onViewModelChanged);
    final profileViewModel = ProfileViewModel(
      profileRepository: ProfileRepository(
        client: client,
        advisorId: widget.session.advisorId,
      ),
      portfolioRepository: repository,
      authRepository: widget.authRepository,
    )..addListener(_onViewModelChanged);
    final viewModel = DailyPortfolioViewModel(repository: repository)
      ..addListener(_onViewModelChanged);
    final alertsViewModel = PortfolioAlertsViewModel(
      repository: alertsRepository,
      appNotificationsRepository: AdvisorNotificationsRepository(
        client: client,
        advisorId: widget.session.advisorId,
      ),
    )..addListener(_onViewModelChanged);
    final campaignsViewModel = CampaignsViewModel(
      repository: campaignsRepository,
    )..addListener(_onViewModelChanged);
    if (!mounted) {
      viewModel.dispose();
      alertsViewModel.dispose();
      campaignsViewModel.dispose();
      clientsViewModel.dispose();
      profileViewModel.dispose();
      return;
    }
    setState(() {
      _viewModel = viewModel;
      _alertsViewModel = alertsViewModel;
      _campaignsViewModel = campaignsViewModel;
      _prospectionRepository = prospectionRepository;
      _clientsViewModel = clientsViewModel;
      _profileViewModel = profileViewModel;
    });
    final localPending = await creditRequestRepository.countLocalPendingSync();
    await Future.wait([
      viewModel.load(),
      alertsViewModel.load(),
      campaignsViewModel.load(),
      prospectionRepository.syncPendingEvaluations(),
      creditRequestRepository.syncPendingRequests(),
      pipelineRepository.syncPendingPipeline(),
      collectionRepository.syncPendingActions(),
      clientsViewModel.load(),
      profileViewModel.load(pendingLocalDrafts: localPending),
    ]);
    alertsViewModel.startRealtime();
    await PortfolioNightlySyncService.registerForAdvisor(widget.session.advisorId);
    await _refreshPendingPaymentsCount(client);
    await PushTokenRepository(
      client: supabase.Supabase.instance.client,
    ).registerDeviceToken(advisorId: widget.session.advisorId);
    await BlacklistRepository(
      client: supabase.Supabase.instance.client,
      preferences: preferences,
    ).warmCache();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPortfolioRefreshSignal() {
    _viewModel?.refreshAfterCaseAssignment();
  }

  Future<void> _refreshProfileStats() async {
    final preferences = await SharedPreferences.getInstance();
    final creditRepository = CreditRequestRepository(
      client: supabase.Supabase.instance.client,
      advisorId: widget.session.advisorId,
      agencyId: widget.session.agencyId,
      preferences: preferences,
    );
    final localPending = await creditRepository.countLocalPendingSync();
    await _profileViewModel?.load(pendingLocalDrafts: localPending);
  }

  void _onProfileUpdated() {
    final profile = _profileViewModel?.profile;
    if (profile != null) {
      setState(() => _advisorDisplayName = profile.displayName);
    }
  }

  void _onNavDestinationSelected(int index) {
    setState(() => _navIndex = index);
    if (index == 2) {
      _clientsViewModel?.load();
    } else if (index == 3) {
      _refreshProfileStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_navIndex == 0)
              _TopAppBar(
                session: widget.session,
                unreadAlerts: _alertsViewModel?.unreadCount ?? 0,
                onOpenAlerts: _openAlertsSheet,
              )
            else
              _ShellTabHeader(
                title: switch (_navIndex) {
                  1 => 'Ruta del dia',
                  2 => 'Mis clientes',
                  _ => 'Mi perfil',
                },
                onOpenDrawer: () => Scaffold.of(context).openDrawer(),
              ),
            Expanded(
              child: IndexedStack(
                index: _navIndex,
                children: [
                  viewModel == null
                      ? const Center(child: CircularProgressIndicator())
                      : _PortfolioBody(
                          viewModel: viewModel,
                          campaignsViewModel: _campaignsViewModel,
                          onManageCampaign: _manageCampaign,
                        ),
                  RouteMapView(session: widget.session, embedded: true),
                  _clientsViewModel == null
                      ? const Center(child: CircularProgressIndicator())
                      : ClientsDirectoryTab(
                          session: widget.session,
                          viewModel: _clientsViewModel!,
                        ),
                  _profileViewModel == null
                      ? const Center(child: CircularProgressIndicator())
                      : ProfileTab(
                          session: widget.session,
                          viewModel: _profileViewModel!,
                          onLogout: _logout,
                          onProfileUpdated: _onProfileUpdated,
                          onRefresh: _refreshProfileStats,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: _RoleDrawer(
        session: widget.session,
        displayName: _advisorDisplayName,
        onLogout: _logout,
        onOpenPortfolio: _openPortfolioTab,
        onOpenRoute: _openRouteMap,
        onOpenFicha: _openClientsDirectory,
        onOpenProspection: _openPreEvaluation,
        onOpenCreditRequests: _openCreditRequests,
        onOpenDocuments: _openDocumentsHub,
        onOpenCollection: _openCollectionBoard,
        onOpenPendingPayments: _openPendingPayments,
        pendingPaymentsCount: _pendingPaymentsCount,
        onOpenFieldCommittee: _openFieldCommittee,
        onOpenSupervisionReports: _openSupervisionReports,
        onOpenCoverageMonitor: _openCoverageMonitor,
        onOpenCreditSimulator: _openCreditSimulator,
        onOpenTaskReassignment: _openTaskReassignment,
        onOpenUserManagement: _openUserManagement,
        onOpenFormsConfiguration: _openFormsConfiguration,
        onOpenAppSettings: _openAppSettings,
        unreadAlerts: _alertsViewModel?.unreadCount ?? 0,
        onOpenAlerts: _openAlertsSheet,
      ),
      bottomNavigationBar: _PortfolioBottomNavigation(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavDestinationSelected,
      ),
    );
  }

  Future<void> _logout() async {
    final preferences = await SharedPreferences.getInstance();
    final creditRepository = CreditRequestRepository(
      client: supabase.Supabase.instance.client,
      advisorId: widget.session.advisorId,
      agencyId: widget.session.agencyId,
      preferences: preferences,
    );
    final remotePending = await widget.authRepository.pendingSyncCount();
    final localPending = await creditRepository.countLocalPendingSync();
    final pendingCount = remotePending + localPending;
    if (!mounted) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cerrar sesion'),
            content: Text(
              pendingCount > 0
                  ? 'Tienes $pendingCount solicitudes sin sincronizar. '
                        'Cerrar de todas formas?'
                  : 'Quieres cerrar sesion?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await PortfolioNightlySyncService.cancel();
    await widget.authRepository.signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginView(authRepository: widget.authRepository),
      ),
      (_) => false,
    );
  }

  Future<void> _openClientProfile(DailyClient client) async {
    if (client.managementType == ManagementType.newRequest &&
        client.solicitudId != null &&
        client.solicitudId!.isNotEmpty) {
      await CreditRequestDetailView.open(
        context,
        session: widget.session,
        solicitudId: client.solicitudId!,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientProfileView(
          session: widget.session,
          dailyClient: client,
          onRegisterVisit: () => _openVisitResult(client),
          onRegisterDeserter: client.managementType == ManagementType.deserter
              ? () => _openDeserterForm(client)
              : null,
          onRegisterCollection:
              client.managementType == ManagementType.recovery
              ? () => _openCollectionAction(client)
              : null,
        ),
      ),
    );
  }

  void _openPreEvaluation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreEvaluationView(session: widget.session),
      ),
    );
  }

  void _openCreditRequests({int initialTabIndex = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreditRequestListView(
          session: widget.session,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
    await _viewModel?.refreshAfterCaseAssignment();
  }

  void _openDocumentsHub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentsHubView(session: widget.session),
      ),
    );
  }

  Future<void> _refreshPendingPaymentsCount(supabase.SupabaseClient client) async {
    try {
      final count = await PendingPaymentsRepository(
        client: client,
        advisorId: widget.session.advisorId,
      ).countPendingPayments();
      if (mounted) {
        setState(() => _pendingPaymentsCount = count);
      }
    } catch (_) {
      // Ignorar si la migracion 011 aun no esta aplicada.
    }
  }

  void _openCollectionBoard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionBoardView(
          session: widget.session,
          portfolioClients: _viewModel?.clients ?? const [],
        ),
      ),
    );
  }

  Future<void> _openPendingPayments() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PendingPaymentsView(session: widget.session),
      ),
    );
    await _refreshPendingPaymentsCount(supabase.Supabase.instance.client);
  }

  void _openSupervisionReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupervisionReportsHubView(session: widget.session),
      ),
    );
  }

  void _openCoverageMonitor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoverageMonitorView(session: widget.session),
      ),
    );
  }

  void _openCreditSimulator() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreditSimulatorView(session: widget.session),
      ),
    );
  }

  void _openTaskReassignment() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TaskReassignmentView()),
    );
  }

  void _openUserManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const UserManagementView()),
    );
  }

  void _openFormsConfiguration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FormsConfigurationView()),
    );
  }

  void _openAppSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AppSettingsView()),
    );
  }

  Future<void> _openCollectionAction(DailyClient client) async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final repository = CollectionRepository(
      client: supabase.Supabase.instance.client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final entry = OverdueClientEntry.fromDailyClient(client);

    final form = await showModalBottomSheet<CollectionActionFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceContainer,
      builder: (context) => CollectionActionSheet(client: entry),
    );
    if (form == null) {
      return;
    }

    try {
      await repository.registerAction(
        client: entry,
        form: form,
        portfolioEntryId: client.id,
      );
      await _viewModel?.refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gestion de cobranza registrada.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _manageCampaign(ActiveCampaign campaign) async {
    final portfolioClient = _viewModel?.findByClientId(campaign.clientId);
    await CreditRequestGatekeeper.openFromLaunch(
      context,
      session: widget.session,
      launch: CreditRequestLaunchData.fromCampaign(
        campaign: campaign,
        client: portfolioClient,
      ),
    );
  }

  Future<void> _openDeserterForm(DailyClient client) async {
    final data = await showModalBottomSheet<DeserterFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceContainer,
      builder: (context) => DeserterFormSheet(clientName: client.clientName),
    );
    if (data == null) {
      return;
    }

    final repository = _prospectionRepository;
    if (repository == null) {
      return;
    }

    await repository.saveDeserterRecord(
      clientId: client.clientId,
      portfolioEntryId: client.id,
      data: data,
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro de desercion guardado.')),
    );
  }

  void _openRouteMap() {
    setState(() => _navIndex = 1);
  }

  void _openPortfolioTab() {
    setState(() => _navIndex = 0);
  }

  void _openClientsDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientsDirectoryView(session: widget.session),
      ),
    );
  }

  void _openFieldCommittee() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FieldCommitteeView(session: widget.session),
      ),
    );
  }

  Future<void> _openAlertsSheet() async {
    final alertsViewModel = _alertsViewModel;
    if (alertsViewModel == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceContainer,
      builder: (context) => PortfolioAlertsSheet(
        viewModel: alertsViewModel,
        onInboxItemTap: (item) async {
          Navigator.of(context).pop();
          await alertsViewModel.markInboxItemAsRead(item);
          if (!mounted) {
            return;
          }
          await _handleInboxItemTap(item);
        },
      ),
    );
  }

  Future<void> _handleInboxItemTap(AdvisorInboxItem item) async {
    switch (item.source) {
      case AdvisorInboxSource.portfolio:
        await _openClientProfile(_dailyClientForAlert(item.alert!));
      case AdvisorInboxSource.appCliente:
        await _handleAppNotificationTap(item.notification!);
    }
  }

  Future<void> _handleAppNotificationTap(
    AdvisorNotification notification,
  ) async {
    switch (notification.type) {
      case AdvisorNotificationType.solicitudNueva:
        _openCreditRequests(initialTabIndex: 1);
      case AdvisorNotificationType.chatCliente:
        await _openChatFromNotification(notification);
      case AdvisorNotificationType.pagoPendiente:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PendingPaymentsView(session: widget.session),
          ),
        );
    }
  }

  Future<void> _openChatFromNotification(
    AdvisorNotification notification,
  ) async {
    final solicitudId = notification.referenciaId;
    if (solicitudId == null || solicitudId.isEmpty) {
      _openCreditRequests(initialTabIndex: 1);
      return;
    }

    try {
      final row = await supabase.Supabase.instance.client
          .from('solicitudes_credito')
          .select(
            'cliente_id, numero_expediente, clientes(nombres, apellidos)',
          )
          .eq('id', solicitudId)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      if (row == null) {
        _openCreditRequests(initialTabIndex: 1);
        return;
      }

      final clienteId = row['cliente_id']?.toString();
      if (clienteId == null || clienteId.isEmpty) {
        await CreditRequestDetailView.open(
          context,
          session: widget.session,
          solicitudId: solicitudId,
        );
        return;
      }

      final clientes = row['clientes'] as Map<String, dynamic>?;
      final nombres = clientes?['nombres']?.toString() ?? '';
      final apellidos = clientes?['apellidos']?.toString() ?? '';
      final clientName = '$nombres $apellidos'.trim();

      await SolicitudChatView.open(
        context,
        session: widget.session,
        solicitudId: solicitudId,
        clienteId: clienteId,
        expedienteNumber: row['numero_expediente']?.toString(),
        clientName: clientName.isEmpty ? null : clientName,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      await CreditRequestDetailView.open(
        context,
        session: widget.session,
        solicitudId: solicitudId,
      );
    }
  }

  DailyClient _dailyClientForAlert(PortfolioAlert alert) {
    final portfolioClient = _viewModel?.findByClientId(alert.clientId);
    if (portfolioClient != null) {
      return portfolioClient;
    }

    return DailyClient(
      clientId: alert.clientId,
      advisorId: widget.session.advisorId,
      clientName: alert.clientName,
      documentNumber: '',
      managementType: ManagementType.followUp,
      creditAmount: 0,
      priorityScore: 0,
      visitStatus: VisitStatus.pending,
      assignmentDate: DateTime.now(),
      id: '',
    );
  }

  Future<void> _openVisitResult(DailyClient client) async {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }

    final result = await showModalBottomSheet<_VisitResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceContainer,
      builder: (context) => _VisitResultSheet(client: client),
    );
    if (result == null) {
      return;
    }

    final insideZone = await viewModel.isInsideWorkZone();
    if (!insideZone && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fuera de zona de trabajo'),
          content: const Text(
            'Su ubicacion actual esta fuera de la geocerca asignada. '
            'Desea registrar la visita de todas formas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Registrar igual'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }

    await viewModel.saveVisitResult(
      client: client,
      status: result.status,
      observation: result.observation,
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  const _PortfolioBody({
    required this.viewModel,
    required this.campaignsViewModel,
    required this.onManageCampaign,
  });

  final DailyPortfolioViewModel viewModel;
  final CampaignsViewModel? campaignsViewModel;
  final ValueChanged<ActiveCampaign> onManageCampaign;

  Future<void> _refreshAll() async {
    final campaigns = campaignsViewModel;
    await Future.wait([
      viewModel.refresh(),
      if (campaigns != null) campaigns.load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final clients = viewModel.filteredClients;
    final campaigns = campaignsViewModel;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  _SummaryCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _SearchField(onChanged: viewModel.updateSearch),
                  const SizedBox(height: 12),
                  _FilterRow(viewModel: viewModel),
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _InlineMessage(text: viewModel.errorMessage!),
                  ],
                  if (campaigns != null) ...[
                    const SizedBox(height: 16),
                    ActiveCampaignsSection(
                      viewModel: campaigns,
                      onManageCampaign: onManageCampaign,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (viewModel.isLoading && clients.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (clients.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No hay clientes para este filtro',
                  style: TextStyle(color: _DailyPortfolioViewState.onSurface),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverReorderableList(
                itemCount: clients.length,
                onReorder: viewModel.reorderFiltered,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return Padding(
                    key: ValueKey(client.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ClientCard(
                      client: client,
                      dragIndex: index,
                      onTap: () => context
                          .findAncestorStateOfType<_DailyPortfolioViewState>()
                          ?._openClientProfile(client),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({
    required this.session,
    required this.unreadAlerts,
    required this.onOpenAlerts,
  });

  final AuthSession session;
  final int unreadAlerts;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _DailyPortfolioViewState.surfaceDim,
        border: Border(
          bottom: BorderSide(color: _DailyPortfolioViewState.outline),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _DailyPortfolioViewState.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _DailyPortfolioViewState.outlineVariant,
              ),
            ),
            child: const Icon(
              Icons.person,
              color: _DailyPortfolioViewState.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cartera Diaria · ${session.role.label}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _DailyPortfolioViewState.primaryFixedDim,
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _BadgeIconButton(
            tooltip: 'Alertas de cartera',
            icon: Icons.notifications_outlined,
            badgeCount: unreadAlerts,
            onPressed: onOpenAlerts,
          ),
          IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            color: _DailyPortfolioViewState.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _BadgeIconButton extends StatelessWidget {
  const _BadgeIconButton({
    required this.tooltip,
    required this.icon,
    required this.badgeCount,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int badgeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          color: _DailyPortfolioViewState.onSurfaceVariant,
        ),
        if (badgeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D),
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShellTabHeader extends StatelessWidget {
  const _ShellTabHeader({
    required this.title,
    required this.onOpenDrawer,
  });

  final String title;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: _DailyPortfolioViewState.surfaceDim,
        border: Border(
          bottom: BorderSide(color: _DailyPortfolioViewState.outline),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onOpenDrawer,
            icon: const Icon(Icons.menu),
            color: _DailyPortfolioViewState.onSurfaceVariant,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _DailyPortfolioViewState.primaryFixedDim,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDrawer extends StatelessWidget {
  const _RoleDrawer({
    required this.session,
    required this.displayName,
    required this.onLogout,
    required this.onOpenPortfolio,
    required this.onOpenRoute,
    required this.onOpenFicha,
    required this.onOpenProspection,
    required this.onOpenCreditRequests,
    required this.onOpenDocuments,
    required this.onOpenCollection,
    required this.onOpenPendingPayments,
    required this.pendingPaymentsCount,
    required this.onOpenFieldCommittee,
    required this.onOpenSupervisionReports,
    required this.onOpenCoverageMonitor,
    required this.onOpenCreditSimulator,
    required this.onOpenTaskReassignment,
    required this.onOpenUserManagement,
    required this.onOpenFormsConfiguration,
    required this.onOpenAppSettings,
    required this.unreadAlerts,
    required this.onOpenAlerts,
  });

  final AuthSession session;
  final String displayName;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenPortfolio;
  final VoidCallback onOpenRoute;
  final VoidCallback onOpenFicha;
  final VoidCallback onOpenProspection;
  final VoidCallback onOpenCreditRequests;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenCollection;
  final VoidCallback onOpenPendingPayments;
  final int pendingPaymentsCount;
  final VoidCallback onOpenFieldCommittee;
  final VoidCallback onOpenSupervisionReports;
  final VoidCallback onOpenCoverageMonitor;
  final VoidCallback onOpenCreditSimulator;
  final VoidCallback onOpenTaskReassignment;
  final VoidCallback onOpenUserManagement;
  final VoidCallback onOpenFormsConfiguration;
  final VoidCallback onOpenAppSettings;
  final int unreadAlerts;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    final sections = _sectionsForRole(session.role);

    return Drawer(
      backgroundColor: _DailyPortfolioViewState.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _DailyPortfolioViewState.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: _DailyPortfolioViewState.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: _DailyPortfolioViewState.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${session.employeeCode} · ${session.role.label}',
                          style: const TextStyle(
                            color: _DailyPortfolioViewState.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: _DailyPortfolioViewState.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final section in sections)
                    ListTile(
                      leading: Icon(
                        section.icon,
                        color: _DailyPortfolioViewState.primary,
                      ),
                      title: Text(
                        section.label,
                        style: const TextStyle(
                          color: _DailyPortfolioViewState.onSurface,
                        ),
                      ),
                      trailing: switch (section.destination) {
                        DrawerDestination.cartera when unreadAlerts > 0 =>
                          _DrawerBadge(count: unreadAlerts),
                        DrawerDestination.pagosPendientes
                            when pendingPaymentsCount > 0 =>
                          _DrawerBadge(count: pendingPaymentsCount),
                        _ => null,
                      },
                      onTap: () {
                        Navigator.of(context).pop();
                        switch (section.destination) {
                          case DrawerDestination.cartera:
                            onOpenPortfolio();
                          case DrawerDestination.ruta:
                            onOpenRoute();
                          case DrawerDestination.prospection:
                            onOpenProspection();
                          case DrawerDestination.ficha:
                            onOpenFicha();
                          case DrawerDestination.solicitud:
                            onOpenCreditRequests();
                          case DrawerDestination.documentos:
                            onOpenDocuments();
                          case DrawerDestination.mora:
                            onOpenCollection();
                          case DrawerDestination.pagosPendientes:
                            onOpenPendingPayments();
                          case DrawerDestination.comite:
                            onOpenFieldCommittee();
                          case DrawerDestination.reportes:
                            onOpenSupervisionReports();
                          case DrawerDestination.monitor:
                            onOpenCoverageMonitor();
                          case DrawerDestination.simulador:
                            onOpenCreditSimulator();
                          case DrawerDestination.reasignacion:
                            onOpenTaskReassignment();
                          case DrawerDestination.usuarios:
                            onOpenUserManagement();
                          case DrawerDestination.formularios:
                            onOpenFormsConfiguration();
                          case DrawerDestination.configuracion:
                            onOpenAppSettings();
                        }
                      },
                    ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: _DailyPortfolioViewState.primary,
                    ),
                    title: const Text(
                      'Alertas',
                      style: TextStyle(color: _DailyPortfolioViewState.onSurface),
                    ),
                    trailing: unreadAlerts > 0
                        ? _DrawerBadge(count: unreadAlerts)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenAlerts();
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: _DailyPortfolioViewState.outlineVariant),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: _DailyPortfolioViewState.primary,
              ),
              title: const Text(
                'Cerrar sesion',
                style: TextStyle(color: _DailyPortfolioViewState.onSurface),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_DrawerSection> _sectionsForRole(UserRole role) {
    final sections = <_DrawerSection>[
      const _DrawerSection(
        DrawerDestination.cartera,
        'Cartera',
        Icons.account_balance_wallet_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.ruta,
        'Ruta',
        Icons.route_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.prospection,
        'Prospeccion',
        Icons.person_search_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.ficha,
        'Ficha',
        Icons.assignment_ind_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.solicitud,
        'Solicitud',
        Icons.note_add_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.simulador,
        'Simulador',
        Icons.calculate_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.documentos,
        'Documentos',
        Icons.folder_copy_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.mora,
        'Mora diaria',
        Icons.payments_outlined,
      ),
      const _DrawerSection(
        DrawerDestination.pagosPendientes,
        'Pagos pendientes',
        Icons.pending_actions_outlined,
      ),
    ];

    if (role == UserRole.superOperator ||
        role == UserRole.supervisor ||
        role == UserRole.administrator) {
      sections.add(
        const _DrawerSection(
          DrawerDestination.comite,
          'Comite en campo',
          Icons.groups_3_outlined,
        ),
      );
    }

    if (role == UserRole.supervisor || role == UserRole.administrator) {
      sections.addAll(const [
        _DrawerSection(
          DrawerDestination.reasignacion,
          'Reasignacion',
          Icons.swap_horiz_outlined,
        ),
        _DrawerSection(
          DrawerDestination.reportes,
          'Reportes',
          Icons.bar_chart_outlined,
        ),
        _DrawerSection(
          DrawerDestination.monitor,
          'Monitor en mapa',
          Icons.map_outlined,
        ),
      ]);
    }

    if (role == UserRole.administrator) {
      sections.addAll(const [
        _DrawerSection(
          DrawerDestination.usuarios,
          'Gestion de usuarios',
          Icons.manage_accounts_outlined,
        ),
        _DrawerSection(
          DrawerDestination.formularios,
          'Formularios',
          Icons.dynamic_form_outlined,
        ),
        _DrawerSection(
          DrawerDestination.configuracion,
          'Configuracion',
          Icons.settings_outlined,
        ),
      ]);
    }

    return sections;
  }
}

enum DrawerDestination {
  cartera,
  ruta,
  prospection,
  ficha,
  solicitud,
  documentos,
  mora,
  pagosPendientes,
  comite,
  reportes,
  monitor,
  simulador,
  reasignacion,
  usuarios,
  formularios,
  configuracion,
}

class _DrawerSection {
  const _DrawerSection(this.destination, this.label, this.icon);

  final DrawerDestination destination;
  final String label;
  final IconData icon;
}

class _DrawerBadge extends StatelessWidget {
  const _DrawerBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D4D),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.viewModel});

  final DailyPortfolioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _DailyPortfolioViewState.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _DailyPortfolioViewState.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              color: _DailyPortfolioViewState.primaryContainer,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CARTERA DEL DIA',
                            style: TextStyle(
                              color: _DailyPortfolioViewState.onSurfaceVariant,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${viewModel.totalCount} clientes · '
                            '${viewModel.visitedCount} visitados · '
                            '${viewModel.pendingCount} pendientes',
                            style: const TextStyle(
                              color: _DailyPortfolioViewState.onSurface,
                              fontSize: 18,
                              height: 26 / 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: viewModel.progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: _DailyPortfolioViewState
                                .surfaceContainerHighest,
                            color: _DailyPortfolioViewState.primaryContainer,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastSyncLabel(viewModel.lastSyncAt),
                            style: const TextStyle(
                              color: _DailyPortfolioViewState.onSurfaceVariant,
                              fontSize: 12,
                              height: 18 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _DailyPortfolioViewState.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.route,
                        color: _DailyPortfolioViewState.primary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastSyncLabel(DateTime? value) {
    if (value == null) {
      return 'Ultima actualizacion: sin sincronizar';
    }
    final now = DateTime.now();
    final isToday =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return 'Ultima actualizacion: ${isToday ? 'hoy' : _date(value)} $hour:$minute';
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.dragIndex,
    required this.onTap,
  });

  final DailyClient client;
  final int dragIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = client.managementType.color;
    final cardColor = client.isVisited
        ? _DailyPortfolioViewState.surfaceContainerHighest.withValues(
            alpha: 0.5,
          )
        : _DailyPortfolioViewState.surfaceContainerLow;

    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _DailyPortfolioViewState.outlineVariant.withValues(
              alpha: 0.3,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                client.clientName,
                                style: TextStyle(
                                  color: client.isVisited
                                      ? _DailyPortfolioViewState
                                            .onSurfaceVariant
                                      : _DailyPortfolioViewState.onSurface,
                                  fontSize: 18,
                                  height: 26 / 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusChip(client: client),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              label: client.managementType.label,
                              color: client.managementType.color,
                            ),
                            _InfoChip(
                              label: client.priorityLevel.label,
                              color: _priorityColor(client.priorityLevel),
                            ),
                            _InfoChip(
                              label: client.maskedDocument,
                              color:
                                  _DailyPortfolioViewState.secondaryContainer,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              color: _DailyPortfolioViewState.onSurfaceVariant,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'S/ ${client.creditAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color:
                                    _DailyPortfolioViewState.onSurfaceVariant,
                                fontSize: 13,
                                height: 18 / 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: dragIndex,
                child: Container(
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: _DailyPortfolioViewState.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.drag_indicator,
                    color: _DailyPortfolioViewState.outline,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(PriorityLevel priority) {
    return switch (priority) {
      PriorityLevel.high => const Color(0xFFFF4D4D),
      PriorityLevel.medium => const Color(0xFFFFC857),
      PriorityLevel.normal => _DailyPortfolioViewState.primaryContainer,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.client});

  final DailyClient client;

  @override
  Widget build(BuildContext context) {
    final borderColor = client.isVisited
        ? _DailyPortfolioViewState.primaryContainer
        : _DailyPortfolioViewState.secondaryContainer;
    final textColor = client.isVisited
        ? _DailyPortfolioViewState.primaryContainer
        : _DailyPortfolioViewState.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            client.isVisited ? Icons.check_circle_outline : Icons.schedule,
            color: textColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            client.visitStatus.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.9)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          height: 14 / 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: _DailyPortfolioViewState.onSurface),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o ultimos 4 digitos',
        hintStyle: const TextStyle(
          color: _DailyPortfolioViewState.onSurfaceVariant,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: _DailyPortfolioViewState.onSurfaceVariant,
        ),
        filled: true,
        fillColor: _DailyPortfolioViewState.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.viewModel});

  final DailyPortfolioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in PortfolioFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: viewModel.selectedFilter == filter,
                onSelected: (_) => viewModel.selectFilter(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _DailyPortfolioViewState.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _DailyPortfolioViewState.outlineVariant),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _DailyPortfolioViewState.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _VisitResult {
  const _VisitResult({required this.status, required this.observation});

  final VisitStatus status;
  final String observation;
}

class _VisitResultSheet extends StatefulWidget {
  const _VisitResultSheet({required this.client});

  final DailyClient client;

  @override
  State<_VisitResultSheet> createState() => _VisitResultSheetState();
}

class _VisitResultSheetState extends State<_VisitResultSheet> {
  VisitStatus _status = VisitStatus.visited;
  final _observationController = TextEditingController();

  @override
  void dispose() {
    _observationController.dispose();
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
            widget.client.clientName,
            style: const TextStyle(
              color: _DailyPortfolioViewState.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in const [
                VisitStatus.visited,
                VisitStatus.notFound,
                VisitStatus.rescheduled,
                VisitStatus.closedBusiness,
              ])
                ChoiceChip(
                  label: Text(status.label),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observationController,
            maxLength: 200,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: _DailyPortfolioViewState.onSurface),
            decoration: InputDecoration(
              labelText: 'Observacion',
              filled: true,
              fillColor: _DailyPortfolioViewState.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                _VisitResult(
                  status: _status,
                  observation: _observationController.text.trim(),
                ),
              );
            },
            child: const Text('Confirmar resultado'),
          ),
        ],
      ),
    );
  }
}

class _PortfolioBottomNavigation extends StatelessWidget {
  const _PortfolioBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: _DailyPortfolioViewState.surfaceContainerLowest,
        indicatorColor: _DailyPortfolioViewState.primaryFixedDim,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, height: 14 / 11),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(
              Icons.account_balance_wallet,
              color: _DailyPortfolioViewState.onPrimaryFixed,
            ),
            label: 'Cartera',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(
              Icons.location_on,
              color: _DailyPortfolioViewState.onPrimaryFixed,
            ),
            label: 'Ruta',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(
              Icons.group,
              color: _DailyPortfolioViewState.onPrimaryFixed,
            ),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(
              Icons.person,
              color: _DailyPortfolioViewState.onPrimaryFixed,
            ),
            label: 'Perfil',
          ),
        ],
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}
