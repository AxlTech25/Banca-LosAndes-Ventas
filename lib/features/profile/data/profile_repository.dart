import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/advisor_profile_details.dart';

class ProfileRepository {
  ProfileRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
  }) : _client = client,
       _advisorId = advisorId;

  final supabase.SupabaseClient _client;
  final String _advisorId;

  Future<AdvisorProfileDetails> fetchProfile() async {
    final row = await _client
        .from('asesores_negocio')
        .select(
          'id, codigo_empleado, nombres, apellidos, perfil, agencias ( nombre )',
        )
        .eq('id', _advisorId)
        .single();

    final agency = row['agencias'];
    final agencyName = agency is Map
        ? (agency['nombre'] ?? '').toString()
        : '';

    final userEmail = _client.auth.currentUser?.email ?? '';

    return AdvisorProfileDetails(
      id: row['id'].toString(),
      employeeCode: (row['codigo_empleado'] ?? '').toString(),
      firstName: (row['nombres'] ?? '').toString(),
      lastName: (row['apellidos'] ?? '').toString(),
      role: (row['perfil'] ?? '').toString(),
      agencyName: agencyName,
      internalEmail: userEmail,
    );
  }

  Future<AdvisorProfileDetails> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    await _client
        .from('asesores_negocio')
        .update({
          'nombres': firstName.trim(),
          'apellidos': lastName.trim(),
        })
        .eq('id', _advisorId);

    return fetchProfile();
  }
}
