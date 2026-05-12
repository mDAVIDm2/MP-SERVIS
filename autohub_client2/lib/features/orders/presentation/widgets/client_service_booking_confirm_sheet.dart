import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/availability/availability_helper.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/repositories/sto_repository.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/organization_ui_copy.dart';

/// Нижний лист: подтверждение записи, оформленной сервисом (услуги, время, сетка слотов).
Future<void> showClientServiceBookingConfirmSheet(
  BuildContext context,
  WidgetRef ref,
  Order order, {
  VoidCallback? onSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return ClientServiceBookingConfirmSheet(
        order: order,
        hostContext: context,
        onSuccess: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
          onSuccess?.call();
        },
      );
    },
  );
}

class ClientServiceBookingConfirmSheet extends ConsumerStatefulWidget {
  const ClientServiceBookingConfirmSheet({
    super.key,
    required this.order,
    required this.hostContext,
    this.onSuccess,
  });

  final Order order;
  final BuildContext hostContext;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<ClientServiceBookingConfirmSheet> createState() =>
      _ClientServiceBookingConfirmSheetState();
}

class _ClientServiceBookingConfirmSheetState extends ConsumerState<ClientServiceBookingConfirmSheet> {
  late Set<String> _selectedItemIds;
  bool _submitting = false;

  /// Выбранное в сетке время (после «Применить»). null — оставляем предложенное сервисом.
  DateTime? _appliedSlotStart;
  bool _otherTimeOpen = false;
  bool _pickerInited = false;
  late DateTime _pickerDate;
  int _slotIndex = 0;
  AvailableSlotsResult? _slots;
  bool _loadingSlots = false;

  List<OrderItem> get _lineItems {
    final src = widget.order.itemsForDisplay;
    final main = src.where((i) => !i.isAdditional && !i.isRejected).toList();
    if (main.isNotEmpty) return main;
    return src.where((i) => !i.isRejected).toList();
  }

  List<OrderItem> get _selectedLines =>
      _lineItems.where((i) => i.id.isEmpty || _selectedItemIds.contains(i.id)).toList();

  int get _selMinutes {
    // Фактические минуты по строкам заказа (30), а не стандарт прайса (120) — в т.ч. для полосы «заказ» в сетке.
    var m = _selectedLines
        .where((i) => !i.isRejected)
        .fold(0, (a, i) => a + i.estimatedMinutes);
    if (m <= 0) m = widget.order.items.where((i) => !i.isRejected).fold(0, (a, i) => a + i.estimatedMinutes);
    if (m <= 0) m = widget.order.estimatedMinutesForDisplay;
    return m.clamp(15, 24 * 60);
  }

  int get _selKopecks => _selectedLines
      .where((i) => !i.isRejected)
      .fold(0, (a, i) => a + i.priceKopecks);

  @override
  void initState() {
    super.initState();
    _selectedItemIds = {
      for (final i in _lineItems)
        if (i.id.isNotEmpty) i.id,
    };
    final raw = widget.order.plannedStartTime ?? widget.order.dateTime;
    final t = orderStartWallClock(raw) ?? raw;
    _pickerDate = DateTime(t.year, t.month, t.day);
  }

  List<String> get _serviceIdsForSlots {
    final fromSel = _selectedLines
        .map((i) => i.serviceId)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (fromSel.isNotEmpty) return fromSel;
    return widget.order.items
        .map((i) => i.serviceId)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _openOtherTime() {
    if (!_pickerInited) {
      _pickerInited = true;
      _slotIndex = 0;
    }
    setState(() {
      _otherTimeOpen = true;
    });
    _loadPickerSlots();
  }

  void _dayDelta(int d) {
    if (_loadingSlots) return;
    final next = _pickerDate.add(Duration(days: d));
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    if (next.isBefore(startOfToday)) return;
    setState(() {
      _pickerDate = next;
    });
    _loadPickerSlots();
  }

  Future<void> _loadPickerSlots() async {
    if (!_otherTimeOpen) return;
    setState(() {
      _loadingSlots = true;
      _slots = null;
    });
    final repo = ref.read(stoRepositoryProvider);
    final fromOrder = <SlotAvailabilityItem>[];
    for (final i in _selectedLines) {
      if (i.isRejected) continue;
      final sid = i.serviceId?.trim();
      fromOrder.add(SlotAvailabilityItem(
        estimatedMinutes: i.estimatedMinutes.clamp(1, 24 * 60),
        serviceId: sid != null && sid.isNotEmpty ? sid : null,
      ));
    }
    final result = await repo.getAvailableSlots(
      widget.order.stoId,
      _pickerDate,
      _serviceIdsForSlots,
      items: fromOrder.isNotEmpty ? fromOrder : null,
    );
    if (!mounted) return;
    result.when(
      success: (res) {
        final labels = _slotLabels(res);
        final available = res.startTimes;
        setState(() {
          _slots = res;
          _loadingSlots = false;
          _alignSlotToOrder(available, labels, res);
        });
      },
      failure: (_) {
        setState(() {
          _slots = const AvailableSlotsResult(startTimes: [], slotChoices: []);
          _loadingSlots = false;
        });
      },
    );
  }

  List<String> _slotLabels(AvailableSlotsResult? r) {
    if (r == null) {
      return buildDaySlotLabels();
    }
    return buildDaySlotLabels(
      slotDurationMinutes: r.slotDurationMinutes,
      workStartMinutes: r.workStartMinutes,
      workEndMinutes: r.workEndMinutes,
    );
  }

  void _alignSlotToOrder(List<String> available, List<String> labels, AvailableSlotsResult res) {
    if (labels.isEmpty) {
      _slotIndex = 0;
      return;
    }
    Order? o;
    for (final x in ref.read(ordersProvider).valueOrNull ?? <Order>[]) {
      if (x.id == widget.order.id) {
        o = x;
        break;
      }
    }
    if (o == null) {
      _adjustToFirstFree(available, labels);
      return;
    }
    final start = orderStartWallClock(o.plannedStartTime ?? o.dateTime);
    if (start == null || !Formatters.isSameCalendarDay(start, _pickerDate)) {
      _adjustToFirstFree(available, labels);
      return;
    }
    final label =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final idx = labels.indexOf(label);
    if (idx >= 0 && available.contains(label) && !Formatters.isBookingSlotStartInPastOrNow(_pickerDate, label)) {
      _slotIndex = idx;
    } else {
      _adjustToFirstFree(available, labels);
    }
  }

  void _adjustToFirstFree(List<String> available, List<String> labels) {
    for (var i = 0; i < labels.length; i++) {
      final s = labels[i];
      if (available.contains(s) && !Formatters.isBookingSlotStartInPastOrNow(_pickerDate, s)) {
        _slotIndex = i;
        return;
      }
    }
    _slotIndex = 0;
  }

  DateTime? get _draftStart {
    if (_slots == null) return null;
    final labels = _slotLabels(_slots);
    if (labels.isEmpty || _slotIndex < 0 || _slotIndex >= labels.length) return null;
    final slot = labels[_slotIndex];
    final st = _slots!.startTimes;
    if (st.isEmpty || !st.contains(slot)) return null;
    final p = slot.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    return DateTime(_pickerDate.year, _pickerDate.month, _pickerDate.day, h, m);
  }

  bool get _canApplySlot {
    if (_loadingSlots || _slots == null) return false;
    return _draftStart != null;
  }

  void _applySlot() {
    final t = _draftStart;
    if (t == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _appliedSlotStart = t;
    });
  }

  String get _proposedTimeLabel {
    final o = widget.order;
    if (o.plannedStartTime != null && o.plannedEndTime != null) {
      return '${Formatters.dateShortRu(o.plannedStartTime!)} ${Formatters.time(o.plannedStartTime!)} — ${Formatters.time(o.plannedEndTime!)}';
    }
    if (o.plannedStartTime != null) {
      return '${Formatters.dateShortRu(o.plannedStartTime!)} ${Formatters.time(o.plannedStartTime!)}';
    }
    return '${Formatters.dateShortRu(o.dateTime)} ${Formatters.time(o.dateTime)}';
  }

  String get _activeTimeLabel {
    if (_appliedSlotStart == null) return _proposedTimeLabel;
    final t = _appliedSlotStart!;
    final end = t.add(Duration(minutes: _selMinutes));
    return '${Formatters.dateShortRu(t)} ${Formatters.time(t)} — ${Formatters.time(end)}';
  }

  Future<void> _submit() async {
    if (_lineItems.isNotEmpty && _selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Отметьте хотя бы одну услугу'),
          backgroundColor: context.palette.warning,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    final orderId = widget.order.id;
    final withIds = _lineItems.where((i) => i.id.isNotEmpty).toList();
    List<String>? approvedItemIds;
    List<String>? rejectedItemIds;
    if (withIds.isNotEmpty) {
      final all = withIds.map((e) => e.id).toSet();
      final approved = _selectedItemIds.intersection(all).toList();
      final rejected = all.difference(_selectedItemIds).toList();
      approvedItemIds = approved;
      rejectedItemIds = rejected.isNotEmpty ? rejected : null;
    }
    // Один POST /confirm: снятие позиций + смена слота (сервер сопоставит время с предложением).
    final cr = _appliedSlotStart != null
        ? await ref.read(ordersProvider.notifier).confirmOrder(
              orderId,
              dateTime: _appliedSlotStart!,
              acceptProposed: true,
              approvedItemIds: approvedItemIds,
              rejectedItemIds: rejectedItemIds,
            )
        : await ref.read(ordersProvider.notifier).confirmOrder(
              orderId,
              acceptProposed: true,
              approvedItemIds: approvedItemIds,
              rejectedItemIds: rejectedItemIds,
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    final l = L10nScope.of(context);
    if (cr.errorOrNull == null) {
      await ref.read(ordersProvider.notifier).loadOrders();
      if (!mounted) return;
      ref.invalidate(orderByIdProvider(orderId));
      HapticFeedback.heavyImpact();
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.orderBookingConfirmedToast),
          backgroundColor: context.palette.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cr.errorOrNull!.message),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final o = widget.order;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final labels = _slotLabels(_slots);
    final available = _slots?.startTimes ?? const <String>[];
    final slotDur = _slots?.slotDurationMinutes ?? defaultSlotMinutes;
    final jobDur = _selMinutes;
    final busyRanges = <BusyRange>[];
    final jobStart = _draftStart;

    return Material(
      color: p.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.textTertiary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.event_available_rounded, color: p.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Запись от сервиса',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          o.stoName,
                          style: TextStyle(
                            fontSize: 14,
                            color: p.textSecondary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (o.carInfo != null && o.carInfo!.trim().isNotEmpty) ...[
                      Text(
                        o.carInfo!.trim(),
                        style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.3),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      'Услуги в записи',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Снимите отметку, если позицию уточните в чате.',
                      style: TextStyle(fontSize: 12, color: p.textTertiary, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    if (_lineItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Состав уточняется в чате с сервисом.',
                          style: TextStyle(fontSize: 14, color: p.textSecondary),
                        ),
                      )
                    else
                      ..._lineItems.map((item) {
                        final hasId = item.id.isNotEmpty;
                        final checked = !hasId || _selectedItemIds.contains(item.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: p.nestedBg,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: hasId
                                  ? () {
                                      setState(() {
                                        if (_selectedItemIds.contains(item.id)) {
                                          _selectedItemIds.remove(item.id);
                                        } else {
                                          _selectedItemIds.add(item.id);
                                        }
                                      });
                                      if (_otherTimeOpen) _loadPickerSlots();
                                      HapticFeedback.selectionClick();
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: hasId
                                          ? Checkbox(
                                              value: checked,
                                              onChanged: (v) {
                                                if (v == true) {
                                                  if (!_selectedItemIds.contains(item.id)) {
                                                    setState(() => _selectedItemIds.add(item.id));
                                                  }
                                                } else {
                                                  if (_selectedItemIds.contains(item.id)) {
                                                    setState(() => _selectedItemIds.remove(item.id));
                                                  }
                                                }
                                                if (_otherTimeOpen) _loadPickerSlots();
                                                HapticFeedback.selectionClick();
                                              },
                                              activeColor: p.primary,
                                            )
                                          : Icon(Icons.info_outline_rounded, size: 20, color: p.textTertiary),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: p.textPrimary,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${Formatters.money(item.priceKopecks)} · ${item.durationLabel}',
                                            style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.2),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    if (_lineItems.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.nestedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Сумма и длительность',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.textTertiary,
                              ),
                            ),
                            Text(
                              '${Formatters.money(_selKopecks)} · ${Formatters.durationMinutes(_selMinutes)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('Время записи', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: p.textSecondary, letterSpacing: 0.2,
                    )),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: p.nestedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 20, color: p.primary.withValues(alpha: 0.9)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _activeTimeLabel,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_appliedSlotStart != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'После нажатия «Подтвердить внизу» запись будет согласована с выбранным составом и временем.',
                        style: TextStyle(fontSize: 12, color: p.textTertiary, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!_otherTimeOpen) ...[
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                _openOtherTime();
                              },
                        icon: Icon(Icons.edit_calendar_outlined, size: 18, color: p.primary),
                        label: const Text('Указать другое время', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  setState(() {
                                    _otherTimeOpen = false;
                                    _slots = null;
                                    _loadingSlots = false;
                                  });
                                },
                          child: const Text('Оставить время как предложено сервисом'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Другое время',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _loadingSlots
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    _dayDelta(-1);
                                  },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                Formatters.dateFullRu(_pickerDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _loadingSlots
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    _dayDelta(1);
                                  },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      if (_loadingSlots) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text('Загрузка слотов…', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                          ],
                        ),
                      ] else if (available.isEmpty && labels.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Нет доступных слотов на эту дату',
                          style: TextStyle(fontSize: 14, color: p.textSecondary),
                        ),
                        Text(OrganizationUiCopy.approvalEmptySlotsHint(), style: TextStyle(fontSize: 13, color: p.textTertiary)),
                      ],
                      if (!_loadingSlots && labels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(labels.length, (i) {
                            final slot = labels[i];
                            final isSelected = i == _slotIndex;
                            final isOccupied = isSlotOccupied(
                              slot,
                              busyRanges,
                              slotDurationMinutes: slotDur,
                            );
                            final isAvailable = available.contains(slot);
                            final isPast = Formatters.isBookingSlotStartInPastOrNow(_pickerDate, slot);
                            final isDisabled = !isAvailable || isPast;
                            final isStart = isSelected && isAvailable && !isPast;
                            final isContinuation = !isPast &&
                                jobStart != null &&
                                slotIsJobContinuation(
                                  slot,
                                  jobStart,
                                  _pickerDate,
                                  jobDur,
                                );
                            late final Color slotBg;
                            late final Color slotBorder;
                            late final Color slotText;
                            if (isPast) {
                              slotBg = p.textTertiary.withValues(alpha: 0.2);
                              slotBorder = p.border;
                              slotText = p.textTertiary;
                            } else if (isStart) {
                              slotBg = p.primary;
                              slotBorder = p.primary;
                              slotText = p.onAccent;
                            } else if (isContinuation) {
                              if (isAvailable) {
                                slotBg = p.success.withValues(alpha: 0.2);
                                slotBorder = p.success;
                                slotText = p.success;
                              } else if (isOccupied) {
                                slotBg = p.error.withValues(alpha: 0.25);
                                slotBorder = p.error;
                                slotText = p.error;
                              } else {
                                slotBg = p.nestedBg;
                                slotBorder = p.border;
                                slotText = p.textTertiary;
                              }
                            } else if (isAvailable) {
                              slotBg = p.success.withValues(alpha: 0.2);
                              slotBorder = p.success;
                              slotText = p.success;
                            } else if (isOccupied) {
                              slotBg = p.error.withValues(alpha: 0.25);
                              slotBorder = p.error;
                              slotText = p.error;
                            } else {
                              slotBg = p.warning.withValues(alpha: 0.14);
                              slotBorder = p.warning.withValues(alpha: 0.45);
                              slotText = p.warning;
                            }
                            final showVisitStrip = isContinuation;
                            return GestureDetector(
                              onTap: isDisabled
                                  ? null
                                  : () {
                                      setState(() => _slotIndex = i);
                                      HapticFeedback.selectionClick();
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 72,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: slotBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: slotBorder, width: 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (showVisitStrip)
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: p.gold2,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.only(top: showVisitStrip ? 2 : 0),
                                        child: Text(
                                          slot,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: slotText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: (!_canApplySlot || _submitting) ? null : _applySlot,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Применить выбранное время'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Выбранное время отобразится в поле «Время записи» выше. Затем нажмите «Подтвердить» внизу листа.',
                          style: TextStyle(fontSize: 11, color: p.textTertiary, height: 1.3),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: p.cardBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onAccent,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Подтвердить',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: p.onAccent,
                            ),
                            maxLines: 1,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
