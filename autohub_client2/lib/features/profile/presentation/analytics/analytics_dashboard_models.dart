import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Тип визуализации (совпадает с порядком в [AnalyticsScreen]).
enum AnalyticsChartDisplay { bar, pie, table }

/// Группировка данных.
enum AnalyticsGroupBy { month, orgKind, serviceCategory }

/// Метрика в ячейке.
enum AnalyticsValueMetric {
  totalSpend,
  orderCount,
  avgCheck,
  avgMonthlySpend,
}

/// Один настраиваемый виджет аналитики (свой период, группировка, метрика, формат).
class AnalyticsBlockConfig {
  AnalyticsBlockConfig({
    required this.id,
    this.periodMonths = 12,
    this.groupBy = AnalyticsGroupBy.month,
    this.display = AnalyticsChartDisplay.bar,
    this.metric = AnalyticsValueMetric.totalSpend,
    this.orgKindFilterCode,
  });

  final String id;
  int periodMonths;
  AnalyticsGroupBy groupBy;
  AnalyticsChartDisplay display;
  AnalyticsValueMetric metric;
  String? orgKindFilterCode;

  AnalyticsBlockConfig copyWith({
    int? periodMonths,
    AnalyticsGroupBy? groupBy,
    AnalyticsChartDisplay? display,
    AnalyticsValueMetric? metric,
    String? orgKindFilterCode,
    bool clearOrgFilter = false,
  }) {
    return AnalyticsBlockConfig(
      id: id,
      periodMonths: periodMonths ?? this.periodMonths,
      groupBy: groupBy ?? this.groupBy,
      display: display ?? this.display,
      metric: metric ?? this.metric,
      orgKindFilterCode: clearOrgFilter ? null : (orgKindFilterCode ?? this.orgKindFilterCode),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'periodMonths': periodMonths,
        'groupBy': groupBy.index,
        'display': display.index,
        'metric': metric.index,
        'orgKind': orgKindFilterCode,
      };

  static AnalyticsBlockConfig fromJson(Map<String, dynamic> m) {
    return AnalyticsBlockConfig(
      id: m['id'] as String? ?? 'b_${DateTime.now().millisecondsSinceEpoch}',
      periodMonths: (m['periodMonths'] as num?)?.toInt() ?? 12,
      groupBy: AnalyticsGroupBy.values[((m['groupBy'] as num?)?.toInt() ?? 0).clamp(0, AnalyticsGroupBy.values.length - 1)],
      display: AnalyticsChartDisplay.values[((m['display'] as num?)?.toInt() ?? 0).clamp(0, AnalyticsChartDisplay.values.length - 1)],
      metric: AnalyticsValueMetric.values[((m['metric'] as num?)?.toInt() ?? 0).clamp(0, AnalyticsValueMetric.values.length - 1)],
      orgKindFilterCode: m['orgKind'] as String?,
    );
  }
}

const _kBlocksJson = 'client_analytics_v2_blocks';
const _kLegacyPeriod = 'client_analytics_period_m';
const _kLegacyGroup = 'client_analytics_group';
const _kLegacyDisplay = 'client_analytics_display';
const _kLegacyMetric = 'client_analytics_metric';

class AnalyticsDashboardStorage {
  static Future<List<AnalyticsBlockConfig>> load(SharedPreferences prefs) async {
    final raw = prefs.getString(_kBlocksJson);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        if (list.isEmpty) return [_defaultBlock()];
        return list.map((e) => AnalyticsBlockConfig.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return _migrateFromLegacy(prefs);
  }

  static List<AnalyticsBlockConfig> _migrateFromLegacy(SharedPreferences prefs) {
    final period = prefs.getInt(_kLegacyPeriod) ?? 12;
    final g = (prefs.getInt(_kLegacyGroup) ?? 0).clamp(0, AnalyticsGroupBy.values.length - 1);
    final d = (prefs.getInt(_kLegacyDisplay) ?? 0).clamp(0, AnalyticsChartDisplay.values.length - 1);
    final met = (prefs.getInt(_kLegacyMetric) ?? 0).clamp(0, AnalyticsValueMetric.values.length - 1);
    return [
      AnalyticsBlockConfig(
        id: 'migrated_1',
        periodMonths: period,
        groupBy: AnalyticsGroupBy.values[g],
        display: AnalyticsChartDisplay.values[d],
        metric: AnalyticsValueMetric.values[met],
      ),
    ];
  }

  static AnalyticsBlockConfig _defaultBlock() => AnalyticsBlockConfig(id: 'default_1');

  static Future<void> save(SharedPreferences prefs, List<AnalyticsBlockConfig> blocks) async {
    final enc = jsonEncode(blocks.map((b) => b.toJson()).toList());
    await prefs.setString(_kBlocksJson, enc);
  }
}
