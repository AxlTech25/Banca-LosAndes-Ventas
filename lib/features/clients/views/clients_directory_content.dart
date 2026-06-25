import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../../client_profile/views/client_profile_view.dart';
import '../../portfolio/models/daily_client.dart';
import '../models/client_directory_entry.dart';
import '../viewmodels/clients_directory_view_model.dart';

class ClientsDirectoryContent extends StatelessWidget {
  const ClientsDirectoryContent({
    super.key,
    required this.session,
    required this.viewModel,
    this.showHeader = true,
  });

  final AuthSession session;
  final ClientsDirectoryViewModel viewModel;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fichas de clientes',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${viewModel.filteredClients.length} clientes en cartera, solicitudes y mora',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: viewModel.updateSearch,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, negocio o DNI',
                    hintStyle:
                        const TextStyle(color: AppColors.onSurfaceVariant),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: viewModel.updateSearch,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, negocio o DNI',
                hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
          ),
        if (viewModel.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              viewModel.errorMessage!,
              style: const TextStyle(color: Color(0xFFFF4D4D)),
            ),
          ),
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : viewModel.filteredClients.isEmpty
              ? const Center(
                  child: Text(
                    'No hay clientes para mostrar.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: viewModel.filteredClients.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final client = viewModel.filteredClients[index];
                    return _ClientDirectoryCard(
                      client: client,
                      onTap: () => _openProfile(context, client),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _openProfile(BuildContext context, ClientDirectoryEntry client) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientProfileView(
          session: session,
          dailyClient: DailyClient(
            id: 'directory-${client.clientId}',
            clientId: client.clientId,
            advisorId: session.advisorId,
            clientName: client.fullName,
            documentNumber: client.documentNumber,
            managementType: ManagementType.followUp,
            creditAmount: 0,
            priorityScore: 0,
            visitStatus: VisitStatus.pending,
            assignmentDate: DateTime.now(),
          ),
        ),
      ),
    );
  }
}

class _ClientDirectoryCard extends StatelessWidget {
  const _ClientDirectoryCard({required this.client, required this.onTap});

  final ClientDirectoryEntry client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceContainerHighest,
                child: Text(
                  client.fullName.isNotEmpty
                      ? client.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${client.maskedDocument} · ${client.businessName.isEmpty ? 'Sin negocio' : client.businessName}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: client.sources
                          .map(
                            (source) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                source.label,
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
