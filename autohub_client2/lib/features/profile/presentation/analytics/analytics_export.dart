import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/utils/formatters.dart';

/// Экспорт текущей таблицы аналитики в CSV (разделитель `;`, UTF‑8 с BOM для Excel).
abstract final class AnalyticsExport {
  static String csvEscape(String s) {
    final t = s.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (t.contains(';') || t.contains('"')) {
      return '"${t.replaceAll('"', '""')}"';
    }
    return t;
  }

  static Future<void> shareTable({
    required AppL10n l10n,
    required String carLabel,
    required String periodDescription,
    required String groupByDescription,
    required String metricDescription,
    required String? orgFilterDescription,
    required List<String> groupLabels,
    required List<int> values,
    required String valueColumnTitle,
    required bool valueIsMoney,
  }) async {
    final b = StringBuffer();
    b.write('\uFEFF');
    b.writeln(l10n.analyticsCsvSectionLine);
    b.writeln('${csvEscape(l10n.analyticsCsvVehicle)};${csvEscape(carLabel)}');
    b.writeln('${csvEscape(l10n.analyticsCsvPeriod)};${csvEscape(periodDescription)}');
    b.writeln('${csvEscape(l10n.analyticsCsvGrouping)};${csvEscape(groupByDescription)}');
    b.writeln('${csvEscape(l10n.analyticsCsvMetric)};${csvEscape(metricDescription)}');
    if (orgFilterDescription != null && orgFilterDescription.isNotEmpty) {
      b.writeln('${csvEscape(l10n.analyticsCsvOrgFilter)};${csvEscape(orgFilterDescription)}');
    }
    b.writeln();
    b.writeln('${csvEscape(l10n.analyticsGroupColumn)};${csvEscape(valueColumnTitle)}');
    for (var i = 0; i < groupLabels.length && i < values.length; i++) {
      final v = valueIsMoney ? Formatters.money(values[i]) : '${values[i]}';
      b.writeln('${csvEscape(groupLabels[i])};${csvEscape(v)}');
    }
    await Share.share(b.toString(), subject: l10n.analyticsShareSubject);
  }
}
