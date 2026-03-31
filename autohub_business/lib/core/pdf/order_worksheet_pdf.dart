import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/models/order_model.dart';
import '../../shared/models/organization_business_kind.dart';
import '../utils/formatters.dart';

/// Печать / предпросмотр заказ-наряда (как в типичном СТО).
Future<void> printOrderWorksheet(
  BuildContext context,
  Order order, {
  required bool showPrices,
}) async {
  try {
    final regular = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final bytes = await _buildPdfBytes(order, showPrices: showPrices, font: regular, fontBold: bold);
    final safeNum = order.orderNumber.replaceAll(RegExp(r'[^\w\-]+'), '_');
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
  required bool showPrices,
  required pw.Font font,
  required pw.Font fontBold,
}) async {
  final items = order.itemsForDisplay;
  final orgName = (order.organizationName ?? '').trim();
  final orgLines = <String>[
    if (orgName.isNotEmpty) orgName,
    if ((order.organizationAddress ?? '').trim().isNotEmpty) order.organizationAddress!.trim(),
    if ((order.organizationPhone ?? '').trim().isNotEmpty) 'тел.: ${order.organizationPhone!.trim()}',
  ];
  final kindLabel = OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind);
  final modeLabel = OrganizationBusinessKindCodes.schedulingModeShortLabel(order.organizationSchedulingMode);
  if (kindLabel.isNotEmpty) orgLines.add('Вид: $kindLabel');
  if (modeLabel.isNotEmpty) orgLines.add('Запись: $modeLabel');

  pw.Widget cell(String text, {pw.Font? f, bool bold = false}) {
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
        if (showPrices) cell('Сумма', bold: true),
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
          if (showPrices) cell(i.priceKopecks != null ? formatMoney(i.priceKopecks!) : '—'),
        ],
      ),
    );
    idx++;
  }

  final start = order.plannedStartTime ?? order.dateTime;
  final end = order.plannedEndTime;
  final dur = order.estimatedMinutesForDisplay;
  final endStr = end != null
      ? formatTime(end)
      : (start != null ? formatTime(start.add(Duration(minutes: dur > 0 ? dur : 60))) : '—');

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
            '№ ${order.displayNumber.replaceAll('#', '')} от ${formatDateOrNull(order.createdAt ?? order.dateTime)}',
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
                    pw.Text(order.carInfo, style: pw.TextStyle(font: font, fontSize: 9)),
                    if (order.vin != null && order.vin!.trim().isNotEmpty)
                      pw.Text('VIN: ${order.vin}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty)
                      pw.Text('Гос. номер: ${order.licensePlate}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (order.mileage != null) pw.Text('Пробег: ${order.mileage} км', style: pw.TextStyle(font: font, fontSize: 8)),
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
              pw.Text('Статус: ${order.status.label}', style: pw.TextStyle(font: font, fontSize: 9)),
              if (start != null)
                pw.Text(
                  'Приём: ${formatDateTime(start)}${end != null ? ' — $endStr' : ''}',
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
            if (showPrices) 3: const pw.FixedColumnWidth(64),
          },
          children: tableRows,
        ),
        if (showPrices && order.totalKopecksForDisplay > 0) ...[
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'ИТОГО: ${formatMoney(order.totalKopecksForDisplay)}',
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
          'Документ сформирован в AutoHub. Подписи сторон подтверждают согласие с перечнем работ и стоимостью (если указана).',
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

