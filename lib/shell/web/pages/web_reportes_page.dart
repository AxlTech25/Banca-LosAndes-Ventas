import 'package:flutter/material.dart';

import '../../../core/theme/web_theme.dart';
import '../../../features/auth/models/auth_session.dart';
import '../../../features/supervision/views/productivity_report_view.dart';
import '../web_shell_widgets.dart';

/// Reportes web sin mapa de cobertura.
class WebReportesPage extends StatelessWidget {
  const WebReportesPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: 'Reportes',
            session: session,
            subtitle:
                'Productividad de ${session.displayName} · sin mapa en web',
          ),
          const SizedBox(height: 24),
          _ReportCard(
            icon: Icons.bar_chart_outlined,
            title: 'Productividad mensual',
            subtitle:
                'Solicitudes enviadas, aprobadas y desembolsadas por asesor.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WebEmbeddedTheme(
                    child: ProductivityReportView(session: session),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: WebTheme.brandCyanLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: WebTheme.brandCyanDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WebTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
