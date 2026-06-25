import '../../client_profile/models/portfolio_alert.dart';
import 'advisor_notification_models.dart';

enum AdvisorInboxSource { portfolio, appCliente }

class AdvisorInboxItem {
  AdvisorInboxItem.portfolio(PortfolioAlert alert)
    : source = AdvisorInboxSource.portfolio,
      alert = alert,
      notification = null,
      id = alert.id,
      isRead = alert.isRead,
      createdAt = alert.createdAt,
      headline = alert.clientName,
      category = alert.type.label,
      message = alert.message;

  AdvisorInboxItem.appCliente(AdvisorNotification notification)
    : source = AdvisorInboxSource.appCliente,
      alert = null,
      notification = notification,
      id = notification.id,
      isRead = notification.isRead,
      createdAt = notification.createdAt,
      headline = notification.title,
      category = notification.type.label,
      message = notification.message;

  final AdvisorInboxSource source;
  final PortfolioAlert? alert;
  final AdvisorNotification? notification;

  final String id;
  final bool isRead;
  final DateTime createdAt;
  final String headline;
  final String category;
  final String message;
}
