import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/supervision_repository.dart';
import '../models/supervision_models.dart';
import '../viewmodels/productivity_report_view_model.dart';

class ProductivityReportView extends StatefulWidget {
  const ProductivityReportView({super.key, required this.session});

  final AuthSession session;

  @override
  State<ProductivityReportView> createState() => _ProductivityReportViewState();
}

class _ProductivityReportViewState extends State<ProductivityReportView> {
  ProductivityReportViewModel? _viewModel;

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
    final viewModel = ProductivityReportViewModel(
      repository: SupervisionRepository(
        client: supabase.Supabase.instance.client,
        agencyId: widget.session.agencyId,
      ),
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

  Future<void> _pickMonth() async {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedMonth,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Seleccionar mes',
    );
    if (picked != null) {
      await viewModel.pickMonth(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final report = viewModel?.report;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Productividad mensual'),
        actions: [
          IconButton(
            onPressed: viewModel == null || viewModel.isLoading
                ? null
                : _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Cambiar mes',
          ),
          IconButton(
            onPressed: viewModel == null ||
                    viewModel.isLoading ||
                    viewModel.isExporting ||
                    report == null
                ? null
                : viewModel.exportPdf,
            icon: viewModel?.isExporting == true
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
          ),
        ],
      ),
      body: viewModel == null || viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? Center(
              child: Text(
                viewModel.errorMessage ?? 'No hay datos para este mes.',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MonthSummary(report: report),
                const SizedBox(height: 16),
                if (viewModel.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      viewModel.errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF4D4D)),
                    ),
                  ),
                _ProductivityChart(rows: report.rows),
                const SizedBox(height: 16),
                _ProductivityTable(rows: report.rows),
              ],
            ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.report});

  final AgencyProductivityReport report;

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${monthAbbreviation(report.month)} ${report.month.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.totalSubmitted} enviadas · '
            '${report.totalDisbursed} desembolsadas · '
            '${formatCurrency(report.totalDisbursedAmount)}',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProductivityChart extends StatelessWidget {
  const _ProductivityChart({required this.rows});

  final List<AdvisorProductivityRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = rows
        .map((row) => row.submittedCount.toDouble())
        .fold<double>(0, (max, value) => value > max ? value : max);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxValue == 0 ? 4 : maxValue + 1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= rows.length) {
                    return const SizedBox.shrink();
                  }
                  final code = rows[index].advisor.employeeCode;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var index = 0; index < rows.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: rows[index].submittedCount.toDouble(),
                    color: AppColors.primary.withValues(alpha: 0.45),
                    width: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: rows[index].approvedCount.toDouble(),
                    color: const Color(0xFF27C46B),
                    width: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: rows[index].disbursedCount.toDouble(),
                    color: const Color(0xFF6ED2FF),
                    width: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                barsSpace: 4,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductivityTable extends StatelessWidget {
  const _ProductivityTable({required this.rows});

  final List<AdvisorProductivityRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Asesor',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Env.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Aprob.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Desemb.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Monto',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Tasa',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows) _ProductivityTableRow(row: row),
        ],
      ),
    );
  }
}

class _ProductivityTableRow extends StatelessWidget {
  const _ProductivityTableRow({required this.row});

  final AdvisorProductivityRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.advisor.displayName,
                  style: const TextStyle(color: AppColors.onSurface),
                ),
                Text(
                  row.advisor.employeeCode,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${row.submittedCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            child: Text(
              '${row.approvedCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            child: Text(
              '${row.disbursedCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCurrency(row.disbursedAmount),
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              '${row.conversionPercent}%',
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
