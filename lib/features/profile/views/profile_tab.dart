import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/user_role.dart';
import '../models/advisor_profile_details.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.session,
    required this.viewModel,
    required this.onLogout,
    required this.onProfileUpdated,
    required this.onRefresh,
  });

  final AuthSession session;
  final ProfileViewModel viewModel;
  final Future<void> Function() onLogout;
  final VoidCallback onProfileUpdated;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = viewModel.profile;
    final syncStats = viewModel.syncStats;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Mi perfil',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (viewModel.successMessage != null)
            _MessageBanner(
              message: viewModel.successMessage!,
              color: const Color(0xFF27C46B),
            ),
          if (viewModel.errorMessage != null)
            _MessageBanner(
              message: viewModel.errorMessage!,
              color: const Color(0xFFFF4D4D),
            ),
          if (profile != null) ...[
            _ProfileHeader(profile: profile, session: session),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Sincronizacion',
              children: [
                _InfoRow(
                  label: 'Ultima actualizacion cartera',
                  value: _formatSync(syncStats?.lastPortfolioSyncAt),
                ),
                _InfoRow(
                  label: 'Pendientes de envio',
                  value: '${syncStats?.totalPending ?? 0}',
                ),
                _InfoRow(
                  label: 'En servidor',
                  value: '${syncStats?.pendingRemoteSync ?? 0}',
                ),
                _InfoRow(
                  label: 'Borradores locales',
                  value: '${syncStats?.pendingLocalDrafts ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'Editar mis datos',
              onTap: () => _openEditProfileSheet(context, profile),
            ),
            _ActionTile(
              icon: Icons.lock_reset_outlined,
              label: 'Cambiar contraseña',
              onTap: () => _openChangePasswordSheet(context),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerHighest,
                foregroundColor: AppColors.onSurface,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSync(DateTime? value) {
    if (value == null) {
      return 'Sin sincronizar';
    }
    final now = DateTime.now();
    final sameDay =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return sameDay ? 'Hoy $hour:$minute' : '${value.day}/${value.month} $hour:$minute';
  }

  Future<void> _openEditProfileSheet(
    BuildContext context,
    AdvisorProfileDetails profile,
  ) async {
    viewModel.clearMessages();
    final firstNameController = TextEditingController(text: profile.firstName);
    final lastNameController = TextEditingController(text: profile.lastName);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Editar mis datos',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Nombres'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
              const SizedBox(height: 8),
              Text(
                'Codigo ${profile.employeeCode} · ${profile.agencyName.isEmpty ? 'Agencia asignada' : profile.agencyName}',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: viewModel.isSavingProfile
                    ? null
                    : () async {
                        final ok = await viewModel.saveProfile(
                          firstName: firstNameController.text,
                          lastName: lastNameController.text,
                        );
                        if (context.mounted && ok) {
                          onProfileUpdated();
                          Navigator.of(context).pop(true);
                        }
                      },
                child: viewModel.isSavingProfile
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        );
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    if (saved == true) {
      viewModel.clearMessages();
    }
  }

  Future<void> _openChangePasswordSheet(BuildContext context) async {
    viewModel.clearMessages();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    var obscureNew = true;
    var obscureConfirm = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Minimo 8 caracteres. Debe ser distinta a la anterior.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setSheetState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: viewModel.isChangingPassword
                        ? null
                        : () async {
                            final ok = await viewModel.changePassword(
                              newPassword: newPasswordController.text,
                              confirmPassword: confirmController.text,
                            );
                            if (context.mounted && ok) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: viewModel.isChangingPassword
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Actualizar contraseña'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    newPasswordController.dispose();
    confirmController.dispose();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.session});

  final AdvisorProfileDetails profile;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final role = UserRole.fromCode(profile.role);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceContainerHighest,
            child: Text(
              profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.employeeCode} · ${role.label}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.agencyName.isEmpty
                      ? 'Agencia asignada'
                      : profile.agencyName,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (profile.internalEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.internalEmail,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
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
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: const TextStyle(color: AppColors.onSurface)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
