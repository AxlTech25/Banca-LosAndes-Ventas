import 'package:flutter/material.dart';

import '../../../core/theme/web_theme.dart';
import '../../../features/auth/models/auth_session.dart';
import '../../../features/prospection/views/pre_evaluation_view.dart';
import 'web_solicitudes_page.dart';
import '../web_shell_widgets.dart';

class WebEvaluacionPage extends StatelessWidget {
  const WebEvaluacionPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: 'Evaluacion crediticia',
            session: session,
            subtitle:
                'Pre-evaluacion, buro y checklist · ${session.displayName}',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _EvalCard(
                title: 'Pre-evaluar prospecto',
                subtitle: 'Formulario de capacidad de pago',
                icon: Icons.fact_check_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WebEmbeddedTheme(
                        child: Scaffold(
                          appBar: AppBar(title: const Text('Pre-evaluacion')),
                          body: PreEvaluationView(session: session),
                        ),
                      ),
                    ),
                  );
                },
              ),
              _EvalCard(
                title: 'Solicitudes en evaluacion',
                subtitle: 'Checklist visita, pre-eval y buro',
                icon: Icons.description_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WebSolicitudesPage(
                        session: session,
                        initialTabIndex:
                            session.role.canApproveClientAppRequests ? 1 : 0,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvalCard extends StatelessWidget {
  const _EvalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: WebTheme.cardDecoration(),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 32, color: WebTheme.brandCyanDark),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
