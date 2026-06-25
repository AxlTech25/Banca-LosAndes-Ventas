import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pre_evaluation_models.dart';
import '../viewmodels/campaigns_view_model.dart';

class ActiveCampaignsSection extends StatelessWidget {
  const ActiveCampaignsSection({
    super.key,
    required this.viewModel,
    required this.onManageCampaign,
  });

  final CampaignsViewModel viewModel;
  final ValueChanged<ActiveCampaign> onManageCampaign;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.campaigns.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.campaigns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: const Text(
          'Sin campanas activas en este periodo.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campanas activas',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.campaigns.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final campaign = viewModel.campaigns[index];
              return _CampaignCard(
                campaign: campaign,
                onManage: () => onManageCampaign(campaign),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign, required this.onManage});

  final ActiveCampaign campaign;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final color = Color(campaign.type.colorValue);
    final days = campaign.daysRemaining;

    return SizedBox(
      width: 260,
      height: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color),
              ),
              child: Text(
                campaign.type.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              campaign.clientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(campaign.offeredAmount),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              days <= 0
                  ? 'Vence hoy'
                  : 'Vence en $days dia${days == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: FilledButton(
                onPressed: onManage,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Gestionar ahora',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
