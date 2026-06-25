import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../features/auth/models/auth_session.dart';
import '../../../core/theme/web_theme.dart';
import '../../../features/portfolio/data/daily_portfolio_repository.dart';
import '../../../features/portfolio/models/daily_client.dart';
import '../../../features/portfolio/viewmodels/daily_portfolio_view_model.dart';
import '../web_shell_widgets.dart';

class WebPortfolioPage extends StatefulWidget {
  const WebPortfolioPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<WebPortfolioPage> createState() => _WebPortfolioPageState();
}

class _WebPortfolioPageState extends State<WebPortfolioPage> {
  DailyPortfolioViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final vm = DailyPortfolioViewModel(
      repository: DailyPortfolioRepository(
        client: supabase.Supabase.instance.client,
        advisorId: widget.session.advisorId,
        preferences: prefs,
      ),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    if (!mounted) {
      vm.dispose();
      return;
    }
    setState(() => _viewModel = vm);
    await vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _viewModel;
    if (vm == null || vm.isLoading) {
      return const WebPageContainer(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final clients = vm.filteredClients;

    return WebPageContainer(
      maxWidth: 1400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cartera del dia',
                  style: TextStyle(
                    color: WebTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: vm.load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar cartera',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${clients.length} clientes asignados a ${widget.session.displayName}',
            style: const TextStyle(color: WebTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar cliente o DNI...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: vm.updateSearch,
          ),
          const SizedBox(height: 16),
          if (vm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Container(
            decoration: WebTheme.cardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    WebTheme.pageBackground,
                  ),
                  columns: const [
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('DNI')),
                    DataColumn(label: Text('Gestion')),
                    DataColumn(label: Text('Prioridad')),
                    DataColumn(label: Text('Visita')),
                    DataColumn(label: Text('Monto')),
                  ],
                  rows: [
                    for (final client in clients)
                      DataRow(cells: [
                        DataCell(Text(client.clientName)),
                        DataCell(Text(client.maskedDocument)),
                        DataCell(Text(client.managementType.label)),
                        DataCell(Text('${client.priorityScore}')),
                        DataCell(_VisitBadge(status: client.visitStatus)),
                        DataCell(Text(formatWebCurrency(client.creditAmount))),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  const _VisitBadge({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.isCompleted
        ? const Color(0xFF27C46B)
        : const Color(0xFFFF9800);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
