import 'package:flutter/material.dart';

import '../../../core/theme/web_theme.dart';
import '../../../features/auth/models/auth_session.dart';
import '../../../features/collection/views/collection_board_view.dart';
import '../web_shell_widgets.dart';

class WebCobranzaPage extends StatelessWidget {
  const WebCobranzaPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: WebTheme.pageBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: WebPageHeader(
              title: 'Cobranza',
              session: session,
              subtitle: 'Gestion de mora · ${session.displayName}',
            ),
          ),
        ),
        Expanded(
          child: WebEmbeddedTheme(
            child: CollectionBoardView(session: session),
          ),
        ),
      ],
    );
  }
}
