import 'dart:math';

import '../../client_profile/models/client_profile.dart';
import '../../portfolio/models/daily_client.dart';
import '../../prospection/models/pre_evaluation_models.dart';

enum CreditRequestStatus {
  draft('borrador', 'Borrador'),
  submitted('enviada', 'Enviada'),
  pendingSync('pendiente_sync', 'Pendiente sync');

  const CreditRequestStatus(this.code, this.label);

  final String code;
  final String label;

  static CreditRequestStatus fromCode(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return CreditRequestStatus.values.firstWhere(
      (status) => status.code == normalized,
      orElse: () => CreditRequestStatus.draft,
    );
  }
}

enum CreditDocumentType {
  dniFront('DNI_ANVERSO', 'DNI anverso'),
  dniBack('DNI_REVERSO', 'DNI reverso'),
  businessFacade('FACHADA_NEGOCIO', 'Fachada del negocio'),
  clientWithAdvisor('FOTO_CLIENTE_ASESOR', 'Foto cliente y asesor'),
  utilityBill('RECIBO_SERVICIO', 'Recibo de servicio');

  const CreditDocumentType(this.code, this.label);

  final String code;
  final String label;

  static CreditDocumentType fromCode(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    return CreditDocumentType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => CreditDocumentType.dniFront,
    );
  }
}

class CreditDocumentAttachment {
  const CreditDocumentAttachment({
    required this.type,
    required this.localPath,
    this.sizeKb = 0,
    this.sharpnessScore = 0,
    this.isSharpEnough = true,
  });

  final CreditDocumentType type;
  final String localPath;
  final int sizeKb;
  final double sharpnessScore;
  final bool isSharpEnough;

  Map<String, dynamic> toJson() {
    return {
      'type': type.code,
      'localPath': localPath,
      'sizeKb': sizeKb,
      'sharpnessScore': sharpnessScore,
      'isSharpEnough': isSharpEnough,
    };
  }

  factory CreditDocumentAttachment.fromJson(Map<String, dynamic> json) {
    return CreditDocumentAttachment(
      type: CreditDocumentType.fromCode(json['type']?.toString()),
      localPath: json['localPath'].toString(),
      sizeKb: _intValue(json['sizeKb']) ?? 0,
      sharpnessScore: _doubleValue(json['sharpnessScore']),
      isSharpEnough: json['isSharpEnough'] != false,
    );
  }
}

class CreditRequestLaunchData {
  const CreditRequestLaunchData({
    this.clientId,
    required this.documentNumber,
    required this.clientFirstName,
    required this.clientLastName,
    this.businessType = 'Comercio',
    this.businessName = '',
    this.businessAgeMonths = 12,
    this.estimatedIncome = 2000,
    this.monthlyExpenses = 800,
    this.estimatedAssets = 5000,
    this.requestedAmount = 5000,
    this.termMonths = 12,
    this.creditPurpose = '',
    this.referenceTea = 68.5,
    this.source = 'manual',
  });

  final String? clientId;
  final String documentNumber;
  final String clientFirstName;
  final String clientLastName;
  final String businessType;
  final String businessName;
  final int businessAgeMonths;
  final double estimatedIncome;
  final double monthlyExpenses;
  final double estimatedAssets;
  final double requestedAmount;
  final int termMonths;
  final String creditPurpose;
  final double referenceTea;
  final String source;

  factory CreditRequestLaunchData.fromProspect(ProspectFormData form) {
    return CreditRequestLaunchData(
      documentNumber: form.documentNumber,
      clientFirstName: form.firstName,
      clientLastName: form.lastName,
      businessType: form.businessType,
      businessAgeMonths: form.businessAgeTotalMonths,
      estimatedIncome: form.estimatedIncome,
      requestedAmount: form.requestedAmount,
      termMonths: 12,
      creditPurpose: form.creditPurpose,
      source: 'pre_eval',
    );
  }

  factory CreditRequestLaunchData.fromPreapproved({
    required ClientProfile profile,
    required PreapprovedOffer offer,
  }) {
    return CreditRequestLaunchData(
      clientId: profile.clientId,
      documentNumber: profile.documentNumber,
      clientFirstName: profile.fullName.split(' ').first,
      clientLastName: profile.fullName.split(' ').skip(1).join(' '),
      businessType: profile.businessType,
      businessName: profile.businessName,
      businessAgeMonths: profile.businessAgeMonths,
      requestedAmount: offer.maxAmount,
      termMonths: offer.suggestedTermMonths,
      referenceTea: offer.referenceTea,
      creditPurpose: 'Renovacion / ampliacion con oferta preaprobada',
      source: 'preapproved',
    );
  }

  factory CreditRequestLaunchData.fromCampaign({
    required ActiveCampaign campaign,
    DailyClient? client,
  }) {
    return CreditRequestLaunchData(
      clientId: campaign.clientId,
      documentNumber: client?.documentNumber ?? '',
      clientFirstName: campaign.clientName.split(' ').first,
      clientLastName: campaign.clientName.split(' ').skip(1).join(' '),
      requestedAmount: campaign.offeredAmount,
      termMonths: 12,
      creditPurpose: 'Campana ${campaign.type.label}',
      source: 'campaign',
    );
  }

  CreditRequestDraft toDraft({
    required String localId,
    required String advisorId,
    required String agencyId,
  }) {
    return CreditRequestDraft(
      localId: localId,
      advisorId: advisorId,
      agencyId: agencyId,
      clientId: clientId,
      documentNumber: documentNumber,
      clientFirstName: clientFirstName,
      clientLastName: clientLastName,
      businessType: businessType,
      businessName: businessName.isEmpty
          ? '$clientFirstName $clientLastName'.trim()
          : businessName,
      businessAgeMonths: businessAgeMonths,
      estimatedIncome: estimatedIncome,
      monthlyExpenses: monthlyExpenses,
      estimatedAssets: estimatedAssets,
      requestedAmount: requestedAmount,
      termMonths: termMonths,
      creditPurpose: creditPurpose,
      referenceTea: referenceTea,
      source: source,
    );
  }
}

class CreditRequestDraft {
  CreditRequestDraft({
    required this.localId,
    required this.advisorId,
    required this.agencyId,
    this.remoteId,
    this.clientId,
    required this.documentNumber,
    required this.clientFirstName,
    required this.clientLastName,
    this.businessType = 'Comercio',
    this.businessName = '',
    this.businessAgeMonths = 12,
    this.estimatedIncome = 2000,
    this.monthlyExpenses = 800,
    this.estimatedAssets = 5000,
    this.hasSpouse = false,
    this.spouseName = '',
    this.hasGuarantor = false,
    this.guarantorName = '',
    this.requestedAmount = 5000,
    this.termMonths = 12,
    this.creditPurpose = '',
    this.guaranteeType = 'Personal',
    this.referenceTea = 68.5,
    this.currentStep = 0,
    this.status = CreditRequestStatus.draft,
    this.pendienteSync = false,
    this.signatureBase64,
    this.captureLatitude,
    this.captureLongitude,
    this.numeroExpediente,
    this.source = 'manual',
    List<CreditDocumentAttachment>? documents,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : documents = documents ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String localId;
  final String advisorId;
  final String agencyId;
  final String? remoteId;
  final String? clientId;
  final String documentNumber;
  final String clientFirstName;
  final String clientLastName;
  final String businessType;
  final String businessName;
  final int businessAgeMonths;
  final double estimatedIncome;
  final double monthlyExpenses;
  final double estimatedAssets;
  final bool hasSpouse;
  final String spouseName;
  final bool hasGuarantor;
  final String guarantorName;
  final double requestedAmount;
  final int termMonths;
  final String creditPurpose;
  final String guaranteeType;
  final double referenceTea;
  final int currentStep;
  final CreditRequestStatus status;
  final bool pendienteSync;
  final String? signatureBase64;
  final double? captureLatitude;
  final double? captureLongitude;
  final String? numeroExpediente;
  final String source;
  final List<CreditDocumentAttachment> documents;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get clientFullName => '$clientFirstName $clientLastName'.trim();

  double get estimatedInstallment =>
      estimateInstallment(requestedAmount, termMonths, referenceTea);

  bool get canAdvanceFromBusiness =>
      documentNumber.trim().length == 8 &&
      clientFirstName.trim().isNotEmpty &&
      clientLastName.trim().isNotEmpty &&
      businessName.trim().isNotEmpty &&
      businessAgeMonths >= 6 &&
      estimatedIncome > 0;

  bool get canAdvanceFromCredit =>
      requestedAmount >= 500 &&
      termMonths >= 3 &&
      termMonths <= 36 &&
      creditPurpose.trim().isNotEmpty;

  bool get hasRequiredDocuments =>
      _hasRequiredDocument(CreditDocumentType.dniFront) &&
      _hasRequiredDocument(CreditDocumentType.dniBack) &&
      _hasRequiredDocument(CreditDocumentType.businessFacade) &&
      _hasRequiredDocument(CreditDocumentType.clientWithAdvisor);

  bool _hasRequiredDocument(CreditDocumentType type) {
    return documents.any(
      (doc) => doc.type == type && doc.isSharpEnough,
    );
  }

  bool get canSubmit =>
      canAdvanceFromBusiness &&
      canAdvanceFromCredit &&
      hasRequiredDocuments &&
      signatureBase64 != null &&
      signatureBase64!.isNotEmpty;

  CreditRequestDraft copyWith({
    String? remoteId,
    String? clientId,
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
    double? requestedAmount,
    int? termMonths,
    String? creditPurpose,
    String? guaranteeType,
    double? referenceTea,
    int? currentStep,
    CreditRequestStatus? status,
    bool? pendienteSync,
    String? signatureBase64,
    double? captureLatitude,
    double? captureLongitude,
    String? numeroExpediente,
    List<CreditDocumentAttachment>? documents,
    DateTime? updatedAt,
  }) {
    return CreditRequestDraft(
      localId: localId,
      advisorId: advisorId,
      agencyId: agencyId,
      remoteId: remoteId ?? this.remoteId,
      clientId: clientId ?? this.clientId,
      documentNumber: documentNumber ?? this.documentNumber,
      clientFirstName: clientFirstName ?? this.clientFirstName,
      clientLastName: clientLastName ?? this.clientLastName,
      businessType: businessType ?? this.businessType,
      businessName: businessName ?? this.businessName,
      businessAgeMonths: businessAgeMonths ?? this.businessAgeMonths,
      estimatedIncome: estimatedIncome ?? this.estimatedIncome,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      estimatedAssets: estimatedAssets ?? this.estimatedAssets,
      hasSpouse: hasSpouse ?? this.hasSpouse,
      spouseName: spouseName ?? this.spouseName,
      hasGuarantor: hasGuarantor ?? this.hasGuarantor,
      guarantorName: guarantorName ?? this.guarantorName,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      termMonths: termMonths ?? this.termMonths,
      creditPurpose: creditPurpose ?? this.creditPurpose,
      guaranteeType: guaranteeType ?? this.guaranteeType,
      referenceTea: referenceTea ?? this.referenceTea,
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      pendienteSync: pendienteSync ?? this.pendienteSync,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      captureLatitude: captureLatitude ?? this.captureLatitude,
      captureLongitude: captureLongitude ?? this.captureLongitude,
      numeroExpediente: numeroExpediente ?? this.numeroExpediente,
      source: source,
      documents: documents ?? this.documents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'advisorId': advisorId,
      'agencyId': agencyId,
      'remoteId': remoteId,
      'clientId': clientId,
      'documentNumber': documentNumber,
      'clientFirstName': clientFirstName,
      'clientLastName': clientLastName,
      'businessType': businessType,
      'businessName': businessName,
      'businessAgeMonths': businessAgeMonths,
      'estimatedIncome': estimatedIncome,
      'monthlyExpenses': monthlyExpenses,
      'estimatedAssets': estimatedAssets,
      'hasSpouse': hasSpouse,
      'spouseName': spouseName,
      'hasGuarantor': hasGuarantor,
      'guarantorName': guarantorName,
      'requestedAmount': requestedAmount,
      'termMonths': termMonths,
      'creditPurpose': creditPurpose,
      'guaranteeType': guaranteeType,
      'referenceTea': referenceTea,
      'currentStep': currentStep,
      'status': status.code,
      'pendienteSync': pendienteSync,
      'signatureBase64': signatureBase64,
      'captureLatitude': captureLatitude,
      'captureLongitude': captureLongitude,
      'numeroExpediente': numeroExpediente,
      'source': source,
      'documents': documents.map((doc) => doc.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CreditRequestDraft.fromJson(Map<String, dynamic> json) {
    return CreditRequestDraft(
      localId: json['localId'].toString(),
      advisorId: json['advisorId'].toString(),
      agencyId: json['agencyId'].toString(),
      remoteId: json['remoteId']?.toString(),
      clientId: json['clientId']?.toString(),
      documentNumber: json['documentNumber'].toString(),
      clientFirstName: json['clientFirstName'].toString(),
      clientLastName: json['clientLastName'].toString(),
      businessType: json['businessType']?.toString() ?? 'Comercio',
      businessName: json['businessName']?.toString() ?? '',
      businessAgeMonths: _intValue(json['businessAgeMonths']) ?? 12,
      estimatedIncome: _doubleValue(json['estimatedIncome']),
      monthlyExpenses: _doubleValue(json['monthlyExpenses']),
      estimatedAssets: _doubleValue(json['estimatedAssets']),
      hasSpouse: json['hasSpouse'] == true,
      spouseName: json['spouseName']?.toString() ?? '',
      hasGuarantor: json['hasGuarantor'] == true,
      guarantorName: json['guarantorName']?.toString() ?? '',
      requestedAmount: _doubleValue(json['requestedAmount']),
      termMonths: _intValue(json['termMonths']) ?? 12,
      creditPurpose: json['creditPurpose']?.toString() ?? '',
      guaranteeType: json['guaranteeType']?.toString() ?? 'Personal',
      referenceTea: _doubleValue(json['referenceTea']),
      currentStep: _intValue(json['currentStep']) ?? 0,
      status: CreditRequestStatus.fromCode(json['status']?.toString()),
      pendienteSync: json['pendienteSync'] == true,
      signatureBase64: json['signatureBase64']?.toString(),
      captureLatitude: _doubleOrNull(json['captureLatitude']),
      captureLongitude: _doubleOrNull(json['captureLongitude']),
      numeroExpediente: json['numeroExpediente']?.toString(),
      source: json['source']?.toString() ?? 'manual',
      documents: (json['documents'] as List<dynamic>? ?? [])
          .map((item) => CreditDocumentAttachment.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabasePayload({required String clientId}) {
    return {
      if (remoteId != null) 'id': remoteId,
      'numero_expediente':
          numeroExpediente ?? _generateExpedienteNumber(),
      'asesor_id': advisorId,
      'cliente_id': clientId,
      'agencia_id': agencyId,
      'tipo_negocio': businessType,
      'nombre_negocio': businessName,
      'actividad_economica': _activityCode(businessType),
      'antiguedad_negocio_meses': businessAgeMonths,
      'ingresos_estimados': estimatedIncome,
      'gastos_mensuales': monthlyExpenses,
      'patrimonio_estimado': estimatedAssets,
      'tiene_conyuge': hasSpouse,
      if (hasSpouse)
        'conyuge_json': {'nombre': spouseName},
      'tiene_garante': hasGuarantor,
      if (hasGuarantor)
        'garante_json': {'nombre': guarantorName},
      'monto_solicitado': requestedAmount,
      'plazo_meses': termMonths,
      'moneda': 'PEN',
      'tipo_cuota': 'mensual',
      'garantia': guaranteeType,
      'destino_credito': creditPurpose,
      'cuota_estimada': estimatedInstallment,
      'tea_referencial': referenceTea,
      'estado': CreditRequestStatus.submitted.code,
      'firma_cliente_base64': signatureBase64,
      if (captureLatitude != null) 'lat_captura': captureLatitude,
      if (captureLongitude != null) 'lng_captura': captureLongitude,
      'pendiente_sync': pendienteSync,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class CreditRequestSubmitResult {
  const CreditRequestSubmitResult({
    this.solicitudId,
    this.offline = false,
    this.errorMessage,
  });

  final String? solicitudId;
  final bool offline;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

double estimateInstallment(double amount, int months, double teaPercent) {
  if (months <= 0) {
    return 0;
  }
  final monthlyRate = teaPercent / 100 / 12;
  if (monthlyRate <= 0) {
    return amount / months;
  }
  final factor = pow(1 + monthlyRate, months);
  return amount * monthlyRate * factor / (factor - 1);
}

String _generateExpedienteNumber() {
  final suffix = DateTime.now().millisecondsSinceEpoch % 100000000;
  return 'SOL-$suffix';
}

String _activityCode(String businessType) {
  return switch (businessType.toLowerCase()) {
    'servicios' => 'SERV',
    'produccion' => 'PROD',
    'agropecuario' => 'AGRO',
    _ => 'COM',
  };
}

int? _intValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}
