import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/credit_request/models/credit_request_models.dart';

class LocalAppDatabase {
  LocalAppDatabase._();

  static Database? _database;

  static Future<Database> instance() async {
    if (_database != null) {
      return _database!;
    }
    final basePath = await getDatabasesPath();
    _database = await openDatabase(
      join(basePath, 'app_fuerza_ventas.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          create table solicitudes_borrador (
            local_id text primary key,
            advisor_id text not null,
            payload_json text not null,
            step_reached integer not null,
            updated_at text not null
          )
        ''');
        await db.execute('''
          create table visitas_pendientes (
            id integer primary key autoincrement,
            portfolio_entry_id text not null,
            payload_json text not null,
            created_at text not null
          )
        ''');
        await db.execute('''
          create table transmision_estado (
            solicitud_id text primary key,
            step_index integer not null,
            updated_at text not null
          )
        ''');
      },
    );
    return _database!;
  }

  static Future<void> saveDraft(CreditRequestDraft draft) async {
    final db = await instance();
    await db.insert(
      'solicitudes_borrador',
      {
        'local_id': draft.localId,
        'advisor_id': draft.advisorId,
        'payload_json': jsonEncode(draft.toJson()),
        'step_reached': draft.currentStep,
        'updated_at': draft.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CreditRequestDraft>> loadDrafts(String advisorId) async {
    final db = await instance();
    final rows = await db.query(
      'solicitudes_borrador',
      where: 'advisor_id = ?',
      whereArgs: [advisorId],
      orderBy: 'updated_at desc',
    );
    return rows
        .map(
          (row) => CreditRequestDraft.fromJson(
            jsonDecode(row['payload_json']!.toString()) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> deleteDraft(String localId) async {
    final db = await instance();
    await db.delete(
      'solicitudes_borrador',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  static Future<void> saveTransmissionStep(
    String solicitudId,
    int stepIndex,
  ) async {
    final db = await instance();
    await db.insert(
      'transmision_estado',
      {
        'solicitud_id': solicitudId,
        'step_index': stepIndex,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> loadTransmissionStep(String solicitudId) async {
    final db = await instance();
    final rows = await db.query(
      'transmision_estado',
      where: 'solicitud_id = ?',
      whereArgs: [solicitudId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first['step_index'] as int? ?? 0;
  }

  static Future<void> clearTransmissionState(String solicitudId) async {
    final db = await instance();
    await db.delete(
      'transmision_estado',
      where: 'solicitud_id = ?',
      whereArgs: [solicitudId],
    );
  }
}
