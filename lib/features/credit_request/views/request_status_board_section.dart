import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/status_notifications_view_model.dart';

class RequestStatusBoardSection extends StatefulWidget {
  const RequestStatusBoardSection({
    super.key,
    required this.viewModel,
    required this.onOpenRequest,
  });

  final RequestStatusBoardViewModel viewModel;
  final ValueChanged<SubmittedCreditRequest> onOpenRequest;

  @override
  State<RequestStatusBoardSection> createState() =>
      _RequestStatusBoardSectionState();
}

class _RequestStatusBoardSectionState extends State<RequestStatusBoardSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: RequestStatusTab.values.length,
      vsync: this,
      initialIndex: RequestStatusTab.values.indexOf(
        RequestStatusTab.enComite,
      ),
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      widget.viewModel.setTab(RequestStatusTab.values[_tabController.index]);
    }
  }

  void _applyAmountFilter() {
    final min = double.tryParse(_minAmountController.text.trim());
    final max = double.tryParse(_maxAmountController.text.trim());
    widget.viewModel.setAmountRange(min: min, max: max);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final summary = viewModel.summary;
    final requests = viewModel.filteredRequests;

    return Column(
      children: [
        if (viewModel.isOfflineData)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _OfflineBanner(),
          ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.onSurface,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: [
            for (final tab in RequestStatusTab.values)
              Tab(
                text: '${tab.label} (${summary.countForTab(tab)})',
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<RequestDateRangeFilter>(
                  initialValue: viewModel.dateFilter,
                  dropdownColor: AppColors.surfaceContainer,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Periodo',
                    isDense: true,
                  ),
                  items: [
                    for (final filter in RequestDateRangeFilter.values)
                      DropdownMenuItem(
                        value: filter,
                        child: Text(filter.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.setDateFilter(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _minAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Min S/',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _maxAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Max S/',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: _applyAmountFilter,
                icon: const Icon(Icons.filter_alt_outlined),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.load,
            child: viewModel.isLoading && requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 48),
                      Center(
                        child: Text(
                          'Sin solicitudes en esta pestana.',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return _TrackingCard(
                        request: request,
                        onTap: () => widget.onOpenRequest(request),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.request, required this.onTap});

  final SubmittedCreditRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(request.status.colorValue);

    return Card(
      color: AppColors.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.expedienteNumber,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      request.status.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.clientName,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '${formatCurrency(request.requestedAmount)} · '
                '${request.daysSinceSubmission} dias desde envio',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
              if (request.assignedAnalyst != null &&
                  request.assignedAnalyst!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Analista: ${request.assignedAnalyst}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.onSurfaceVariant),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mostrando ultimo estado descargado.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
