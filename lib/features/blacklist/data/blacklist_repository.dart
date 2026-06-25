import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/blacklist_entry.dart';

class BlacklistRepository {
  BlacklistRepository({
    required supabase.SupabaseClient client,
    required SharedPreferences preferences,
  }) : _client = client,
       _preferences = preferences;

  final supabase.SupabaseClient _client;
  final SharedPreferences _preferences;

  static const _cacheKey = 'lista_negra_cache_v1';
  static const _cacheAtKey = 'lista_negra_cache_at_v1';
  static const _cacheTtl = Duration(hours: 12);

  Future<BlacklistEntry?> findActiveEntry(String documentNumber) async {
    final normalized = documentNumber.trim();
    if (normalized.length != 8) {
      return null;
    }

    final cached = _readCache();
    if (cached != null) {
      return cached[normalized];
    }

    try {
      final row = await _client
          .from('lista_negra')
          .select('numero_documento, motivo, fuente')
          .eq('numero_documento', normalized)
          .eq('activo', true)
          .maybeSingle();

      if (row != null) {
        return BlacklistEntry.fromJson(row);
      }

      await _refreshCache();
      return _readCache()?[normalized];
    } catch (_) {
      return _readCache()?[normalized];
    }
  }

  Future<void> warmCache() async {
    try {
      await _refreshCache();
    } catch (_) {}
  }

  Future<void> _refreshCache() async {
    final rows = await _client
        .from('lista_negra')
        .select('numero_documento, motivo, fuente')
        .eq('activo', true);

    final cache = <String, BlacklistEntry>{};
    for (final row in rows as List) {
      final entry = BlacklistEntry.fromJson(row as Map<String, dynamic>);
      cache[entry.documentNumber] = entry;
    }

    await _preferences.setString(
      _cacheKey,
      cache.entries
          .map(
            (entry) =>
                '${entry.key}|${entry.value.reason}|${entry.value.source}',
          )
          .join('\n'),
    );
    await _preferences.setString(_cacheAtKey, DateTime.now().toIso8601String());
  }

  Map<String, BlacklistEntry>? _readCache() {
    final cachedAt = DateTime.tryParse(
      _preferences.getString(_cacheAtKey) ?? '',
    );
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt) > _cacheTtl) {
      return null;
    }

    final raw = _preferences.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final cache = <String, BlacklistEntry>{};
    for (final line in raw.split('\n')) {
      final parts = line.split('|');
      if (parts.length < 2) {
        continue;
      }
      cache[parts[0]] = BlacklistEntry(
        documentNumber: parts[0],
        reason: parts[1],
        source: parts.length > 2 ? parts[2] : 'interna',
      );
    }
    return cache;
  }
}
