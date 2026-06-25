import 'package:flutter/material.dart';

import '../../../core/theme/web_theme.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/user_role.dart';
import '../models/dashboard_summary.dart';
import '../../../shell/web/web_shell_widgets.dart';

typedef WebQuickAction = ({
  String title,
  String subtitle,
  IconData icon,
  Color color,
  WebNavSection? section,
});

class WebDashboardView extends StatelessWidget {
  const WebDashboardView({
    super.key,
    required this.session,
    required this.summary,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onNavigate,
  });

  final AuthSession session;
  final DashboardSummary? summary;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final ValueChanged<WebNavSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final firstName = session.displayName.split(' ').first;
    final actions = _quickActions(session.role);

    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $firstName',
                      style: const TextStyle(
                        color: WebTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.displayName} · ${session.role.label}',
                      style: const TextStyle(
                        color: WebTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          if (isLoading && summary == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (summary != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                  children: [
                    _KpiCard(
                      title: 'Visitas pendientes',
                      value: '${summary!.pendingVisits}',
                      subtitle: 'de ${summary!.totalInPortfolio} en cartera',
                      icon: Icons.location_on_outlined,
                      iconColor: WebTheme.brandCyanDark,
                    ),
                    _KpiCard(
                      title: 'Gestionadas hoy',
                      value: '${summary!.managedToday}',
                      subtitle: 'visitas registradas',
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF26A69A),
                    ),
                    _KpiCard(
                      title: 'Monto en cartera',
                      value: formatWebCurrency(summary!.portfolioAmount),
                      subtitle: 'colocacion gestionada',
                      icon: Icons.trending_up,
                      iconColor: WebTheme.brandCyan,
                    ),
                    _KpiCard(
                      title: session.role.canApproveClientAppRequests
                          ? 'Listas para aprobar'
                          : 'Solicitudes aprobadas',
                      value: session.role.canApproveClientAppRequests
                          ? '${summary!.readyForApproval}'
                          : '${summary!.approvedThisMonth}',
                      subtitle: session.role.canApproveClientAppRequests
                          ? 'en su agencia'
                          : 'de este mes',
                      icon: Icons.assignment_turned_in_outlined,
                      iconColor: WebTheme.brandCyanDark,
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 32),
          const Text(
            'Accesos rapidos',
            style: TextStyle(
              color: WebTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1000 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.4,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _QuickAccessCard(
                    title: action.title,
                    subtitle: action.subtitle,
                    icon: action.icon,
                    color: action.color,
                    onTap: action.section == null
                        ? null
                        : () => onNavigate(action.section!),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  List<WebQuickAction> _quickActions(UserRole role) {
    final actions = <WebQuickAction>[
      (
        title: 'Cartera del dia',
        subtitle: 'Clientes asignados para visitar hoy',
        icon: Icons.work_outline,
        color: WebTheme.brandCyanDark,
        section: WebNavSection.cartera,
      ),
      (
        title: 'Nueva solicitud',
        subtitle: 'Registrar una solicitud de credito',
        icon: Icons.add_circle_outline,
        color: const Color(0xFF66BB6A),
        section: WebNavSection.solicitudes,
      ),
      (
        title: 'Pre-evaluar / Buro',
        subtitle: 'Capacidad de pago y listas negras',
        icon: Icons.shield_outlined,
        color: const Color(0xFFAB47BC),
        section: WebNavSection.evaluacion,
      ),
      (
        title: 'Cobranza',
        subtitle: 'Gestion de mora del dia',
        icon: Icons.savings_outlined,
        color: const Color(0xFFEF5350),
        section: WebNavSection.cobranza,
      ),
      (
        title: 'Mis solicitudes',
        subtitle: 'Tablero de estado de expedientes',
        icon: Icons.list_alt_outlined,
        color: WebTheme.brandCyan,
        section: WebNavSection.solicitudes,
      ),
      (
        title: 'Reportes',
        subtitle: 'Productividad del equipo',
        icon: Icons.insights_outlined,
        color: const Color(0xFFFF7043),
        section: WebNavSection.reportes,
      ),
    ];

    if (role.canApproveClientAppRequests) {
      actions.insert(
        4,
        (
          title: 'Por aprobar',
          subtitle: 'Solicitudes app clientes listas',
          icon: Icons.admin_panel_settings_outlined,
          color: WebTheme.brandCyanDark,
          section: WebNavSection.solicitudes,
        ),
      );
    }

    return actions;
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: WebTheme.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: WebTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: WebTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: WebTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: WebTheme.cardDecoration(),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WebTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WebTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: WebTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
