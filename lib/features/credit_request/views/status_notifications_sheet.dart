import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/status_notifications_view_model.dart';

class StatusNotificationsSheet extends StatelessWidget {
  const StatusNotificationsSheet({
    super.key,
    required this.viewModel,
    required this.onOpenRequest,
  });

  final StatusNotificationsViewModel viewModel;
  final ValueChanged<StatusChangeNotification> onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final notifications = viewModel.notifications;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Decisiones del comite',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (viewModel.unreadCount > 0)
                  TextButton(
                    onPressed: viewModel.markAllRead,
                    child: const Text('Marcar leidas'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aun no hay decisiones registradas.',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () async {
                        await viewModel.markRead(notification.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          onOpenRequest(notification);
                        }
                      },
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final StatusChangeNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(notification.status.colorValue);

    return Material(
      color: notification.read
          ? AppColors.surfaceContainer
          : AppColors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notification.read ? Colors.transparent : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.expedienteNumber,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      notification.message,
                      style: const TextStyle(color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
