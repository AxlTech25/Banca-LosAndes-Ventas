import 'package:flutter/material.dart';

import '../../auth/views/login_view.dart';
import '../models/daily_client.dart';
import '../viewmodels/daily_portfolio_view_model.dart';

class DailyPortfolioView extends StatefulWidget {
  const DailyPortfolioView({super.key});

  @override
  State<DailyPortfolioView> createState() => _DailyPortfolioViewState();
}

class _DailyPortfolioViewState extends State<DailyPortfolioView> {
  late final DailyPortfolioViewModel _viewModel;

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
    _viewModel = DailyPortfolioViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopAppBar(onLogout: _logout),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _SummaryCard(totalVisits: _viewModel.totalVisits),
                  const SizedBox(height: 24),
                  ..._viewModel.clients.map(
                    (client) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ClientCard(client: client),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _PortfolioBottomNavigation(),
    );
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginView()),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({required this.onLogout});

  final VoidCallback onLogout;

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
          const Expanded(
            child: Text(
              'Cartera Diaria',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _DailyPortfolioViewState.primaryFixedDim,
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesi\u00F3n',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            color: _DailyPortfolioViewState.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalVisits});

  final int totalVisits;

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
                            'RESUMEN DEL D\u00CDA',
                            style: TextStyle(
                              color: _DailyPortfolioViewState.onSurfaceVariant,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$totalVisits',
                                style: const TextStyle(
                                  color: _DailyPortfolioViewState.onSurface,
                                  fontSize: 30,
                                  height: 38 / 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Total Visitas',
                                style: TextStyle(
                                  color:
                                      _DailyPortfolioViewState.onSurfaceVariant,
                                  fontSize: 14,
                                  height: 20 / 14,
                                ),
                              ),
                            ],
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
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});

  final DailyClient client;

  bool get isVisited => client.status == DailyClientStatus.visited;

  @override
  Widget build(BuildContext context) {
    final accentColor = isVisited
        ? _DailyPortfolioViewState.primaryContainer
        : _DailyPortfolioViewState.secondaryContainer;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _DailyPortfolioViewState.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _DailyPortfolioViewState.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: const TextStyle(
                              color: _DailyPortfolioViewState.onSurface,
                              fontSize: 20,
                              height: 28 / 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                client.typeIcon,
                                color:
                                    _DailyPortfolioViewState.onSurfaceVariant,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                client.typeLabel,
                                style: const TextStyle(
                                  color:
                                      _DailyPortfolioViewState.onSurfaceVariant,
                                  fontSize: 12,
                                  height: 18 / 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(client: client),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.client});

  final DailyClient client;

  bool get isVisited => client.status == DailyClientStatus.visited;

  @override
  Widget build(BuildContext context) {
    final borderColor = isVisited
        ? _DailyPortfolioViewState.primaryContainer
        : _DailyPortfolioViewState.secondaryContainer;
    final textColor = isVisited
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
          Icon(client.statusIcon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            client.statusLabel,
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

class _PortfolioBottomNavigation extends StatelessWidget {
  const _PortfolioBottomNavigation();

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
        selectedIndex: 0,
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(
              Icons.account_balance_wallet,
              color: _DailyPortfolioViewState.onPrimaryFixed,
            ),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Visits',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (_) {},
      ),
    );
  }
}
