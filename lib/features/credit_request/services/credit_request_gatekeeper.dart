import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../auth/models/auth_session.dart';
import '../../blacklist/data/blacklist_repository.dart';
import '../../blacklist/views/blacklist_block_dialog.dart';
import '../models/credit_request_models.dart';
import '../views/credit_request_wizard_view.dart';

class CreditRequestGatekeeper {
  CreditRequestGatekeeper._();

  static Future<bool?> openFromLaunch(
    BuildContext context, {
    required AuthSession session,
    required CreditRequestLaunchData launch,
  }) async {
    final documentNumber = launch.documentNumber.trim();
    if (documentNumber.length == 8) {
      final allowed = await verifyDocumentForLaunch(context, documentNumber);
      if (!allowed) {
        return null;
      }
    }

    if (!context.mounted) {
      return null;
    }

    return CreditRequestWizardView.openFromLaunch(
      context,
      session: session,
      launch: launch,
    );
  }

  static Future<bool> checkDocumentAndBlock(
    BuildContext context,
    String documentNumber,
  ) async {
    final normalized = documentNumber.trim();
    if (normalized.length != 8) {
      return false;
    }
    return _showBlockIfListed(context, normalized);
  }

  static Future<bool> verifyDocumentForLaunch(
    BuildContext context,
    String documentNumber,
  ) async {
    final blocked = await checkDocumentAndBlock(context, documentNumber);
    if (blocked || !context.mounted) {
      return false;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Color(0xFF27C46B)),
        title: const Text('Verificacion OK'),
        content: Text(
          'DNI $documentNumber no figura en listas negras. '
          'Puede continuar con la solicitud.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return true;
  }

  static Future<bool> _showBlockIfListed(
    BuildContext context,
    String documentNumber,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final repository = BlacklistRepository(
      client: supabase.Supabase.instance.client,
      preferences: preferences,
    );
    final entry = await repository.findActiveEntry(documentNumber);
    if (entry == null) {
      return false;
    }
    if (!context.mounted) {
      return true;
    }
    await BlacklistBlockDialog.show(context, entry);
    return true;
  }
}
