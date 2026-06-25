import 'package:flutter/material.dart';

import '../../auth/models/auth_session.dart';
import '../viewmodels/clients_directory_view_model.dart';
import 'clients_directory_content.dart';

class ClientsDirectoryTab extends StatelessWidget {
  const ClientsDirectoryTab({
    super.key,
    required this.session,
    required this.viewModel,
  });

  final AuthSession session;
  final ClientsDirectoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ClientsDirectoryContent(
      session: session,
      viewModel: viewModel,
      showHeader: false,
    );
  }
}
