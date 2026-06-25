import 'package:flutter/material.dart';

import '../../core/theme/web_theme.dart';
import '../../features/auth/models/auth_session.dart';
import '../../features/auth/models/user_role.dart';
import '../../shared/widgets/banco_los_andes_logo.dart';

enum WebNavSection {
  inicio,
  cartera,
  solicitudes,
  evaluacion,
  cobranza,
  reportes,
}

extension WebNavSectionX on WebNavSection {
  String get label => switch (this) {
    WebNavSection.inicio => 'Inicio',
    WebNavSection.cartera => 'Cartera',
    WebNavSection.solicitudes => 'Solicitudes',
    WebNavSection.evaluacion => 'Evaluacion',
    WebNavSection.cobranza => 'Cobranza',
    WebNavSection.reportes => 'Reportes',
  };

  IconData get icon => switch (this) {
    WebNavSection.inicio => Icons.home_outlined,
    WebNavSection.cartera => Icons.account_balance_wallet_outlined,
    WebNavSection.solicitudes => Icons.description_outlined,
    WebNavSection.evaluacion => Icons.fact_check_outlined,
    WebNavSection.cobranza => Icons.payments_outlined,
    WebNavSection.reportes => Icons.bar_chart_outlined,
  };
}

List<WebNavSection> webNavSectionsFor(UserRole role) {
  return WebNavSection.values;
}

String formatWebCurrency(double value) => 'S/ ${value.toStringAsFixed(2)}';

class WebHeader extends StatelessWidget {
  const WebHeader({
    super.key,
    required this.session,
    required this.clockText,
    required this.onLogout,
  });

  final AuthSession session;
  final String clockText;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(session.displayName);

    return Container(
      decoration: const BoxDecoration(gradient: WebTheme.headerGradient),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const _BrandLogo(),
            const Spacer(),
            Text(
              clockText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 24),
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'logout') {
                  onLogout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${session.role.label} · ${session.employeeCode}',
                        style: const TextStyle(
                          color: WebTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('Cerrar sesion'),
                    ],
                  ),
                ),
              ],
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${session.role.label} · ${session.employeeCode}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BancoLosAndesLogo(
          height: 44,
          width: 44,
          onDarkBackground: true,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Banco Los Andes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.1,
              ),
            ),
            Text(
              'Fuerza de Ventas',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WebNavBar extends StatelessWidget {
  const WebNavBar({
    super.key,
    required this.sections,
    required this.selected,
    required this.onSelected,
    this.approvalBadgeCount = 0,
  });

  final List<WebNavSection> sections;
  final WebNavSection selected;
  final ValueChanged<WebNavSection> onSelected;
  final int approvalBadgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final section in sections)
              _NavTab(
                label: section.label,
                icon: section.icon,
                selected: section == selected,
                badgeCount: section == WebNavSection.solicitudes
                    ? approvalBadgeCount
                    : 0,
                onTap: () => onSelected(section),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? WebTheme.navActive : WebTheme.navInactive;

    Widget tab = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? WebTheme.navActive : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    if (badgeCount > 0) {
      tab = Badge(
        label: Text('$badgeCount'),
        child: tab,
      );
    }

    return tab;
  }
}

/// Encabezado de pagina web con titulo y datos del operador conectado.
class WebPageHeader extends StatelessWidget {
  const WebPageHeader({
    super.key,
    required this.title,
    required this.session,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final AuthSession session;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: WebTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle ??
                    '${session.displayName} · ${session.role.label} · '
                    '${session.employeeCode}',
                style: const TextStyle(
                  color: WebTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Contenedor de contenido con fondo claro para secciones embebidas.
class WebPageContainer extends StatelessWidget {
  const WebPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WebTheme.pageBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tema claro aplicado a widgets que usan AppColors oscuros (móvil).
class WebEmbeddedTheme extends StatelessWidget {
  const WebEmbeddedTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: WebTheme.pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: WebTheme.brandCyan,
          brightness: Brightness.light,
          primary: WebTheme.brandCyanDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: WebTheme.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
      ),
      child: ColoredBox(
        color: WebTheme.pageBackground,
        child: child,
      ),
    );
  }
}
