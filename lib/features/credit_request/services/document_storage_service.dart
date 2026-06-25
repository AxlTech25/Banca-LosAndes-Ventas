import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class DocumentStorageService {
  DocumentStorageService({required supabase.SupabaseClient client})
      : _client = client;

  final supabase.SupabaseClient _client;
  static const _bucket = 'documentos-solicitudes';

  Future<String?> uploadDocument({
    required String solicitudId,
    required String typeCode,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final storagePath = '$solicitudId/$typeCode.jpg';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const supabase.FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _client.storage.from(_bucket).getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }
}
