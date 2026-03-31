import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../shared/models/car_model.dart';

/// Полная карточка напоминания: интервалы, три блока «было / осталось / потребуется», история, запись вручную.
class MaintenanceReminderDetailScreen extends ConsumerWidget {
  const MaintenanceReminderDetailScreen({
    super.key,
    required this.car,
    required this.type,
  });

  final Car car;
  final MaintenanceType type;

  static String _emoji(MaintenanceType t) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(maintenanceRemindersProvider);
    final notifier = ref.read(maintenanceRemindersProvider.notifier);
    final config = notifier.getConfig(car.id, type.name);
    final records = notifier.getRecords(car.id, type.name);
    final snap = notifier.computeDue(car.id, type.name, car.mileage);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          type.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SummaryCard(
            car: car,
            type: type,
            config: config,
            snap: snap,
          ),
          if (config != null) ...[
            const SizedBox(height: 16),
            _IntervalsCard(
              car: car,
              type: type,
              config: config,
              notifier: notifier,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'История замен',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary.withValues(alpha: 0.95),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: config == null
                    ? null
                    : () => _openAddRecord(context, ref, car, type, config),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Пока нет записей. Добавьте вручную или они появятся из завершённых заказов в автосервисе, на шиномонтаже или в сервисе электромобилей.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            )
          else
            ...records.map(
              (r) => _RecordTile(
                record: r,
                onDelete: () {
                  notifier.removeRecord(r.id);
                },
              ),
            ),
          if (config != null) ...[
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => _confirmRemoveReminder(context, ref, car.id, type.name),
                child: const Text(
                  'Убрать напоминание из списка',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _confirmRemoveReminder(
    BuildContext context,
    WidgetRef ref,
    String carId,
    String typeKey,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Убрать напоминание?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Настройки интервалов будут удалены. История замен сохранится.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Убрать', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ref.read(maintenanceRemindersProvider.notifier).deleteConfig(carId, typeKey);
      Navigator.pop(context);
    }
  }

  static void _openAddRecord(
    BuildContext context,
    WidgetRef ref,
    Car car,
    MaintenanceType type,
    MaintenanceConfig config,
  ) {
    final kmController = TextEditingController(text: '${car.mileage}');
    final placeController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Новая запись', style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Пробег (км)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Например 65 000'),
            ),
            const SizedBox(height: 12),
            const Text('Место (сервис)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            TextField(
              controller: placeController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Необязательно'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              final km = int.tryParse(kmController.text.replaceAll(' ', '').trim());
              if (km != null && km >= 0) {
                ref.read(maintenanceRemindersProvider.notifier).addRecord(
                      MaintenanceRecord(
                        id: 'man_${DateTime.now().millisecondsSinceEpoch}',
                        carId: car.id,
                        typeKey: type.name,
                        odometerKm: km,
                        date: DateTime.now(),
                        place: placeController.text.trim().isEmpty ? null : placeController.text.trim(),
                      ),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить', style: TextStyle(color: AppColors.primary)),
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
  });

  final Car car;
  final MaintenanceType type;
  final MaintenanceConfig? config;
  final MaintenanceDueSnapshot snap;

  static final _df = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    if (config == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Напоминание не добавлено. Вернитесь назад и выберите услугу в списке.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35),
        ),
      );
    }

    final cfg = config!;
    final last = snap.lastRecord;
    final kmLine = cfg.useKmInterval && cfg.intervalKm > 0;
    final moLine = cfg.useMonthsInterval && cfg.intervalMonths > 0;

    String fmtKm(int? k) {
      if (k == null) return '—';
      final sep = NumberFormat.decimalPattern('ru_RU');
      return '${sep.format(k)} км';
    }

    String fmtDays(int? d) {
      if (d == null) return '—';
      if (d < 0) return 'просрочено на ${-d} дн.';
      return '≈ $d дн.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
              Text(MaintenanceReminderDetailScreen._emoji(type), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      car.displayName,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _line(
            'Последняя замена',
            last != null ? '${fmtKm(last.odometerKm)} · ${_df.format(last.date)}' : 'Нет данных — добавьте запись',
            AppColors.textPrimary,
          ),
          const SizedBox(height: 12),
          _line(
            'Осталось',
            last == null
                ? '—'
                : [
                    if (kmLine && snap.kmRemaining != null) fmtKm(snap.kmRemaining),
                    if (moLine && snap.daysRemaining != null) fmtDays(snap.daysRemaining),
                  ].where((s) => s != '—').join(' · ').orDashIfEmpty(),
            snap.overdue ? AppColors.error : AppColors.textPrimary,
          ),
          const SizedBox(height: 12),
          _line(
            'Следующая замена',
            last == null
                ? '—'
                : [
                    if (kmLine && snap.nextDueKm != null) 'на ${fmtKm(snap.nextDueKm)}',
                    if (moLine && snap.nextDueDate != null) 'до ${_df.format(snap.nextDueDate!)}',
                  ].join(' · ').orDashIfEmpty(),
            snap.overdue ? AppColors.error : AppColors.primary,
          ),
          if (snap.overdue) ...[
            const SizedBox(height: 10),
            Text(
              snap.overdueByKm && snap.overdueByDate
                  ? 'Просрочено по пробегу и по сроку'
                  : snap.overdueByKm
                      ? 'Просрочено по пробегу'
                      : 'Просрочено по сроку',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor, height: 1.25)),
      ],
    );
  }
}

extension _StrOr on String {
  String orDashIfEmpty() => isEmpty ? '—' : this;
}

class _IntervalsCard extends StatefulWidget {
  const _IntervalsCard({
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
    _kmCtrl = TextEditingController(text: '${widget.config.intervalKm}');
    _monthsCtrl = TextEditingController(text: widget.config.intervalMonths > 0 ? '${widget.config.intervalMonths}' : '12');
  }

  @override
  void didUpdateWidget(covariant _IntervalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.intervalKm != widget.config.intervalKm) {
      _kmCtrl.text = '${widget.config.intervalKm}';
    }
    if (oldWidget.config.intervalMonths != widget.config.intervalMonths) {
      _monthsCtrl.text = widget.config.intervalMonths > 0 ? '${widget.config.intervalMonths}' : '12';
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

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Настройка напоминания',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Напоминание включено'),
            subtitle: const Text('При выключении расчёты сохраняются', style: TextStyle(fontSize: 12)),
            value: c.remindEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => widget.notifier.setRemindEnabled(widget.car.id, widget.type.name, v),
          ),
          if (!c.remindEnabled) ...[
            const SizedBox(height: 4),
            const Text(
              'Включите напоминание, чтобы получать расчёт срока и пробега.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            ),
          ],
          if (c.remindEnabled) ...[
            const SizedBox(height: 2),
            const Text(
              'Можно использовать пробег, срок или оба критерия. Сработает то, что наступит раньше.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
            _intervalBlock(
              title: 'Интервал по пробегу',
              enabled: c.useKmInterval,
              currentValueLabel: 'Каждые ${_kmCtrl.text} км',
              onToggle: (v) => setState(() => _savePartial(useKm: v)),
              field: TextField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Километров между заменами',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              onApply: () {
                final n = int.tryParse(_kmCtrl.text.trim());
                if (n != null && n > 0) _savePartial(intervalKm: n);
              },
            ),
            const SizedBox(height: 10),
            _intervalBlock(
              title: 'Интервал по времени',
              enabled: c.useMonthsInterval,
              currentValueLabel: 'Раз в ${_monthsCtrl.text} мес.',
              onToggle: (v) => setState(() => _savePartial(useMonths: v)),
              field: TextField(
                controller: _monthsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Месяцев между заменами',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              onApply: () {
                final n = int.tryParse(_monthsCtrl.text.trim());
                if (n != null && n > 0) _savePartial(intervalMonths: n);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _intervalBlock({
    required String title,
    required bool enabled,
    required String currentValueLabel,
    required ValueChanged<bool> onToggle,
    required Widget field,
    required VoidCallback onApply,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(currentValueLabel, style: const TextStyle(fontSize: 12)),
            value: enabled,
            activeThumbColor: AppColors.primary,
            onChanged: onToggle,
          ),
          if (enabled) ...[
            field,
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onApply,
                child: const Text('Применить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete});

  final MaintenanceRecord record;
  final VoidCallback onDelete;

  static final _df = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${NumberFormat.decimalPattern('ru_RU').format(record.odometerKm)} км · ${_df.format(record.date)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                if (record.place != null && record.place!.isNotEmpty)
                  Text(record.place!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (record.orderId != null)
                  Text('Из заказа', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.85))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.cardBg,
                  title: const Text('Удалить запись?', style: TextStyle(color: AppColors.textPrimary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
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
