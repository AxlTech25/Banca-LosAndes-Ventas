import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../../portfolio/models/daily_client.dart';
import '../data/collection_repository.dart';
import '../models/collection_models.dart';
import '../viewmodels/collection_board_view_model.dart';
import 'collection_action_sheet.dart';

class CollectionBoardView extends StatefulWidget {
  const CollectionBoardView({
    super.key,
    required this.session,
    this.portfolioClients = const [],
  });

  final AuthSession session;
  final List<DailyClient> portfolioClients;

  @override
  State<CollectionBoardView> createState() => _CollectionBoardViewState();
}

class _CollectionBoardViewState extends State<CollectionBoardView> {
  CollectionBoardViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final viewModel = CollectionBoardViewModel(
      repository: CollectionRepository(
        client: Supabase.instance.client,
        advisorId: widget.session.advisorId,
        preferences: preferences,
      ),
      portfolioClients: widget.portfolioClients,
    )..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
    await viewModel.load();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openActionSheet(OverdueClientEntry client) async {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }

    final form = await showModalBottomSheet<CollectionActionFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) => CollectionActionSheet(client: client),
    );
    if (form == null) {
      return;
    }

    await viewModel.registerAction(client: client, form: form);
    if (!mounted || viewModel.successMessage == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(viewModel.successMessage!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final summary = viewModel?.summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Mora diaria'),
      ),
      body: viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (viewModel.errorMessage != null)
                    _MessageBox(text: viewModel.errorMessage!, isError: true),
                  if (summary != null) ...[
                    _TotalOverdueBanner(
                      clientCount: summary.overdueClients,
                      totalAmount: summary.totalOverdueAmount,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Semáforo: amarillo 1-30d · naranja 31-60d · rojo +60d',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Resumen del dia',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SummaryChip(
                          label: 'Clientes en mora',
                          value: '${summary.overdueClients}',
                          color: const Color(0xFFFF4D4D),
                        ),
                        _SummaryChip(
                          label: 'Monto vencido',
                          value: formatCurrency(summary.totalOverdueAmount),
                          color: AppColors.primary,
                        ),
                        _SummaryChip(
                          label: 'Gestiones hoy',
                          value: '${summary.actionsToday}',
                          color: const Color(0xFF27C46B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'Cartera vencida',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (viewModel.isLoading && viewModel.overdueClients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (viewModel.overdueClients.isEmpty)
                    const Text(
                      'No hay clientes en mora asignados.',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    )
                  else
                    for (final client in viewModel.overdueClients)
                      _OverdueCard(
                        client: client,
                        onManage: () => _openActionSheet(client),
                      ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gestiones recientes',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (viewModel.recentActions.isEmpty)
                    const Text(
                      'Aun no hay gestiones registradas.',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    )
                  else
                    for (final action in viewModel.recentActions)
                      _ActionTile(action: action),
                ],
              ),
            ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  const _OverdueCard({required this.client, required this.onManage});

  final OverdueClientEntry client;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final urgency = client.urgency;

    return Card(
      color: AppColors.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: urgency.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.clientName,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        urgency.label,
                        style: TextStyle(
                          color: urgency.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: urgency.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: urgency.color),
                  ),
                  child: Text(
                    '${client.daysPastDue}d mora',
                    style: TextStyle(
                      color: urgency.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(client.overdueAmount),
              style: const TextStyle(color: AppColors.primary),
            ),
            if (client.lastContactDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ultimo contacto: ${_formatDate(client.lastContactDate!)}',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onManage,
              child: const Text('Registrar gestion'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final CollectionActionRecord action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action.clientName,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${action.managementType.label} · ${action.result.label}',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          if (action.amountPaid != null)
            Text(
              'Pago: ${formatCurrency(action.amountPaid!)}',
              style: const TextStyle(color: AppColors.primary),
            ),
          if (action.commitmentAmount != null &&
              action.commitmentDate != null)
            Text(
              'Compromiso ${formatCurrency(action.commitmentAmount!)} '
              'para ${_formatDate(action.commitmentDate!)}',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _TotalOverdueBanner extends StatelessWidget {
  const _TotalOverdueBanner({
    required this.clientCount,
    required this.totalAmount,
  });

  final int clientCount;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D4D).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4D4D).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monto total vencido: ${formatCurrency(totalAmount)}',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$clientCount cliente(s) en mora',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFF4D4D) : AppColors.primary,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
