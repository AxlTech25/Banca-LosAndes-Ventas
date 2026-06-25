import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/clients_directory_repository.dart';
import '../viewmodels/clients_directory_view_model.dart';
import 'clients_directory_content.dart';

class ClientsDirectoryView extends StatefulWidget {
  const ClientsDirectoryView({super.key, required this.session});

  final AuthSession session;

  @override
  State<ClientsDirectoryView> createState() => _ClientsDirectoryViewState();
}

class _ClientsDirectoryViewState extends State<ClientsDirectoryView> {
  ClientsDirectoryViewModel? _viewModel;

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
    final viewModel = ClientsDirectoryViewModel(
      repository: ClientsDirectoryRepository(
        client: supabase.Supabase.instance.client,
        advisorId: widget.session.advisorId,
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

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Ficha del cliente'),
      ),
      body: viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: ClientsDirectoryContent(
                session: widget.session,
                viewModel: viewModel,
              ),
            ),
    );
  }
}
