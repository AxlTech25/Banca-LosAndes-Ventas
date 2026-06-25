import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../shared/widgets/risk_semaphore.dart';
import '../models/client_profile.dart';

class ClientProfileRepository {
  ClientProfileRepository({
    required supabase.SupabaseClient client,
    required String advisorId,
    required SharedPreferences preferences,
    Connectivity? connectivity,
  }) : _client = client,
       _advisorId = advisorId,
       _preferences = preferences,
       _connectivity = connectivity ?? Connectivity();

  final supabase.SupabaseClient _client;
  final String _advisorId;
  final SharedPreferences _preferences;
  final Connectivity _connectivity;

  String _cacheKey(String clientId) => 'ficha_cliente_${_advisorId}_$clientId';

  Future<ProfileLoadResult> loadProfile(String clientId) async {
    if (await _hasNetwork()) {
      try {
        final profile = await _fetchRemoteProfile(clientId);
        await _cacheProfile(clientId, profile);
        return ProfileLoadResult(profile: profile, fromCache: false);
      } catch (_) {
        final cached = await _loadCachedProfile(clientId);
        if (cached != null) {
          return ProfileLoadResult(profile: cached, fromCache: true);
        }
        rethrow;
      }
    }

    final cached = await _loadCachedProfile(clientId);
    if (cached != null) {
      return ProfileLoadResult(profile: cached, fromCache: true);
    }
    throw Exception('Sin conexion y sin ficha en cache local.');
  }

  Future<ClientProfile> _fetchRemoteProfile(String clientId) async {
    final clientRow = await _client
        .from('clientes')
        .select()
        .eq('id', clientId)
        .maybeSingle();
    if (clientRow == null) {
      throw Exception('Cliente no encontrado.');
    }

    final credits = await _client
        .from('creditos')
        .select()
        .eq('cliente_id', clientId)
        .order('fecha_desembolso', ascending: false)
        .limit(5);

    final preapprovedRow = await _client
        .from('creditos_preaprobados')
        .select()
        .eq('cliente_id', clientId)
        .eq('asesor_id', _advisorId)
        .eq('vigente', true)
        .gte('fecha_vencimiento', _dateOnly(DateTime.now()))
        .order('score_confianza', ascending: false)
        .limit(1)
        .maybeSingle();

    final creditMaps = (credits as List).cast<Map<String, dynamic>>();
    final position = _buildPosition(creditMaps);
    final history = creditMaps.map(_mapCreditHistory).toList();
    final paymentBehavior = _buildPaymentBehavior(creditMaps);

    final nombres = (clientRow['nombres'] ?? '').toString();
    final apellidos = (clientRow['apellidos'] ?? '').toString();

    return ClientProfile(
      clientId: clientId,
      fullName: '$nombres $apellidos'.trim(),
      documentNumber: (clientRow['numero_documento'] ?? '').toString(),
      phone: (clientRow['telefono'] ?? '').toString(),
      email: clientRow['email']?.toString(),
      address: (clientRow['direccion'] ?? '').toString(),
      businessType: (clientRow['tipo_negocio'] ?? '').toString(),
      businessName: (clientRow['nombre_negocio'] ?? '').toString(),
      businessAgeMonths: _intValue(clientRow['antiguedad_negocio_meses']),
      sbsRating: SbsRating.fromCode(clientRow['calificacion_sbs']?.toString()),
      latitude: _optionalDouble(clientRow['lat']),
      longitude: _optionalDouble(clientRow['lng']),
      position: position,
      creditHistory: history,
      paymentBehavior: paymentBehavior,
      preapproved: preapprovedRow == null
          ? null
          : PreapprovedOffer(
              maxAmount: _doubleValue(preapprovedRow['monto_maximo']),
              suggestedTermMonths: _intValue(
                preapprovedRow['plazo_sugerido_meses'],
              ),
              referenceTea: _doubleValue(preapprovedRow['tea_referencial']),
              confidenceScore: _intValue(preapprovedRow['score_confianza']),
              expirationDate:
                  DateTime.tryParse(
                    (preapprovedRow['fecha_vencimiento'] ?? '').toString(),
                  ) ??
                  DateTime.now(),
            ),
    );
  }

  ClientPosition _buildPosition(List<Map<String, dynamic>> credits) {
    var totalDebt = 0.0;
    var activeAccounts = 0;
    var overdueAccounts = 0;
    var maxOverdue = 0;
    var onTime = 0;
    var overdueInstallments = 0;
    DateTime? lastPayment;

    for (final credit in credits) {
      final estado = (credit['estado'] ?? '').toString();
      if (estado == 'pagado') {
        continue;
      }
      activeAccounts++;
      totalDebt += _doubleValue(credit['saldo_actual']);
      final diasMora = _intValue(credit['dias_mora']);
      if (diasMora > 0) {
        overdueAccounts++;
        overdueInstallments += diasMora > 30 ? 2 : 1;
        maxOverdue = diasMora > maxOverdue ? diasMora : maxOverdue;
      } else {
        onTime += _intValue(credit['cuotas_pagadas']);
      }

      final disbursement = DateTime.tryParse(
        (credit['fecha_desembolso'] ?? '').toString(),
      );
      if (disbursement != null) {
        final estimatedLastPayment = disbursement.add(
          Duration(days: 30 * _intValue(credit['cuotas_pagadas'])),
        );
        if (lastPayment == null || estimatedLastPayment.isAfter(lastPayment)) {
          lastPayment = estimatedLastPayment;
        }
      }
    }

    return ClientPosition(
      totalDebt: totalDebt,
      activeAccounts: activeAccounts,
      overdueAccounts: overdueAccounts,
      maxHistoricalOverdueDays: maxOverdue,
      lastPaymentDate: lastPayment,
      onTimeInstallments: onTime,
      overdueInstallments: overdueInstallments,
    );
  }

  CreditHistoryItem _mapCreditHistory(Map<String, dynamic> credit) {
    final total = _intValue(credit['cuotas_total']);
    final paid = _intValue(credit['cuotas_pagadas']);
    final rate = total == 0 ? 0.0 : (paid / total) * 100;

    return CreditHistoryItem(
      amount: _doubleValue(credit['monto_desembolsado']),
      termMonths: _intValue(credit['plazo_meses']),
      tea: _doubleValue(credit['tea']),
      status: (credit['estado'] ?? '').toString(),
      punctualPaymentRate: rate,
      disbursementDate: DateTime.tryParse(
        (credit['fecha_desembolso'] ?? '').toString(),
      ),
    );
  }

  List<PaymentBehaviorMonth> _buildPaymentBehavior(
    List<Map<String, dynamic>> credits,
  ) {
    if (credits.isEmpty) {
      return List.generate(12, (index) {
        final month = DateTime(DateTime.now().year, DateTime.now().month - 11 + index);
        return PaymentBehaviorMonth(
          month: DateTime(month.year, month.month),
          status: PaymentMonthStatus.noInstallment,
          amountPaid: 0,
        );
      });
    }

    final primary = credits.first;
    final monthlyPayment = _doubleValue(primary['monto_desembolsado']) /
        (_intValue(primary['plazo_meses']).clamp(1, 120));
    final currentOverdue = _intValue(primary['dias_mora']);

    return List.generate(12, (index) {
      final month = DateTime(
        DateTime.now().year,
        DateTime.now().month - (11 - index),
      );
      final normalizedMonth = DateTime(month.year, month.month);

      if (index >= 10 && currentOverdue > 0) {
        return PaymentBehaviorMonth(
          month: normalizedMonth,
          status: PaymentMonthStatus.late,
          amountPaid: monthlyPayment * 0.5,
        );
      }

      if (index >= 8) {
        return PaymentBehaviorMonth(
          month: normalizedMonth,
          status: PaymentMonthStatus.onTime,
          amountPaid: monthlyPayment,
        );
      }

      return PaymentBehaviorMonth(
        month: normalizedMonth,
        status: PaymentMonthStatus.noInstallment,
        amountPaid: 0,
      );
    });
  }

  Future<String> reverseGeocode(double latitude, double longitude) async {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) {
      return '$latitude, $longitude';
    }
    final place = placemarks.first;
    return [
      place.street,
      place.subLocality,
      place.locality,
    ].where((part) => part != null && part.isNotEmpty).join(', ');
  }

  Future<ClientProfile> updateBusinessLocation({
    required ClientProfile profile,
    required double latitude,
    required double longitude,
  }) async {
    await _client
        .from('clientes')
        .update({
          'lat': latitude,
          'lng': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', profile.clientId);

    final updated = ClientProfile(
      clientId: profile.clientId,
      fullName: profile.fullName,
      documentNumber: profile.documentNumber,
      phone: profile.phone,
      email: profile.email,
      address: profile.address,
      businessType: profile.businessType,
      businessName: profile.businessName,
      businessAgeMonths: profile.businessAgeMonths,
      sbsRating: profile.sbsRating,
      latitude: latitude,
      longitude: longitude,
      position: profile.position,
      creditHistory: profile.creditHistory,
      paymentBehavior: profile.paymentBehavior,
      preapproved: profile.preapproved,
    );
    await _cacheProfile(profile.clientId, updated);
    return updated;
  }

  Future<void> _cacheProfile(String clientId, ClientProfile profile) async {
    await _preferences.setString(
      _cacheKey(clientId),
      jsonEncode(_profileToCache(profile)),
    );
  }

  Future<ClientProfile?> _loadCachedProfile(String clientId) async {
    final raw = _preferences.getString(_cacheKey(clientId));
    if (raw == null) {
      return null;
    }
    return _profileFromCache(jsonDecode(raw) as Map<String, dynamic>);
  }

  Map<String, dynamic> _profileToCache(ClientProfile profile) {
    return {
      'clientId': profile.clientId,
      'fullName': profile.fullName,
      'documentNumber': profile.documentNumber,
      'phone': profile.phone,
      'email': profile.email,
      'address': profile.address,
      'businessType': profile.businessType,
      'businessName': profile.businessName,
      'businessAgeMonths': profile.businessAgeMonths,
      'sbsRating': profile.sbsRating.label,
      'latitude': profile.latitude,
      'longitude': profile.longitude,
      'position': {
        'totalDebt': profile.position.totalDebt,
        'activeAccounts': profile.position.activeAccounts,
        'overdueAccounts': profile.position.overdueAccounts,
        'maxHistoricalOverdueDays': profile.position.maxHistoricalOverdueDays,
        'lastPaymentDate': profile.position.lastPaymentDate?.toIso8601String(),
        'onTimeInstallments': profile.position.onTimeInstallments,
        'overdueInstallments': profile.position.overdueInstallments,
      },
      'creditHistory': profile.creditHistory
          .map(
            (item) => {
              'amount': item.amount,
              'termMonths': item.termMonths,
              'tea': item.tea,
              'status': item.status,
              'punctualPaymentRate': item.punctualPaymentRate,
              'disbursementDate': item.disbursementDate?.toIso8601String(),
            },
          )
          .toList(),
      'paymentBehavior': profile.paymentBehavior
          .map(
            (month) => {
              'month': month.month.toIso8601String(),
              'status': month.status.name,
              'amountPaid': month.amountPaid,
            },
          )
          .toList(),
      'preapproved': profile.preapproved == null
          ? null
          : {
              'maxAmount': profile.preapproved!.maxAmount,
              'suggestedTermMonths': profile.preapproved!.suggestedTermMonths,
              'referenceTea': profile.preapproved!.referenceTea,
              'confidenceScore': profile.preapproved!.confidenceScore,
              'expirationDate': profile.preapproved!.expirationDate
                  .toIso8601String(),
            },
    };
  }

  ClientProfile _profileFromCache(Map<String, dynamic> json) {
    final positionJson = json['position'] as Map<String, dynamic>;
    final preapprovedJson = json['preapproved'] as Map<String, dynamic>?;

    return ClientProfile(
      clientId: json['clientId'].toString(),
      fullName: json['fullName'].toString(),
      documentNumber: json['documentNumber'].toString(),
      phone: json['phone'].toString(),
      email: json['email']?.toString(),
      address: json['address'].toString(),
      businessType: json['businessType'].toString(),
      businessName: json['businessName'].toString(),
      businessAgeMonths: _intValue(json['businessAgeMonths']),
      sbsRating: SbsRating.fromCode(json['sbsRating']?.toString()),
      latitude: _optionalDouble(json['latitude']),
      longitude: _optionalDouble(json['longitude']),
      position: ClientPosition(
        totalDebt: _doubleValue(positionJson['totalDebt']),
        activeAccounts: _intValue(positionJson['activeAccounts']),
        overdueAccounts: _intValue(positionJson['overdueAccounts']),
        maxHistoricalOverdueDays: _intValue(
          positionJson['maxHistoricalOverdueDays'],
        ),
        lastPaymentDate: DateTime.tryParse(
          (positionJson['lastPaymentDate'] ?? '').toString(),
        ),
        onTimeInstallments: _intValue(positionJson['onTimeInstallments']),
        overdueInstallments: _intValue(positionJson['overdueInstallments']),
      ),
      creditHistory: (json['creditHistory'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (item) => CreditHistoryItem(
              amount: _doubleValue(item['amount']),
              termMonths: _intValue(item['termMonths']),
              tea: _doubleValue(item['tea']),
              status: item['status'].toString(),
              punctualPaymentRate: _doubleValue(item['punctualPaymentRate']),
              disbursementDate: DateTime.tryParse(
                (item['disbursementDate'] ?? '').toString(),
              ),
            ),
          )
          .toList(),
      paymentBehavior: (json['paymentBehavior'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (item) => PaymentBehaviorMonth(
              month: DateTime.parse(item['month'].toString()),
              status: PaymentMonthStatus.values.byName(item['status'].toString()),
              amountPaid: _doubleValue(item['amountPaid']),
            ),
          )
          .toList(),
      preapproved: preapprovedJson == null
          ? null
          : PreapprovedOffer(
              maxAmount: _doubleValue(preapprovedJson['maxAmount']),
              suggestedTermMonths: _intValue(
                preapprovedJson['suggestedTermMonths'],
              ),
              referenceTea: _doubleValue(preapprovedJson['referenceTea']),
              confidenceScore: _intValue(preapprovedJson['confidenceScore']),
              expirationDate: DateTime.parse(
                preapprovedJson['expirationDate'].toString(),
              ),
            ),
    );
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((state) => state != ConnectivityResult.none);
  }

  int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _optionalDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
