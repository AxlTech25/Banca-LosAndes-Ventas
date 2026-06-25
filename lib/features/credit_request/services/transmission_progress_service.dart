import '../../../core/database/local_app_database.dart';
import '../models/pipeline_models.dart';
import '../services/transmission_checklist.dart';
import 'document_storage_service.dart';

enum TransmissionStep {
  validating('Validando datos'),
  uploadingDocuments('Subiendo documentos'),
  registering('Registrando en sistema central'),
  assigning('Asignando expediente'),
  completed('Solicitud enviada');

  const TransmissionStep(this.label);

  final String label;
}

class TransmissionProgressService {
  TransmissionProgressService({
    required DocumentStorageService storageService,
  }) : _storageService = storageService;

  final DocumentStorageService _storageService;

  Future<TransmissionResult> transmitWithProgress({
    required CreditRequestDetail detail,
    required Future<TransmissionResult> Function() transmitCore,
    void Function(TransmissionStep step, int current, int total)? onProgress,
  }) async {
    final solicitudId = detail.request.id;
    var stepIndex = await LocalAppDatabase.loadTransmissionStep(solicitudId);

    if (stepIndex <= 0) {
      final checklist = TransmissionChecklist.evaluate(detail);
      if (!checklist.isReady) {
        return TransmissionResult(
          errorMessage: 'Checklist incompleto antes de transmitir.',
        );
      }
      stepIndex = 1;
      await LocalAppDatabase.saveTransmissionStep(solicitudId, stepIndex);
      onProgress?.call(TransmissionStep.validating, 1, 5);
    }

    if (stepIndex <= 1) {
      final docs = detail.documents.where((doc) {
        if (doc.storageUrl.startsWith('http')) {
          return false;
        }
        return !doc.isDataUri;
      }).toList();
      var uploaded = 0;
      for (final doc in docs) {
        await _storageService.uploadDocument(
          solicitudId: solicitudId,
          typeCode: doc.typeCode,
          localPath: doc.storageUrl,
        );
        uploaded++;
        onProgress?.call(
          TransmissionStep.uploadingDocuments,
          uploaded,
          docs.isEmpty ? 1 : docs.length,
        );
      }
      stepIndex = 2;
      await LocalAppDatabase.saveTransmissionStep(solicitudId, stepIndex);
    }

    onProgress?.call(TransmissionStep.registering, 3, 5);
    final result = await transmitCore();
    if (!result.success) {
      return result;
    }

    stepIndex = 4;
    await LocalAppDatabase.saveTransmissionStep(solicitudId, stepIndex);
    onProgress?.call(TransmissionStep.assigning, 4, 5);

    await LocalAppDatabase.clearTransmissionState(solicitudId);
    onProgress?.call(TransmissionStep.completed, 5, 5);
    return result;
  }
}
