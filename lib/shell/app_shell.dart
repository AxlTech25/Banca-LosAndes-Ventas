import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/auth_session.dart';
import '../features/portfolio/views/daily_portfolio_view.dart';
import 'web/web_app_shell.dart';

/// Punto de entrada post-login segun plataforma.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.authRepository,
    required this.session,
  });

  final AuthRepository authRepository;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebAppShell(
        authRepository: authRepository,
        session: session,
      );
    }

    return DailyPortfolioView(
      authRepository: authRepository,
      session: session,
    );
  }
}
