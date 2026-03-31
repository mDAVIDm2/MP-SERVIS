import 'package:flutter/material.dart';

/// Документ на автомобиль (ОСАГО, VIN, техосмотр, СТС и др.).
class CarDocument {
  final String carId;
  final String type;
  final String detail;
  final String? status;
  final String? expiry;
  final Color? statusColor;

  const CarDocument({
    required this.carId,
    required this.type,
    required this.detail,
    this.status,
    this.expiry,
    this.statusColor,
  });

  Map<String, dynamic> toJson() => {
        'carId': carId,
        'type': type,
        'detail': detail,
        'status': status,
        'expiry': expiry,
        'statusColor': statusColor?.value,
      };

  static CarDocument fromJson(Map<String, dynamic> j) => CarDocument(
        carId: j['carId'] as String? ?? '',
        type: j['type'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        status: j['status'] as String?,
        expiry: j['expiry'] as String?,
        statusColor: j['statusColor'] != null ? Color(j['statusColor'] as int) : null,
      );
}

/// Типы документов для выбора при добавлении.
const List<String> kCarDocumentTypes = [
  'ОСАГО',
  'VIN',
  'Техосмотр',
  'СТС',
  'ПТС',
  'Другое',
];
