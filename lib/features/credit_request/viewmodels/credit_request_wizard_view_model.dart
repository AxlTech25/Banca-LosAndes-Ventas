import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../data/credit_request_repository.dart';
import '../models/credit_request_models.dart';
import '../services/document_capture_service.dart';

class CreditRequestWizardViewModel extends ChangeNotifier {
  CreditRequestWizardViewModel({
    required CreditRequestRepository repository,
    required CreditRequestDraft draft,
  }) : _repository = repository,
       _draft = draft;

  final CreditRequestRepository _repository;
  CreditRequestDraft _draft;

  bool isSaving = false;
  bool isSubmitting = false;
  String? errorMessage;
  String? successMessage;

  CreditRequestDraft get draft => _draft;
  int get currentStep => _draft.currentStep;

  static const businessTypes = [
    'Comercio',
    'Servicios',
    'Produccion',
    'Agropecuario',
  ];

  static const guaranteeTypes = ['Personal', 'Prendaria', 'Hipotecaria'];

  Future<void> saveDraft() async {
    isSaving = true;
    notifyListeners();
    await _repository.saveDraft(_draft);
    isSaving = false;
    notifyListeners();
  }

  void updateBusiness({
    String? documentNumber,
    String? clientFirstName,
    String? clientLastName,
    String? businessType,
    String? businessName,
    int? businessAgeMonths,
    double? estimatedIncome,
    double? monthlyExpenses,
    double? estimatedAssets,
    bool? hasSpouse,
    String? spouseName,
    bool? hasGuarantor,
    String? guarantorName,
  }) {
    _draft = _draft.copyWith(
      documentNumber: documentNumber,
      clientFirstName: clientFirstName,
      clientLastName: clientLastName,
      businessType: businessType,
      businessName: businessName,
      businessAgeMonths: businessAgeMonths,
      estimatedIncome: estimatedIncome,
      monthlyExpenses: monthlyExpenses,
      estimatedAssets: estimatedAssets,
      hasSpouse: hasSpouse,
      spouseName: spouseName,
      hasGuarantor: hasGuarantor,
      guarantorName: guarantorName,
    );
    notifyListeners();
  }

  void updateCredit({
    double? requestedAmount,
    int? termMonths,
    String? creditPurpose,
    String? guaranteeType,
    double? referenceTea,
  }) {
    _draft = _draft.copyWith(
      requestedAmount: requestedAmount,
      termMonths: termMonths,
      creditPurpose: creditPurpose,
      guaranteeType: guaranteeType,
      referenceTea: referenceTea,
    );
    notifyListeners();
  }

  Future<bool> nextStep() async {
    errorMessage = null;
    final validation = switch (_draft.currentStep) {
      0 when !_draft.canAdvanceFromBusiness =>
        'Completa los datos del negocio y cliente.',
      1 when !_draft.canAdvanceFromCredit =>
        'Revisa monto, plazo y destino del credito.',
      2 when !_draft.hasRequiredDocuments =>
        'Adjunta DNI anverso y fachada del negocio con buena nitidez.',
      _ => null,
    };

    if (validation != null) {
      errorMessage = validation;
      notifyListeners();
      return false;
    }

    if (_draft.currentStep >= 3) {
      return true;
    }

    _draft = _draft.copyWith(currentStep: _draft.currentStep + 1);
    await saveDraft();
    return true;
  }

  Future<void> previousStep() async {
    if (_draft.currentStep == 0) {
      return;
    }
    _draft = _draft.copyWith(currentStep: _draft.currentStep - 1);
    await saveDraft();
  }

  Future<bool> attachDocument(CreditDocumentType type) async {
    errorMessage = null;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null) {
      return false;
    }

    final processed = await DocumentCaptureService.processCameraFile(image.path);
    if (processed == null) {
      errorMessage = 'No se pudo procesar la imagen capturada.';
      notifyListeners();
      return false;
    }

    if (!processed.isSharpEnough) {
      errorMessage =
          'Imagen borrosa (nitidez ${processed.sharpnessScore.toStringAsFixed(0)}). '
          'Sostenga el telefono firme y vuelva a capturar.';
      notifyListeners();
      return false;
    }

    final documents = List<CreditDocumentAttachment>.from(_draft.documents)
      ..removeWhere((doc) => doc.type == type)
      ..add(
        CreditDocumentAttachment(
          type: type,
          localPath: processed.outputPath,
          sizeKb: processed.sizeKb,
          sharpnessScore: processed.sharpnessScore,
          isSharpEnough: processed.isSharpEnough,
        ),
      );

    _draft = _draft.copyWith(documents: documents);
    await saveDraft();
    return true;
  }

  void removeDocument(CreditDocumentType type) {
    final documents = List<CreditDocumentAttachment>.from(_draft.documents)
      ..removeWhere((doc) => doc.type == type);
    _draft = _draft.copyWith(documents: documents);
    notifyListeners();
  }

  CreditDocumentAttachment? documentFor(CreditDocumentType type) {
    for (final document in _draft.documents) {
      if (document.type == type) {
        return document;
      }
    }
    return null;
  }

  void setSignature(String? base64Signature) {
    _draft = _draft.copyWith(signatureBase64: base64Signature);
    notifyListeners();
  }

  Future<void> captureLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    _draft = _draft.copyWith(
      captureLatitude: position.latitude,
      captureLongitude: position.longitude,
    );
    notifyListeners();
  }

  Future<CreditRequestSubmitResult?> submit() async {
    errorMessage = null;
    successMessage = null;

    if (!_draft.canSubmit) {
      errorMessage = 'Firma, documentos y datos obligatorios pendientes.';
      notifyListeners();
      return null;
    }

    if (_draft.captureLatitude == null || _draft.captureLongitude == null) {
      await captureLocation();
    }

    isSubmitting = true;
    notifyListeners();

    try {
      final result = await _repository.submit(_draft);
      if (result.isSuccess) {
        successMessage = result.offline
            ? 'Solicitud guardada sin conexion. Se sincronizara al reconectar.'
            : 'Solicitud enviada correctamente.';
      } else {
        errorMessage = result.errorMessage ?? 'No se pudo enviar la solicitud.';
      }
      return result;
    } catch (error) {
      errorMessage = error.toString();
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
