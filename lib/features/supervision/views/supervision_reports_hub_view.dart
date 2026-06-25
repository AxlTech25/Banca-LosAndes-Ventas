import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import 'coverage_monitor_view.dart';
import 'productivity_report_view.dart';

class SupervisionReportsHubView extends StatelessWidget {
  const SupervisionReportsHubView({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Reportes de supervision'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubCard(
            icon: Icons.bar_chart_outlined,
            title: 'Productividad mensual',
            subtitle:
                'Solicitudes enviadas, aprobadas y desembolsadas por asesor.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductivityReportView(session: session),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.map_outlined,
            title: 'Monitor de cobertura',
            subtitle:
                'Mapa en vivo y avance de visitas del dia por asesor.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CoverageMonitorView(session: session),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
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
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
