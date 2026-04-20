import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/availability/availability_helper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/repositories/sto_repository.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/organization_ui_copy.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Экран выбора даты и слота. Режимы: [onTimeSelected] — только вернуть время (draft, без API); [onConfirmed] — сразу отправить confirm.
class ApprovalSlotPickerScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String stoId;
  final List<String> serviceIds;
  /// Если задан — кнопка «Подтвердить» только возвращает выбранное время (draft), без вызова API.
  final void Function(DateTime dateTime)? onTimeSelected;
  /// Если задан и onTimeSelected == null — при подтверждении вызывается API confirmOrder, затем callback.
  final Future<void> Function(DateTime dateTime)? onConfirmed;

  const ApprovalSlotPickerScreen({
    super.key,
    required this.orderId,
    required this.stoId,
    this.serviceIds = const [],
    this.onTimeSelected,
    this.onConfirmed,
  });

  @override
  ConsumerState<ApprovalSlotPickerScreen> createState() => _ApprovalSlotPickerScreenState();
}

class _ApprovalSlotPickerScreenState extends ConsumerState<ApprovalSlotPickerScreen> {
  late DateTime _selectedDate;
  int _selectedTimeSlotIndex = 0;
  AvailableSlotsResult? _slotsResult;
  bool _isSubmitting = false;

  Order? _orderFromList(List<Order> orders) {
    try {
      return orders.firstWhere((o) => o.id == widget.orderId);
    } catch (_) {
      return null;
    }
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

  int get _jobDurationMinutes {
    final fromApi = _slotsResult?.totalMinutes ?? 0;
    if (fromApi > 0) return fromApi;
    final o = _orderFromList(ref.read(ordersProvider).valueOrNull ?? []);
    if (o == null) return 60;
    return o.items.fold<int>(0, (s, i) => s + i.estimatedMinutes).clamp(15, 24 * 60);
  }

  DateTime? get _draftJobStart {
    final labels = _slotLabels(_slotsResult);
    if (labels.isEmpty || _selectedTimeSlotIndex < 0 || _selectedTimeSlotIndex >= labels.length) return null;
    final slot = labels[_selectedTimeSlotIndex];
    final parts = slot.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
  }

  bool get _canConfirm {
    final starts = _slotsResult?.startTimes ?? [];
    if (starts.isEmpty) return false;
    final labels = _slotLabels(_slotsResult);
    if (_selectedTimeSlotIndex < 0 || _selectedTimeSlotIndex >= labels.length) return false;
    final selected = labels[_selectedTimeSlotIndex];
    return starts.contains(selected);
  }

  @override
  void initState() {
    super.initState();
    final orders = ref.read(ordersProvider).valueOrNull ?? [];
    final ord = _orderFromList(orders);
    if (ord != null) {
      final raw = ord.plannedStartTime ?? ord.dateTime;
      final start = orderStartWallClock(raw) ?? raw;
      _selectedDate = DateTime(start.year, start.month, start.day);
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    }
    _loadSlots();
  }

  void _pickIndexForOrder(List<String> labels, List<String> available, Order? ord) {
    if (ord == null) {
      _adjustSelectedAfterLoad(labels, available);
      return;
    }
    final start = orderStartWallClock(ord.plannedStartTime ?? ord.dateTime);
    if (start == null || !Formatters.isSameCalendarDay(start, _selectedDate)) {
      _adjustSelectedAfterLoad(labels, available);
      return;
    }
    final label =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final idx = labels.indexOf(label);
    if (idx >= 0 && available.contains(label)) {
      _selectedTimeSlotIndex = idx;
    } else {
      _adjustSelectedAfterLoad(labels, available);
    }
  }

  void _adjustSelectedAfterLoad(List<String> labels, List<String> available) {
    if (labels.isEmpty) {
      _selectedTimeSlotIndex = 0;
      return;
    }
    final current =
        _selectedTimeSlotIndex >= 0 && _selectedTimeSlotIndex < labels.length ? labels[_selectedTimeSlotIndex] : null;
    if (current != null && available.contains(current)) {
      if (!Formatters.isBookingSlotStartInPastOrNow(_selectedDate, current)) return;
    }
    for (var i = 0; i < labels.length; i++) {
      final s = labels[i];
      if (available.contains(s) && !Formatters.isBookingSlotStartInPastOrNow(_selectedDate, s)) {
        _selectedTimeSlotIndex = i;
        return;
      }
    }
    _selectedTimeSlotIndex = 0;
  }

  Future<void> _loadSlots() async {
    setState(() => _slotsResult = null);
    final repo = ref.read(stoRepositoryProvider);
    final result = await repo.getAvailableSlots(
      widget.stoId,
      _selectedDate,
      widget.serviceIds,
    );
    if (!mounted) return;
    result.when(
      success: (res) {
        final labels = _slotLabels(res);
        final starts = res.startTimes;
        final ord = _orderFromList(ref.read(ordersProvider).valueOrNull ?? []);
        setState(() {
          _slotsResult = res;
          _pickIndexForOrder(labels, starts, ord);
        });
      },
      failure: (_) => setState(() => _slotsResult = const AvailableSlotsResult(startTimes: [], slotChoices: [])),
    );
  }

  /// Подтвердить: либо только вернуть время (draft), либо отправить confirmOrder.
  Future<void> _confirmWithTime(DateTime chosen) async {
    if (_isSubmitting) return;
    if (widget.onTimeSelected != null) {
      widget.onTimeSelected!(chosen);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = true);
    final result = await ref.read(ordersProvider.notifier).confirmOrder(
          widget.orderId,
          dateTime: chosen,
          acceptProposed: false,
        );
    if (!mounted) return;
    if (result.errorOrNull == null) {
      await ref.read(notificationsProvider.notifier).markReadByOrderId(widget.orderId);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(unreadByCarProvider);
      await widget.onConfirmed?.call(chosen);
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.errorOrNull?.message ?? 'Не удалось подтвердить запись'),
        backgroundColor: context.palette.error,
      ));
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm || _isSubmitting) return;
    final labels = _slotLabels(_slotsResult);
    final timeStr = labels[_selectedTimeSlotIndex];
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    final chosen = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );
    await _confirmWithTime(chosen);
  }

  /// Подтвердить запись на выбранную дату без слота (время — начало рабочего дня из сетки).
  Future<void> _confirmDateOnly() async {
    if (_isSubmitting) return;
    final r = _slotsResult;
    final startMin = r?.workStartMinutes ?? 9 * 60;
    final chosen = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      startMin ~/ 60,
      startMin % 60,
    );
    await _confirmWithTime(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final available = _slotsResult?.startTimes ?? [];
    final loading = _slotsResult == null;
    final labels = _slotLabels(_slotsResult);
    final busyRanges = <BusyRange>[];
    final jobStart = _draftJobStart;
    final jobDur = _jobDurationMinutes;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('Выбор времени', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Выберите дату и удобное время', style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && date != _selectedDate && mounted) {
                        setState(() => _selectedDate = date);
                        _loadSlots();
                      }
                    },
                    icon: Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(Formatters.dateFullRu(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.textPrimary,
                      side: BorderSide(color: context.palette.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: loading
                ? Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary)),
                      SizedBox(width: 8),
                      Text('Загрузка слотов...', style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                    ],
                  )
                : Text(
                    available.isNotEmpty && labels.isNotEmpty
                        ? 'Время: ${labels[_selectedTimeSlotIndex.clamp(0, labels.length > 1 ? labels.length - 1 : 0)]}'
                        : 'Нет доступных слотов на эту дату',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: available.isNotEmpty ? context.palette.textPrimary : context.palette.textSecondary,
                    ),
                  ),
          ),
          if (!loading && available.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                OrganizationUiCopy.approvalEmptySlotsHint(),
                style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
              ),
            ),
            SizedBox(height: 8),
          ],
          SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(labels.length, (i) {
                  final slot = labels[i];
                  final isSelected = i == _selectedTimeSlotIndex;
                  final slotDur = _slotsResult?.slotDurationMinutes ?? defaultSlotMinutes;
                  final isOccupied = isSlotOccupied(slot, busyRanges, slotDurationMinutes: slotDur);
                  final isAvailable = available.contains(slot);
                  final isDisabled = loading || !isAvailable;
                  final isStart = isSelected && isAvailable;
                  final isContinuation = jobStart != null &&
                      slotIsJobContinuation(slot, jobStart, _selectedDate, jobDur);

                  late final Color slotBg;
                  late final Color slotBorder;
                  late final Color slotText;

                  if (isStart) {
                    slotBg = context.palette.primary;
                    slotBorder = context.palette.primary;
                    slotText = context.palette.onAccent;
                  } else if (isContinuation) {
                    if (isAvailable) {
                      slotBg = context.palette.success.withValues(alpha: 0.2);
                      slotBorder = context.palette.success;
                      slotText = context.palette.success;
                    } else if (isOccupied) {
                      slotBg = context.palette.error.withValues(alpha: 0.25);
                      slotBorder = context.palette.error;
                      slotText = context.palette.error;
                    } else {
                      slotBg = context.palette.nestedBg;
                      slotBorder = context.palette.border;
                      slotText = context.palette.textTertiary;
                    }
                  } else if (isAvailable) {
                    slotBg = context.palette.success.withValues(alpha: 0.2);
                    slotBorder = context.palette.success;
                    slotText = context.palette.success;
                  } else if (isOccupied) {
                    slotBg = context.palette.error.withValues(alpha: 0.25);
                    slotBorder = context.palette.error;
                    slotText = context.palette.error;
                  } else {
                    slotBg = context.palette.nestedBg;
                    slotBorder = context.palette.border;
                    slotText = context.palette.textTertiary;
                  }

                  final showVisitStrip = isContinuation;

                  return GestureDetector(
                    onTap: isDisabled ? null : () => setState(() => _selectedTimeSlotIndex = i),
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
                                  decoration: BoxDecoration(color: context.palette.gold2),
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
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoldButton(
                  text: _isSubmitting ? 'Подтверждение...' : 'Подтвердить запись',
                  onPressed: (_canConfirm && !_isSubmitting) ? _confirm : null,
                ),
                if (!loading && available.isEmpty && !_isSubmitting) ...[
                  SizedBox(height: 10),
                  TextButton(
                    onPressed: _confirmDateOnly,
                    child: Text(OrganizationUiCopy.approvalConfirmDate()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
