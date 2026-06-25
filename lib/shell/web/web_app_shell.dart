import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/models/auth_session.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/dashboard/viewmodels/dashboard_view_model.dart';
import '../../features/dashboard/views/web_dashboard_view.dart';
import '../../core/theme/web_theme.dart';
import 'pages/web_cobranza_page.dart';
import 'pages/web_evaluacion_page.dart';
import 'pages/web_portfolio_page.dart';
import 'pages/web_reportes_page.dart';
import 'pages/web_solicitudes_page.dart';
import 'web_shell_widgets.dart';

class WebAppShell extends StatefulWidget {
  const WebAppShell({
    super.key,
    required this.authRepository,
    required this.session,
  });

  final AuthRepository authRepository;
  final AuthSession session;

  @override
  State<WebAppShell> createState() => _WebAppShellState();
}

class _WebAppShellState extends State<WebAppShell> {
  WebNavSection _section = WebNavSection.inicio;
  DashboardViewModel? _dashboardViewModel;
  String _clockText = _formatClock(DateTime.now());
  Timer? _clockTimer;
  int _solicitudesTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initDashboard();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _clockText = _formatClock(DateTime.now()));
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _dashboardViewModel?.dispose();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    final vm = DashboardViewModel(
      repository: DashboardRepository(
        client: supabase.Supabase.instance.client,
        advisorId: widget.session.advisorId,
        agencyId: widget.session.agencyId,
      ),
      role: widget.session.role,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    setState(() => _dashboardViewModel = vm);
    await vm.load();
  }

  static String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _navigate(WebNavSection section, {int solicitudesTab = 0}) {
    setState(() {
      _section = section;
      _solicitudesTabIndex = solicitudesTab;
    });
  }

  Future<void> _logout() async {
    await widget.authRepository.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginView(authRepository: widget.authRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = webNavSectionsFor(widget.session.role);
    final dashboard = _dashboardViewModel;
    final approvalBadge = dashboard?.summary?.readyForApproval ?? 0;

    return Scaffold(
      backgroundColor: WebTheme.pageBackground,
      body: Column(
        children: [
          WebHeader(
            session: widget.session,
            clockText: _clockText,
            onLogout: _logout,
          ),
          WebNavBar(
            sections: sections,
            selected: _section,
            approvalBadgeCount: approvalBadge,
            onSelected: (section) {
              if (section == WebNavSection.solicitudes) {
                _navigate(
                  section,
                  solicitudesTab: widget.session.role.canApproveClientAppRequests
                      ? 1
                      : 0,
                );
              } else {
                _navigate(section);
              }
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_section) {
      case WebNavSection.inicio:
        final dashboard = _dashboardViewModel;
        return WebDashboardView(
          session: widget.session,
          summary: dashboard?.summary,
          isLoading: dashboard?.isLoading ?? true,
          errorMessage: dashboard?.errorMessage,
          onRefresh: () => dashboard?.load(),
          onNavigate: (section) {
            if (section == WebNavSection.solicitudes &&
                widget.session.role.canApproveClientAppRequests) {
              _navigate(section, solicitudesTab: 1);
            } else {
              _navigate(section);
            }
          },
        );
      case WebNavSection.cartera:
        return WebPortfolioPage(session: widget.session);
      case WebNavSection.solicitudes:
        return WebSolicitudesPage(
          session: widget.session,
          initialTabIndex: _solicitudesTabIndex,
        );
      case WebNavSection.evaluacion:
        return WebEvaluacionPage(session: widget.session);
      case WebNavSection.cobranza:
        return WebCobranzaPage(session: widget.session);
      case WebNavSection.reportes:
        return WebReportesPage(session: widget.session);
    }
  }
}
