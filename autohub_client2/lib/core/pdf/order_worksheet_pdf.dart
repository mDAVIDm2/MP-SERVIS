import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/models/car_model.dart';
import '../../shared/models/order_model.dart';
import '../../shared/org_business_kind.dart';

DateTime _local(DateTime d) => d.toLocal();

String _formatMoney(int kopecks) {
  final rub = kopecks / 100;
  return NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0).format(rub);
}

String _formatDate(DateTime d) => DateFormat('dd.MM.yyyy').format(_local(d));
String _formatTime(DateTime d) => DateFormat('HH:mm').format(_local(d));
String _formatDateTime(DateTime d) => DateFormat('dd.MM.yyyy HH:mm').format(_local(d));
String _formatDateOrNull(DateTime? d) => d == null ? '—' : _formatDate(d);

/// Дополняет заказ данными из гаража, если в ответе API не было строки авто / VIN / номера.
Order _orderForPdf(Order order, Car? car) {
  if (car == null || car.id != order.carId) return order;
  final parts = <String>[car.brand, car.model, if (car.year > 0) '${car.year}'];
  final fromCar = parts.where((s) => s.trim().isNotEmpty).join(' ');
  final hasCarInfo = (order.carInfo ?? '').trim().isNotEmpty;
  return order.copyWith(
    carInfo: hasCarInfo ? order.carInfo : (fromCar.isEmpty ? order.carInfo : fromCar),
    vin: order.vin ?? car.vin,
    licensePlate: order.licensePlate ?? car.plateNumber,
    mileage: order.mileage ?? (car.mileage > 0 ? car.mileage : null),
  );
}

/// Печать / предпросмотр заказ-наряда (как в типичном СТО).
Future<void> printOrderWorksheet(
  BuildContext context,
  Order order, {
  Car? car,
}) async {
  final merged = _orderForPdf(order, car);
  try {
    final regular = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final bytes = await _buildPdfBytes(merged, font: regular, fontBold: bold);
    final safeNum = merged.orderNumber.replaceAll(RegExp(r'[^\w\-]+'), '_');
    await Printing.layoutPdf(
      name: 'zakaz_naryad_$safeNum.pdf',
      onLayout: (_) async => bytes,
    );
  } catch (e, st) {
    debugPrint('printOrderWorksheet: $e\n$st');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось сформировать PDF. Нужен интернет для загрузки шрифта (первый раз) или проверьте настройки печати.\n$e',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }
}

Future<Uint8List> _buildPdfBytes(
  Order order, {
  required pw.Font font,
  required pw.Font fontBold,
}) async {
  final items = order.itemsForDisplay;
  final orgName = order.stoName.trim();
  final orgLines = <String>[
    if (orgName.isNotEmpty) orgName,
    if ((order.stoAddress ?? '').trim().isNotEmpty) order.stoAddress!.trim(),
    if ((order.stoPhone ?? '').trim().isNotEmpty) 'тел.: ${order.stoPhone!.trim()}',
  ];
  final kindLabel = OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind);
  final modeLabel = OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode);
  if (kindLabel.isNotEmpty) orgLines.add('Вид: $kindLabel');
  if (modeLabel.isNotEmpty) orgLines.add('Запись: $modeLabel');

  pw.Widget cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 9),
      ),
    );
  }

  final tableRows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell('№', bold: true),
        cell('Наименование работ', bold: true),
        cell('Норма, мин', bold: true),
        cell('Сумма', bold: true),
      ],
    ),
  ];

  var idx = 1;
  for (final i in items) {
    tableRows.add(
      pw.TableRow(
        children: [
          cell('$idx'),
          cell(i.name),
          cell('${i.estimatedMinutes}'),
          cell(_formatMoney(i.priceKopecks)),
        ],
      ),
    );
    idx++;
  }

  final start = order.plannedStartTime ?? order.dateTime;
  final end = order.plannedEndTime;
  final dur = order.estimatedMinutesForDisplay;
  final endStr = end != null
      ? _formatTime(end)
      : _formatTime(start.add(Duration(minutes: dur > 0 ? dur : 60)));

  final carLine = (order.carInfo ?? '').trim();
  final mileageShow = order.mileage ?? order.odometerAtCompletion;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Center(
          child: pw.Text(
            'ЗАКАЗ-НАРЯД',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            '№ ${order.displayNumber.replaceAll('#', '')} от ${_formatDateOrNull(order.createdAt ?? order.dateTime)}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ИСПОЛНИТЕЛЬ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.SizedBox(height: 4),
              ...orgLines.map((l) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text(l, style: pw.TextStyle(font: font, fontSize: 9)),
                  )),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ЗАКАЗЧИК', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Text(order.clientName ?? '—', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(order.clientPhone ?? '—', style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('АВТОМОБИЛЬ', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Text(carLine.isEmpty ? '—' : carLine, style: pw.TextStyle(font: font, fontSize: 9)),
                    if (order.vin != null && order.vin!.trim().isNotEmpty)
                      pw.Text('VIN: ${order.vin}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty)
                      pw.Text('Гос. номер: ${order.licensePlate}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (mileageShow != null && mileageShow > 0)
                      pw.Text('Пробег: $mileageShow км', style: pw.TextStyle(font: font, fontSize: 8)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('СТАТУС И СРОКИ', style: pw.TextStyle(font: fontBold, fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text('Статус: ${order.displayStatus.label}', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text(
                'Приём: ${_formatDateTime(start)}${end != null ? ' — $endStr' : ''}',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text('Мастер: ${order.masterName ?? 'не назначен'}', style: pw.TextStyle(font: font, fontSize: 9)),
              if (order.bayName != null && order.bayName!.trim().isNotEmpty)
                pw.Text('Пост / бокс: ${order.bayName!.trim()}', style: pw.TextStyle(font: font, fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('РАБОТЫ И МАТЕРИАЛЫ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(52),
            3: const pw.FixedColumnWidth(64),
          },
          children: tableRows,
        ),
        if (order.totalKopecksForDisplay > 0) ...[
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'ИТОГО: ${_formatMoney(order.totalKopecksForDisplay)}',
              style: pw.TextStyle(font: fontBold, fontSize: 11),
            ),
          ),
        ],
        if (order.comment != null && order.comment!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Комментарий:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
          pw.Text(order.comment!.trim(), style: pw.TextStyle(font: font, fontSize: 9)),
        ],
        pw.SizedBox(height: 24),
        pw.Text(
          'Документ сформирован в AutoHub. Подписи сторон подтверждают согласие с перечнем работ и стоимостью.',
          style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Исполнитель', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  pw.SizedBox(height: 22),
                  pw.Text('________________ / ________________', style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Заказчик', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  pw.SizedBox(height: 22),
                  pw.Text('________________ / ________________', style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
