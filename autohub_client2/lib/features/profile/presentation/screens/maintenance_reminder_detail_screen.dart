import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';
import '../widgets/add_maintenance_record_sheet.dart';

String _maintenanceDetailEmoji(MaintenanceType t) {
  switch (t) {
    case MaintenanceType.oil:
      return '🛢';
    case MaintenanceType.tires:
      return '🛞';
    case MaintenanceType.battery:
      return '🔋';
    case MaintenanceType.antifreeze:
      return '❄️';
    case MaintenanceType.brakes:
      return '🔧';
    case MaintenanceType.inspection:
      return '🔍';
    default:
      return '⚙️';
  }
}

/// Полная карточка напоминания: интервалы, три блока «было / осталось / потребуется», история, запись вручную.
class MaintenanceReminderDetailScreen extends ConsumerStatefulWidget {
  const MaintenanceReminderDetailScreen({
    super.key,
    required this.car,
    required this.type,
  });

  final Car car;
  final MaintenanceType type;

  @override
  ConsumerState<MaintenanceReminderDetailScreen> createState() => _MaintenanceReminderDetailScreenState();
}

class _MaintenanceReminderDetailScreenState extends ConsumerState<MaintenanceReminderDetailScreen> {
  final GlobalKey<_IntervalsCardState> _intervalsKey = GlobalKey<_IntervalsCardState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(maintenanceRemindersProvider);
    final notifier = ref.read(maintenanceRemindersProvider.notifier);
    final car = widget.car;
    final type = widget.type;
    final config = notifier.getConfig(car.id, type.name);
    final records = notifier.getRecords(car.id, type.name);
    final snap = notifier.computeDue(car.id, type.name, car.mileage);
    final oilQuickSetup = type == MaintenanceType.oil && records.isEmpty && config != null;
    final l10n = L10nScope.of(context);
    final showHistorySection = records.isNotEmpty || config != null;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        title: Text(
          type.localizedTitle(l10n),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.palette.textPrimary,
          ),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          32 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          if (oilQuickSetup)
            _OilQuickSetupBanner(car: car, l10n: l10n)
          else
            _SummaryCard(
              car: car,
              type: type,
              config: config,
              snap: snap,
              l10n: l10n,
            ),
          if (config != null) ...[
            SizedBox(height: 16),
            _IntervalsCard(
              key: _intervalsKey,
              car: car,
              type: type,
              config: config,
              notifier: notifier,
            ),
          ],
          if (showHistorySection) ...[
            SizedBox(height: 18),
            Row(
              children: [
                Text(
                  l10n.replacementHistory,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary.withValues(alpha: 0.95),
                  ),
                ),
                const Spacer(),
                if (records.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => showAddMaintenanceRecordSheet(
                      context,
                      ref,
                      cars: [car],
                      initialCar: car,
                      initialType: type,
                    ),
                    icon: Icon(Icons.add_rounded, size: 20),
                    label: Text(l10n.add),
                  ),
              ],
            ),
            SizedBox(height: 8),
            if (records.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => showAddMaintenanceRecordSheet(
                      context,
                      ref,
                      cars: [car],
                      initialCar: car,
                      initialType: type,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text(l10n.maintHistoryAddBigButton, style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.maintHistoryAddBigButtonSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35),
                  ),
                ],
              )
            else
              ...records.map(
                (r) => _RecordTile(
                  record: r,
                  l10n: l10n,
                  onDelete: () {
                    notifier.removeRecord(r.id);
                  },
                ),
              ),
          ],
          if (config != null) ...[
            SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => _confirmRemoveReminder(context, ref, car.id, type.name, l10n),
                child: Text(
                  l10n.removeReminderFromList,
                  style: TextStyle(color: context.palette.error, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: config == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: () {
                    _intervalsKey.currentState?.commitIntervals();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.settingsSaved),
                        backgroundColor: context.palette.success,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: context.palette.primary,
                    foregroundColor: context.palette.onAccent,
                  ),
                  child: Text(l10n.save, style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
    );
  }

  static Future<void> _confirmRemoveReminder(
    BuildContext context,
    WidgetRef ref,
    String carId,
    String typeKey,
    AppL10n l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text(l10n.removeReminderTitle, style: TextStyle(color: context.palette.textPrimary)),
        content: Text(
          l10n.removeReminderBody,
          style: TextStyle(color: context.palette.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.removeAction, style: TextStyle(color: context.palette.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ref.read(maintenanceRemindersProvider.notifier).deleteConfig(carId, typeKey);
      Navigator.pop(context);
    }
  }

}

/// Первый шаг для масла: без тяжёлой сводки — только подсказка и поля интервалов ниже.
class _OilQuickSetupBanner extends StatelessWidget {
  const _OilQuickSetupBanner({required this.car, required this.l10n});

  final Car car;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_maintenanceDetailEmoji(MaintenanceType.oil), style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  MaintenanceType.oil.localizedTitle(l10n),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            car.displayName,
            style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.car,
    required this.type,
    required this.config,
    required this.snap,
    required this.l10n,
  });

  final Car car;
  final MaintenanceType type;
  final MaintenanceConfig? config;
  final MaintenanceDueSnapshot snap;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    if (config == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          l10n.reminderNotAdded,
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary, height: 1.35),
        ),
      );
    }

    final cfg = config!;
    final last = snap.lastRecord;
    final kmLine = cfg.useKmInterval && cfg.intervalKm > 0;
    final moLine = cfg.useMonthsInterval && cfg.intervalMonths > 0;
    final df = DateFormat('dd.MM.yyyy', l10n.locale.languageCode);
    final sep = NumberFormat.decimalPattern(l10n.intlLocale);

    String fmtKm(int? k) {
      if (k == null) return '—';
      return l10n.mileageValue(k);
    }

    String remainingValue() {
      if (last == null) return '—';
      final parts = <String>[];
      if (kmLine && snap.kmRemaining != null) {
        final k = snap.kmRemaining!;
        if (k < 0) {
          parts.add(l10n.maintShortKmOverdue(sep.format(k)));
        } else {
          parts.add(l10n.maintShortKmLeft(sep.format(k)));
        }
      }
      if (moLine && snap.daysRemaining != null) {
        final d = snap.daysRemaining!;
        if (d < 0) {
          parts.add(l10n.maintShortDaysOverdue(sep.format(d)));
        } else {
          parts.add(l10n.maintShortDaysLeft(d));
        }
      }
      if (parts.isEmpty) return '—';
      return parts.join(' · ');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_maintenanceDetailEmoji(type), style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.localizedTitle(l10n),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      car.displayName,
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _line(
            context,
            l10n.lastReplacement,
            last != null ? '${fmtKm(last.odometerKm)} · ${df.format(last.date)}' : l10n.noDataAddRecord,
            context.palette.textPrimary,
          ),
          SizedBox(height: 12),
          _line(
            context,
            snap.overdue ? l10n.overdueStatusLabel : l10n.remaining,
            last == null ? '—' : remainingValue().orDashIfEmpty(),
            snap.overdue ? context.palette.error : context.palette.textPrimary,
          ),
          SizedBox(height: 12),
          _line(
            context,
            l10n.nextReplacement,
            last == null
                ? '—'
                : [
                    if (kmLine && snap.nextDueKm != null) '${l10n.onMileagePrefix}${fmtKm(snap.nextDueKm)}',
                    if (moLine && snap.nextDueDate != null) '${l10n.untilPrefix}${df.format(snap.nextDueDate!)}',
                  ].join(' · ').orDashIfEmpty(),
            snap.overdue ? context.palette.error : context.palette.primary,
          ),
          if (snap.overdue) ...[
            SizedBox(height: 10),
            Text(
              snap.overdueByKm && snap.overdueByDate
                  ? l10n.overdueKmAndDate
                  : snap.overdueByKm
                      ? l10n.overdueKm
                      : l10n.overdueDate,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.palette.textSecondary)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor, height: 1.25)),
      ],
    );
  }
}

extension _StrOr on String {
  String orDashIfEmpty() => isEmpty ? '—' : this;
}

const int _kKmIntervalMin = 100;
const int _kKmIntervalMax = 500000;
const int _kMonthsIntervalMin = 1;
const int _kMonthsIntervalMax = 120;

/// Диапазон, который покрывает слайдер км (как раньше: с шагом 1000 от 1000 до 15000).
const int _kKmSliderMin = 1000;
const int _kKmSliderMax = 15000;

int _clampKmInterval(int v) => v.clamp(_kKmIntervalMin, _kKmIntervalMax);
int _clampMonthsInterval(int v) => v.clamp(_kMonthsIntervalMin, _kMonthsIntervalMax);

class _IntervalsCard extends StatefulWidget {
  const _IntervalsCard({
    super.key,
    required this.car,
    required this.type,
    required this.config,
    required this.notifier,
  });

  final Car car;
  final MaintenanceType type;
  final MaintenanceConfig config;
  final MaintenanceRemindersNotifier notifier;

  @override
  State<_IntervalsCard> createState() => _IntervalsCardState();
}

class _IntervalsCardState extends State<_IntervalsCard> {
  late final TextEditingController _kmCtrl;
  late final TextEditingController _monthsCtrl;

  @override
  void initState() {
    super.initState();
    _kmCtrl = TextEditingController(text: '${_clampKmInterval(widget.config.intervalKm)}');
    _monthsCtrl = TextEditingController(
      text: widget.config.intervalMonths > 0
          ? '${_clampMonthsInterval(widget.config.intervalMonths)}'
          : '12',
    );
    _kmCtrl.addListener(() => setState(() {}));
    _monthsCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _IntervalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.intervalKm != widget.config.intervalKm) {
      _kmCtrl.text = '${_clampKmInterval(widget.config.intervalKm)}';
    }
    if (oldWidget.config.intervalMonths != widget.config.intervalMonths) {
      _monthsCtrl.text = widget.config.intervalMonths > 0
          ? '${_clampMonthsInterval(widget.config.intervalMonths)}'
          : '12';
    }
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  void _savePartial({
    int? intervalKm,
    bool? useKm,
    int? intervalMonths,
    bool? useMonths,
  }) {
    final c = widget.config;
    widget.notifier.setConfig(MaintenanceConfig(
      carId: c.carId,
      typeKey: c.typeKey,
      intervalKm: intervalKm ?? c.intervalKm,
      useKmInterval: useKm ?? c.useKmInterval,
      intervalMonths: intervalMonths ?? c.intervalMonths,
      useMonthsInterval: useMonths ?? c.useMonthsInterval,
      remindEnabled: c.remindEnabled,
    ));
  }

  /// Сохранить километраж и месяцы из полей (кнопка «Сохранить» снизу экрана).
  void commitIntervals() {
    final c = widget.config;
    final nKm = int.tryParse(_kmCtrl.text.replaceAll(RegExp(r'\s'), ''));
    final nMo = int.tryParse(_monthsCtrl.text.trim());
    final km = nKm != null ? _clampKmInterval(nKm) : _clampKmInterval(c.intervalKm);
    final mo = nMo != null
        ? _clampMonthsInterval(nMo)
        : _clampMonthsInterval(c.intervalMonths > 0 ? c.intervalMonths : 12);
    widget.notifier.setConfig(MaintenanceConfig(
      carId: c.carId,
      typeKey: c.typeKey,
      intervalKm: km,
      useKmInterval: c.useKmInterval,
      intervalMonths: mo,
      useMonthsInterval: c.useMonthsInterval,
      remindEnabled: c.remindEnabled,
    ));
  }

  /// Значение км из поля: для подписи и сохранения (с учётом ручного ввода, без округления).
  int get _kmForSlider {
    final n = int.tryParse(_kmCtrl.text.replaceAll(RegExp(r'\s'), ''));
    if (n == null) return _clampKmInterval(widget.config.intervalKm);
    return _clampKmInterval(n);
  }

  /// 0…14: позиция слайдера по диапазону 1000–15000; значения <1000 или >15000 — у края (ручной ввод всё равно в поле).
  int get _kmSliderStepIndex {
    final km = _kmForSlider;
    if (km < _kKmSliderMin) return 0;
    if (km > _kKmSliderMax) return 14;
    return ((km - _kKmSliderMin) / 1000).round().clamp(0, 14);
  }

  int get _monthsForSlider {
    final n = int.tryParse(_monthsCtrl.text.trim());
    if (n == null) {
      final m = widget.config.intervalMonths;
      return m > 0 ? m.clamp(_kMonthsIntervalMin, _kMonthsIntervalMax) : 12;
    }
    return n.clamp(_kMonthsIntervalMin, _kMonthsIntervalMax);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final l10n = L10nScope.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.reminderEnabled),
            value: c.remindEnabled,
            activeThumbColor: context.palette.primary,
            onChanged: (v) => widget.notifier.setRemindEnabled(widget.car.id, widget.type.name, v),
          ),
          if (c.remindEnabled) ...[
            SizedBox(height: 8),
            _intervalBlock(
              title: l10n.intervalByMileage,
              enabled: c.useKmInterval,
              onToggle: (v) => setState(() => _savePartial(useKm: v)),
              field: _kmSliderRow(context, l10n),
            ),
            SizedBox(height: 8),
            _intervalBlock(
              title: l10n.intervalByTime,
              enabled: c.useMonthsInterval,
              onToggle: (v) => setState(() => _savePartial(useMonths: v)),
              field: _monthsSliderBlock(context, l10n),
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _intervalBlock({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required Widget field,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 10, compact ? 6 : 8, compact ? 8 : 10, compact ? 8 : 10),
      decoration: BoxDecoration(
        color: context.palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(title, style: TextStyle(fontSize: compact ? 13 : 14, fontWeight: FontWeight.w600)),
            value: enabled,
            activeThumbColor: context.palette.primary,
            onChanged: onToggle,
          ),
          if (enabled) field,
        ],
      ),
    );
  }

  Widget _kmSliderRow(BuildContext context, AppL10n l10n) {
    final step = _kmSliderStepIndex;
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 0, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: pal.primary,
                    inactiveTrackColor: pal.border,
                    thumbColor: pal.primary,
                    overlayColor: pal.primary.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: step.toDouble(),
                    min: 0,
                    max: 14,
                    divisions: 14,
                    label: '$_kmForSlider',
                    onChanged: (v) {
                      final s = v.round().clamp(0, 14);
                      final km = _kKmSliderMin + s * 1000;
                      final t = '$km';
                      if (_kmCtrl.text != t) {
                        _kmCtrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
                      }
                      setState(() {});
                    },
                  ),
                ),
              ),
              SizedBox(width: 2),
              SizedBox(
                width: 104,
                child: TextField(
                  controller: _kmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    suffixText: l10n.kmBetween,
                    suffixStyle: TextStyle(fontSize: 12, color: pal.textSecondary),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              l10n.maintIntervalKmHelper,
              style: TextStyle(fontSize: 12, height: 1.3, color: pal.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthsSliderBlock(BuildContext context, AppL10n l10n) {
    const sliderMax = 24;
    final m = _monthsForSlider > sliderMax ? sliderMax.toDouble() : _monthsForSlider.toDouble();
    final pal = context.palette;
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 2.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      activeTrackColor: pal.primary,
      inactiveTrackColor: pal.border,
      thumbColor: pal.primary,
      overlayColor: pal.primary.withValues(alpha: 0.1),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.78,
                    alignment: Alignment.centerLeft,
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: m,
                        min: _kMonthsIntervalMin.toDouble(),
                        max: sliderMax.toDouble(),
                        divisions: sliderMax - _kMonthsIntervalMin,
                        label: '$_monthsForSlider',
                        onChanged: (v) {
                          final mo = v.round().clamp(_kMonthsIntervalMin, _kMonthsIntervalMax);
                          final t = '$mo';
                          if (_monthsCtrl.text != t) {
                            _monthsCtrl.value = TextEditingValue(
                              text: t,
                              selection: TextSelection.collapsed(offset: t.length),
                            );
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2),
              SizedBox(
                width: 62,
                child: TextField(
                  controller: _monthsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    suffixText: l10n.monthsBetween,
                    suffixStyle: TextStyle(fontSize: 11, color: pal.textSecondary),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(
              l10n.maintIntervalMonthsHelper,
              style: TextStyle(fontSize: 12, height: 1.3, color: pal.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete, required this.l10n});

  final MaintenanceRecord record;
  final VoidCallback onDelete;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy', l10n.locale.languageCode);
    final sep = NumberFormat.decimalPattern(l10n.intlLocale);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sep.format(record.odometerKm)} ${l10n.kmUnit} · ${df.format(record.date)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
                ),
                if (record.place != null && record.place!.isNotEmpty)
                  Text(record.place!, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                if (record.priceKopecks != null && record.priceKopecks! > 0)
                  Text(
                    Formatters.money(record.priceKopecks!),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
                  ),
                if (record.orderId != null)
                  Text(l10n.fromOrder, style: TextStyle(fontSize: 11, color: context.palette.textSecondary.withValues(alpha: 0.85))),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: context.palette.textSecondary),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.palette.cardBg,
                  title: Text(l10n.deleteRecordTitle, style: TextStyle(color: context.palette.textPrimary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.delete, style: TextStyle(color: context.palette.error)),
                    ),
                  ],
                ),
              );
              if (ok == true) onDelete();
            },
          ),
        ],
      ),
    );
  }
}
