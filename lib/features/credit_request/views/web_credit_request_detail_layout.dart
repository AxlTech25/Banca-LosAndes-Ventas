import 'package:flutter/material.dart';

import '../../../core/theme/web_theme.dart';

/// Organiza las secciones del detalle en una o dos columnas según el ancho.
class WebCreditRequestDetailLayout extends StatelessWidget {
  const WebCreditRequestDetailLayout({
    super.key,
    required this.primarySections,
    required this.secondarySections,
    this.maxWidth = 1400,
  });

  final List<Widget> primarySections;
  final List<Widget> secondarySections;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;

        if (!wide) {
          return _SectionColumn(
            sections: [...primarySections, ...secondarySections],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _SectionColumn(sections: primarySections),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _SectionColumn(sections: secondarySections),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          sections[i],
        ],
      ],
    );
  }
}

/// Barra superior del detalle en web con datos del expediente.
class WebCreditRequestDetailHeader extends StatelessWidget {
  const WebCreditRequestDetailHeader({
    super.key,
    required this.expedienteNumber,
    required this.clientName,
    required this.statusLabel,
    required this.statusColor,
    this.operatorName,
  });

  final String expedienteNumber;
  final String clientName;
  final String statusLabel;
  final Color statusColor;
  final String? operatorName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0x14000000)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expedienteNumber,
                  style: const TextStyle(
                    color: WebTheme.brandCyanDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  clientName,
                  style: const TextStyle(
                    color: WebTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (operatorName != null)
                  Text(
                    'Gestionado por $operatorName',
                    style: const TextStyle(
                      color: WebTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
