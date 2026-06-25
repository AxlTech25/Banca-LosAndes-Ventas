enum UserRole {
  operator('Operador'),
  superOperator('Super Operador'),
  supervisor('Supervisor'),
  administrator('Administrador');

  const UserRole(this.label);

  final String label;

  /// Solo super operador puede aprobar solicitudes app_cliente.
  bool get canApproveClientAppRequests => this == UserRole.superOperator;

  static UserRole fromCode(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    return switch (normalized) {
      'administrator' ||
      'administrador' ||
      'admin' => UserRole.administrator,
      'supervisor' => UserRole.supervisor,
      'superoperator' ||
      'superoperador' ||
      'super_operador' => UserRole.superOperator,
      'operator' || 'operador' || 'asesor' => UserRole.operator,
      _ => UserRole.operator,
    };
  }
}
