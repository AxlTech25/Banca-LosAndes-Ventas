import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../notifications/models/advisor_inbox_item.dart';
import '../../notifications/models/advisor_notification_models.dart';
import '../models/portfolio_alert.dart';
import '../viewmodels/portfolio_alerts_view_model.dart';

class PortfolioAlertsSheet extends StatelessWidget {
  const PortfolioAlertsSheet({
    super.key,
    required this.viewModel,
    required this.onInboxItemTap,
  });

  final PortfolioAlertsViewModel viewModel;
  final ValueChanged<AdvisorInboxItem> onInboxItemTap;

  @override
  Widget build(BuildContext context) {
    final items = viewModel.inboxItems;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alertas y notificaciones',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (viewModel.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D4D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${viewModel.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (viewModel.isLoading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No tienes alertas ni notificaciones recientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _InboxTile(
                      item: item,
                      onTap: () => onInboxItemTap(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.onTap});

  final AdvisorInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.isRead
          ? AppColors.surfaceContainerLow
          : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isRead
                  ? AppColors.outlineVariant.withValues(alpha: 0.3)
                  : const Color(0xFFFF4D4D).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconForItem(item),
                color: item.isRead
                    ? AppColors.onSurfaceVariant
                    : const Color(0xFFFF4D4D),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.headline,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.category,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D4D),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForItem(AdvisorInboxItem item) {
    return switch (item.source) {
      AdvisorInboxSource.portfolio => _iconForPortfolioType(item.alert!.type),
      AdvisorInboxSource.appCliente => _iconForAppType(item.notification!.type),
    };
  }

  IconData _iconForPortfolioType(PortfolioAlertType type) {
    return switch (type) {
      PortfolioAlertType.firstOverdueDay => Icons.warning_amber_outlined,
      PortfolioAlertType.overdue30 || PortfolioAlertType.overdue60 =>
        Icons.error_outline,
      PortfolioAlertType.partialPayment => Icons.payments_outlined,
      PortfolioAlertType.fullPayment => Icons.check_circle_outline,
    };
  }

  IconData _iconForAppType(AdvisorNotificationType type) {
    return switch (type) {
      AdvisorNotificationType.solicitudNueva => Icons.inbox_outlined,
      AdvisorNotificationType.chatCliente => Icons.chat_bubble_outline,
      AdvisorNotificationType.pagoPendiente => Icons.pending_actions_outlined,
    };
  }
}
