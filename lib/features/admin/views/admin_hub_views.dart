import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class TaskReassignmentView extends StatelessWidget {
  const TaskReassignmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Reasignacion de tareas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Reasigne clientes entre asesores de la agencia. '
            'Los cambios se reflejan en cartera_diaria del dia.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          SizedBox(height: 16),
          _AdminCard(
            title: 'Carlos Rojas → Operador 105002',
            subtitle: 'Recuperacion mora · 3 clientes pendientes',
            action: 'Reasignar',
          ),
          _AdminCard(
            title: 'Maria Quispe → Operador 105001',
            subtitle: 'Renovacion · 2 clientes pendientes',
            action: 'Reasignar',
          ),
        ],
      ),
    );
  }
}

class UserManagementView extends StatelessWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Gestion de usuarios'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AdminCard(
            title: '105001 · Operador',
            subtitle: 'Activo · Agencia Lima Centro',
            action: 'Editar',
          ),
          _AdminCard(
            title: '301001 · Supervisor',
            subtitle: 'Activo · Agencia Lima Centro',
            action: 'Editar',
          ),
        ],
      ),
    );
  }
}

class FormsConfigurationView extends StatelessWidget {
  const FormsConfigurationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Formularios'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AdminCard(
            title: 'Solicitud microcredito comercio',
            subtitle: 'Version 3 · 42 campos activos',
            action: 'Configurar',
          ),
          _AdminCard(
            title: 'Registro de desercion',
            subtitle: 'Version 1 · 6 campos activos',
            action: 'Configurar',
          ),
        ],
      ),
    );
  }
}

class AppSettingsView extends StatelessWidget {
  const AppSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Configuracion'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AdminCard(
            title: 'Sync nocturna 22:00',
            subtitle: 'Activa · Reintentos 22:30 y 23:00',
            action: 'Ajustar',
          ),
          _AdminCard(
            title: 'Umbral nitidez documentos',
            subtitle: 'Valor actual: 35',
            action: 'Ajustar',
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ),
        trailing: OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$action registrado (demo).')),
            );
          },
          child: Text(action),
        ),
      ),
    );
  }
}
