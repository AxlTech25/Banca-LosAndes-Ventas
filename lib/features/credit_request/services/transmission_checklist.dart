import '../models/credit_request_models.dart';
import '../models/pipeline_models.dart';
import 'document_capture_service.dart';

class TransmissionCheckItem {
  const TransmissionCheckItem({
    required this.label,
    required this.isComplete,
    this.detail,
  });

  final String label;
  final bool isComplete;
  final String? detail;
}

class TransmissionChecklistResult {
  const TransmissionChecklistResult({
    required this.items,
  });

  final List<TransmissionCheckItem> items;

  bool get isReady => items.every((item) => item.isComplete);

  List<TransmissionCheckItem> get pendingItems =>
      items.where((item) => !item.isComplete).toList();
}

class TransmissionChecklist {
  TransmissionChecklist._();

  static const requiredDocumentTypes = [
    CreditDocumentType.dniFront,
    CreditDocumentType.dniBack,
    CreditDocumentType.businessFacade,
    CreditDocumentType.clientWithAdvisor,
  ];

  static TransmissionChecklistResult evaluate(CreditRequestDetail detail) {
    final documents = detail.documents;
    final bureau = detail.bureauConsult;
    final items = <TransmissionCheckItem>[];

    for (final type in requiredDocumentTypes) {
      final stored = documents.where((doc) => doc.typeCode == type.code);
      if (stored.isEmpty) {
        items.add(
          TransmissionCheckItem(
            label: type.label,
            isComplete: false,
            detail: 'Documento obligatorio pendiente.',
          ),
        );
        continue;
      }

      final document = stored.first;
      final sharpness = document.sharpnessScore;
      final sharpEnough = sharpness == null ||
          sharpness >= DocumentCaptureService.minSharpnessScore;
      items.add(
        TransmissionCheckItem(
          label: type.label,
          isComplete: sharpEnough,
          detail: sharpEnough
              ? '${document.sizeKb} KB · nitidez ${sharpness?.toStringAsFixed(0) ?? 'N/D'}'
              : 'Imagen borrosa (nitidez ${sharpness.toStringAsFixed(0)}). '
                  'Vuelva a capturar.',
        ),
      );
    }

    items.add(
      TransmissionCheckItem(
        label: 'Consulta buró registrada',
        isComplete: bureau != null,
        detail: bureau == null
            ? 'Firme consentimiento y consulte buró.'
            : 'Calificacion ${bureau.rating.label}',
      ),
    );

    items.add(
      TransmissionCheckItem(
        label: 'Calificacion SBS apta',
        isComplete: bureau != null && !bureau.blocksTransmission,
        detail: bureau == null
            ? null
            : bureau.blocksTransmission
            ? 'Calificacion restrictiva (${bureau.rating.label}).'
            : 'Sin restricciones para transmitir.',
      ),
    );

    return TransmissionChecklistResult(items: items);
  }
}
