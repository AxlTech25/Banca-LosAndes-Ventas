import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/risk_semaphore.dart';
import '../../auth/models/auth_session.dart';
import '../../credit_request/models/credit_request_models.dart';
import '../../credit_request/services/credit_request_gatekeeper.dart';
import '../../portfolio/models/daily_client.dart';
import '../data/client_profile_repository.dart';
import '../models/client_profile.dart';
import '../viewmodels/client_profile_view_model.dart';

class ClientProfileView extends StatefulWidget {
  const ClientProfileView({
    super.key,
    required this.session,
    required this.dailyClient,
    this.onRegisterVisit,
    this.onRegisterDeserter,
    this.onRegisterCollection,
  });

  final AuthSession session;
  final DailyClient dailyClient;
  final VoidCallback? onRegisterVisit;
  final VoidCallback? onRegisterDeserter;
  final VoidCallback? onRegisterCollection;

  @override
  State<ClientProfileView> createState() => _ClientProfileViewState();
}

class _ClientProfileViewState extends State<ClientProfileView> {
  ClientProfileViewModel? _viewModel;

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
    final repository = ClientProfileRepository(
      client: supabase.Supabase.instance.client,
      advisorId: widget.session.advisorId,
      preferences: preferences,
    );
    final viewModel = ClientProfileViewModel(repository: repository)
      ..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
    await viewModel.load(widget.dailyClient.clientId);
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _callClient(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el marcador telefonico.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final profile = viewModel?.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Ficha del cliente'),
        actions: [
          if (widget.onRegisterVisit != null)
            TextButton.icon(
              onPressed: widget.onRegisterVisit,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Visita'),
            ),
        ],
      ),
      body: viewModel == null || viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.errorMessage != null
          ? Center(
              child: Text(
                viewModel.errorMessage!,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          : profile == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: () => viewModel.load(widget.dailyClient.clientId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (viewModel.isOfflineData)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _OfflineBanner(),
                    ),
                  _HeaderSection(
                    profile: profile,
                    dailyClient: widget.dailyClient,
                  ),
                  if (widget.onRegisterDeserter != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: widget.onRegisterDeserter,
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Registrar desercion'),
                    ),
                  ],
                  if (widget.onRegisterCollection != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: widget.onRegisterCollection,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Registrar gestion de cobranza'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D4D),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ContactSection(
                    profile: profile,
                    onCall: () => _callClient(profile.phone),
                  ),
                  const SizedBox(height: 16),
                  _PositionSection(profile: profile),
                  const SizedBox(height: 16),
                  _PaymentChartSection(profile: profile),
                  const SizedBox(height: 16),
                  _CreditHistorySection(profile: profile),
                  const SizedBox(height: 16),
                  _PreapprovedSection(
                    profile: profile,
                    onUseOffer: () => _usePreapprovedOffer(context, profile),
                  ),
                  const SizedBox(height: 16),
                  _LocationSection(viewModel: viewModel, profile: profile),
                  if (viewModel.locationMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      viewModel.locationMessage!,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _usePreapprovedOffer(BuildContext context, ClientProfile profile) {
    final offer = profile.preapproved;
    if (offer == null) {
      return;
    }

    CreditRequestGatekeeper.openFromLaunch(
      context,
      session: widget.session,
      launch: CreditRequestLaunchData.fromPreapproved(
        profile: profile,
        offer: offer,
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
              'Datos descargados en la ultima sincronizacion.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.profile,
    required this.dailyClient,
  });

  final ClientProfile profile;
  final DailyClient dailyClient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceContainerHighest,
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  maskDocument(profile.documentNumber),
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                RiskSemaphore(rating: profile.sbsRating, compact: true),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dailyClient.managementType.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: dailyClient.managementType.color.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Text(
                    dailyClient.managementType.label,
                    style: TextStyle(
                      color: dailyClient.managementType.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.profile, required this.onCall});

  final ClientProfile profile;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Datos de contacto y negocio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Direccion', value: profile.address),
          _InfoRow(label: 'Telefono', value: profile.phone),
          _InfoRow(label: 'Negocio', value: profile.businessName),
          _InfoRow(label: 'Tipo', value: profile.businessType),
          _InfoRow(
            label: 'Antiguedad',
            value: '${profile.businessAgeMonths ~/ 12}a ${profile.businessAgeMonths % 12}m',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: profile.phone.isEmpty ? null : onCall,
            icon: const Icon(Icons.phone_outlined),
            label: const Text('Llamar'),
          ),
        ],
      ),
    );
  }
}

class _PositionSection extends StatelessWidget {
  const _PositionSection({required this.profile});

  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    final position = profile.position;
    return _SectionCard(
      title: 'Posicion del cliente',
      child: Column(
        children: [
          _MetricGrid(
            items: [
              _MetricItem('Deuda total', formatCurrency(position.totalDebt)),
              _MetricItem('Cuentas vigentes', '${position.activeAccounts}'),
              _MetricItem('En mora', '${position.overdueAccounts}'),
              _MetricItem(
                'Ultimo pago',
                position.lastPaymentDate == null
                    ? 'Sin registro'
                    : _formatDate(position.lastPaymentDate!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _PaymentChartSection extends StatelessWidget {
  const _PaymentChartSection({required this.profile});

  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Comportamiento de pagos (12 meses)',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= profile.paymentBehavior.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthAbbreviation(profile.paymentBehavior[index].month),
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < profile.paymentBehavior.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: profile.paymentBehavior[i].status ==
                                  PaymentMonthStatus.noInstallment
                              ? 0.2
                              : 1,
                          color: _barColor(profile.paymentBehavior[i].status),
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            items: [
              _MetricItem(
                'Pagos puntuales',
                '${profile.punctualPaymentPercentage.toStringAsFixed(0)}%',
              ),
              _MetricItem(
                'Dias promedio mora',
                profile.averageLateDays.toStringAsFixed(1),
              ),
              _MetricItem(
                'Total pagado',
                formatCurrency(profile.totalPaidAmount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _barColor(PaymentMonthStatus status) {
    return switch (status) {
      PaymentMonthStatus.onTime => const Color(0xFF27C46B),
      PaymentMonthStatus.late => const Color(0xFFFF4D4D),
      PaymentMonthStatus.noInstallment => const Color(0xFF86929A),
    };
  }
}

class _CreditHistorySection extends StatelessWidget {
  const _CreditHistorySection({required this.profile});

  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.creditHistory.isEmpty) {
      return const _SectionCard(
        title: 'Historial crediticio',
        child: Text(
          'Sin creditos registrados.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return _SectionCard(
      title: 'Historial crediticio',
      child: Column(
        children: [
          for (final credit in profile.creditHistory)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatCurrency(credit.amount),
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${credit.termMonths} meses · TEA ${credit.tea.toStringAsFixed(1)}% · ${credit.status}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    'Pagos puntuales: ${credit.punctualPaymentRate.toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreapprovedSection extends StatelessWidget {
  const _PreapprovedSection({
    required this.profile,
    required this.onUseOffer,
  });

  final ClientProfile profile;
  final VoidCallback onUseOffer;

  @override
  Widget build(BuildContext context) {
    final offer = profile.preapproved;
    if (offer == null || !offer.isValid) {
      return const _SectionCard(
        title: 'Oferta vigente',
        child: Text(
          'Sin oferta vigente. Puede iniciar solicitud nueva.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27C46B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Oferta vigente',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(offer.maxAmount),
            style: const TextStyle(
              color: Color(0xFF27C46B),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${offer.suggestedTermMonths} meses · TEA ${offer.referenceTea.toStringAsFixed(1)}%',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: offer.confidenceScore / 100,
            backgroundColor: AppColors.surfaceContainerHighest,
            color: const Color(0xFF27C46B),
          ),
          const SizedBox(height: 4),
          Text(
            'Confianza ${offer.confidenceScore}% · Vigente hasta ${_formatDate(offer.expirationDate)}',
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onUseOffer,
            child: const Text('Usar esta oferta'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.viewModel,
    required this.profile,
  });

  final ClientProfileViewModel viewModel;
  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ubicacion del negocio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.latitude != null && profile.longitude != null)
            Text(
              'Coordenadas: ${profile.latitude!.toStringAsFixed(5)}, '
              '${profile.longitude!.toStringAsFixed(5)}',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          if (viewModel.locationPreview != null) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.locationPreview!,
              style: const TextStyle(color: AppColors.onSurface),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: viewModel.discardCapturedLocation,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: viewModel.isUpdatingLocation
                        ? null
                        : viewModel.confirmCapturedLocation,
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ] else
            FilledButton.icon(
              onPressed: viewModel.isUpdatingLocation
                  ? null
                  : viewModel.captureBusinessLocation,
              icon: viewModel.isUpdatingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Actualizar ubicacion del negocio'),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}
