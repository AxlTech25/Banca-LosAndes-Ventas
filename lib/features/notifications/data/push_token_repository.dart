import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class PushTokenRepository {
  PushTokenRepository({required supabase.SupabaseClient client})
      : _client = client;

  final supabase.SupabaseClient _client;

  Future<void> registerDeviceToken({
    required String advisorId,
    String? token,
  }) async {
    final resolved = token ?? 'local-notifications-${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('asesores_negocio').update({
      'token_fcm': resolved,
    }).eq('id', advisorId);
  }
}
