import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/utils/schedule_masters_filter.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../../core/utils/formatters.dart' show formatDate, formatTime, formatMoney;
import 'schedule_screen.dart';
import '../providers/schedule_board_provider.dart';

const double _kRowHeight = 64.0;
const double _kTimeColWidth = 56.0;
const double _kUnassignedColWidth = 200.0;
const double _kMasterColWidth = 248.0;

int _dayStartMinutes(SlotsSettings s) => s.startHour * 60 + s.startMinute;
int _dayEndMinutes(SlotsSettings s) => s.endHour * 60 + s.endMinute;
int _totalSlots(SlotsSettings s) => ((_dayEndMinutes(s) - _dayStartMinutes(s)) / 30).floor();
String _slotTime(int index, SlotsSettings s) {
  final m = _dayStartMinutes(s) + index * 30;
  final h = m ~/ 60;
  final min = m % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

/// Парсинг "HH:mm" в минуты от полуночи (для графика мастера).
int _timeToMinutes(String t) {
  final parts = t.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

/// Слот [slotIndex] входит в рабочие часы мастера в выбранный день.
bool _isSlotInMasterWorkRange(StaffEntry master, DateTime date, int slotIndex, SlotsSettings slots) {
  final dayOfWeek = date.weekday % 7;
  final scheduleSlot = master.schedule.where((s) => s.dayOfWeek == dayOfWeek).firstOrNull;
  if (scheduleSlot == null || !scheduleSlot.isWorkingDay) return false;
  final slotStartMinutes = _dayStartMinutes(slots) + slotIndex * 30;
  final masterStart = _timeToMinutes(scheduleSlot.startTime);
  final masterEnd = _timeToMinutes(scheduleSlot.endTime);
  return slotStartMinutes >= masterStart && slotStartMinutes < masterEnd;
}

String _masterInitials(StaffEntry m) {
  final parts = m.name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : parts[0].toUpperCase();
}

int _slotIndex(DateTime dt, SlotsSettings s) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  final minutes = local.hour * 60 + local.minute;
  final start = _dayStartMinutes(s);
  final total = _totalSlots(s);
  final slot = (minutes - start) ~/ 30;
  return slot.clamp(0, total - 1);
}

int _orderStartSlot(Order o, SlotsSettings s) {
  final start = o.plannedStartTime ?? o.effectiveDateTime;
  return _slotIndex(start, s);
}

DateTime _desktopOrderStartLocal(Order o) {
  final start = o.plannedStartTime ?? o.effectiveDateTime;
  return start.isUtc ? start.toLocal() : start;
}

DateTime _desktopOrderEndLocal(Order o) {
  final startLocal = _desktopOrderStartLocal(o);
  if (o.plannedEndTime != null) {
    final e = o.plannedEndTime!;
    return e.isUtc ? e.toLocal() : e;
  }
  var totalMin = o.items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
  if (totalMin <= 0) totalMin = 60;
  return startLocal.add(Duration(minutes: totalMin));
}

/// Сколько слотов по 30 мин занимает заказ (как в мобильном расписании): конец по верхней границе слота — 9:00–10:15 → 3 слота до 10:30.
int _orderSlotSpan(Order o, SlotsSettings s) {
  const slotMin = 30;
  final gridStartMin = _dayStartMinutes(s);
  final totalSlots = _totalSlots(s);
  if (totalSlots <= 0) return 1;

  final localStart = _desktopOrderStartLocal(o);
  final endLocal = _desktopOrderEndLocal(o);

  final startMinAbs = localStart.hour * 60 + localStart.minute;
  final endMinAbs = endLocal.hour * 60 + endLocal.minute;

  var startOffset = startMinAbs - gridStartMin;
  var endOffset = endMinAbs - gridStartMin;
  if (endOffset <= startOffset) endOffset = startOffset + slotMin;

  final startSlot = (startOffset ~/ slotMin).clamp(0, totalSlots - 1);
  final endSlotExclusive = ((endOffset + slotMin - 1) ~/ slotMin).clamp(startSlot + 1, totalSlots);
  var span = endSlotExclusive - startSlot;
  if (span < 1) span = 1;
  return span;
}

/// Строка диапазона времени заказа «10.00–12.30». Длительность из окна (plannedEnd−plannedStart) или из суммы услуг.
String _orderTimeRangeString(Order order) {
  final start = order.plannedStartTime ?? order.effectiveDateTime;
  final startLocal = start.isUtc ? start.toLocal() : start;
  int durationMin = order.estimatedMinutesForDisplay;
  if (order.plannedStartTime != null && order.plannedEndTime != null && durationMin <= 0) {
    durationMin = order.plannedEndTime!.difference(order.plannedStartTime!).inMinutes;
  }
  if (durationMin <= 0) durationMin = 60;
  final end = order.plannedEndTime ?? startLocal.add(Duration(minutes: durationMin));
  final endLocal = end.isUtc ? end.toLocal() : end;
  return '${formatTime(startLocal)}–${formatTime(endLocal)}';
}

/// Цвет фона карточки по статусу (ТЗ: мягкие тона, читаемый текст).
/// подтверждён — холодный голубой/синий; в работе — синий насыщеннее;
/// новый/нераспределённый — светло-оранжевый/бежевый; требует согласования — янтарный; проблемный — красноватый.
Color _cardBgForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendingConfirmation:
      return const Color(0xFFFFF7ED); // светло-оранжевый/бежевый — новый
    case OrderStatus.confirmed:
      return const Color(0xFFDBEAFE); // холодный голубой/синий
    case OrderStatus.inProgress:
      return const Color(0xFFBFDBFE); // синий насыщеннее — в работе
    case OrderStatus.pendingApproval:
      return const Color(0xFFFEF3C7); // мягкий янтарный
    case OrderStatus.completed:
      return const Color(0xFFD1FAE5); // зелёный
    case OrderStatus.done:
      return const Color(0xFFE5E7EB); // серый
    case OrderStatus.cancelled:
      return const Color(0xFFFEE2E2); // мягкий красноватый — проблемный
  }
}

Color _cardAccentForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendingConfirmation:
      return AppColorsDesktop.statusPending;
    case OrderStatus.confirmed:
      return AppColorsDesktop.statusConfirmed;
    case OrderStatus.inProgress:
      return AppColorsDesktop.statusInProgress;
    case OrderStatus.pendingApproval:
      return AppColorsDesktop.statusApproval;
    case OrderStatus.completed:
      return AppColorsDesktop.statusCompleted;
    case OrderStatus.done:
      return AppColorsDesktop.statusDone;
    case OrderStatus.cancelled:
      return AppColorsDesktop.statusCancelled;
  }
}

/// Цвет фона выделенной мини-карточки по статусу — сохраняем узнаваемый оттенок статуса.
Color _selectedCardBgForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendingConfirmation:
      return const Color(0xFFFFEDD5); // чуть ярче оранжевый
    case OrderStatus.confirmed:
      return const Color(0xFFC7E0FF); // чуть ярче голубой
    case OrderStatus.inProgress:
      return const Color(0xFFDBEAFE); // мягкий синий «в работе» (не насыщенный)
    case OrderStatus.pendingApproval:
      return const Color(0xFFFDE68A); // янтарный
    case OrderStatus.completed:
      return const Color(0xFFA7F3D0); // зелёный
    case OrderStatus.done:
      return const Color(0xFFD1D5DB); // серый
    case OrderStatus.cancelled:
      return const Color(0xFFFECACA); // красноватый
  }
}

/// Цвет рамки выделенной мини-карточки по статусу — тёмный оттенок того же цвета.
Color _selectedCardBorderForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendingConfirmation:
      return const Color(0xFFC2410C); // тёмно-оранжевый
    case OrderStatus.confirmed:
      return const Color(0xFF1D4ED8); // тёмно-синий
    case OrderStatus.inProgress:
      return const Color(0xFF1E40AF); // тёмно-синий в работе
    case OrderStatus.pendingApproval:
      return const Color(0xFFB45309); // тёмно-янтарный
    case OrderStatus.completed:
      return const Color(0xFF047857); // тёмно-зелёный
    case OrderStatus.done:
      return const Color(0xFF4B5563); // тёмно-серый
    case OrderStatus.cancelled:
      return const Color(0xFFB91C1C); // тёмно-красный
  }
}

/// Сетка расписания для desktop: время | нераспределённые | колонки всех мастеров, drag & drop.
class ScheduleDesktopGrid extends ConsumerStatefulWidget {
  const ScheduleDesktopGrid({
    super.key,
    required this.selectedDate,
    this.onDateChanged,
  });

  final DateTime selectedDate;
  final void Function(DateTime)? onDateChanged;

  @override
  ConsumerState<ScheduleDesktopGrid> createState() => _ScheduleDesktopGridState();
}

class _ScheduleDesktopGridState extends ConsumerState<ScheduleDesktopGrid> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalBodyScrollController = ScrollController();
  final ScrollController _horizontalHeaderScrollController = ScrollController();
  bool _syncingHorizontal = false;
  int _lastWheelTimeMs = 0;
  static const int _kWheelThrottleMs = 180;
  int _overscrollCount = 0;
  int _overscrollCountUp = 0;

  @override
  void initState() {
    super.initState();
    _horizontalBodyScrollController.addListener(_syncHeaderToBodyHorizontal);
    _horizontalHeaderScrollController.addListener(_syncBodyToHeaderHorizontal);
    _verticalScrollController.addListener(_onVerticalScroll);
  }

  void _onVerticalScroll() {
    if (!_verticalScrollController.hasClients) return;
    final max = _verticalScrollController.position.maxScrollExtent;
    final offset = _verticalScrollController.offset;
    if (offset < max - 30) _overscrollCount = 0;
    if (offset > 30) _overscrollCountUp = 0;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_verticalScrollController.hasClients) return false;
    final max = _verticalScrollController.position.maxScrollExtent;
    final offset = _verticalScrollController.offset;
    if (offset < max - 30) _overscrollCount = 0;
    if (offset > 30) _overscrollCountUp = 0;
    return false;
  }

  void _handleWheelAtBottom(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_verticalScrollController.hasClients) return;
    final max = _verticalScrollController.position.maxScrollExtent;
    final offset = _verticalScrollController.offset;
    final dy = event.scrollDelta.dy;

    if (dy > 0) {
      if (offset < max - 20) return;
      _overscrollCountUp = 0;
      _overscrollCount++;
      if (_overscrollCount >= 4 && widget.onDateChanged != null) {
        final next = widget.selectedDate.add(const Duration(days: 1));
        widget.onDateChanged!(next);
        _overscrollCount = 0;
        _verticalScrollController.jumpTo(0);
      }
    } else if (dy < 0) {
      if (offset > 20) return;
      _overscrollCount = 0;
      _overscrollCountUp++;
      if (_overscrollCountUp >= 4 && widget.onDateChanged != null) {
        final prev = widget.selectedDate.subtract(const Duration(days: 1));
        final pos = _verticalScrollController.position;
        widget.onDateChanged!(prev);
        _overscrollCountUp = 0;
        _verticalScrollController.jumpTo(pos.maxScrollExtent);
      }
    }
  }

  void _syncHeaderToBodyHorizontal() {
    if (_syncingHorizontal) return;
    final offset = _horizontalBodyScrollController.offset;
    if (_horizontalHeaderScrollController.hasClients &&
        (_horizontalHeaderScrollController.offset - offset).abs() > 2) {
      _syncingHorizontal = true;
      _horizontalHeaderScrollController.jumpTo(offset);
      _syncingHorizontal = false;
    }
  }

  void _syncBodyToHeaderHorizontal() {
    if (_syncingHorizontal) return;
    final offset = _horizontalHeaderScrollController.offset;
    if (_horizontalBodyScrollController.hasClients &&
        (_horizontalBodyScrollController.offset - offset).abs() > 2) {
      _syncingHorizontal = true;
      _horizontalBodyScrollController.jumpTo(offset);
      _syncingHorizontal = false;
    }
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_onVerticalScroll);
    _horizontalBodyScrollController.removeListener(_syncHeaderToBodyHorizontal);
    _horizontalHeaderScrollController.removeListener(_syncBodyToHeaderHorizontal);
    _verticalScrollController.dispose();
    _horizontalBodyScrollController.dispose();
    _horizontalHeaderScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) return const SizedBox.shrink();
    final orders = ref.watch(orderRepositoryProvider);
    final staff = ref.watch(staffRepositoryProvider);
    final authUser = ref.watch(authProvider).user;
    final slots = ref.watch(settingsRepositoryProvider).slotsSettings;
    final dayStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    // Как на мобильном [_ordersForDayWithDate]: показываем слот дня для всех, кроме отмены
    // (в т.ч. «Завершён» — чтобы запись не пропадала из сетки до конца дня).
    final dayOrders = orders
        .where((o) =>
            !o.effectiveDateTime.isBefore(dayStart) &&
            o.effectiveDateTime.isBefore(dayEnd) &&
            o.status != OrderStatus.cancelled)
        .toList();
    final allMasters = filterMastersForScheduleRole(
      mastersOnShiftForDate(staff, widget.selectedDate),
      authUser?.role,
      authUser?.id,
    );
    final hiddenIds = ref.watch(scheduleHiddenMasterIdsProvider);
    final masters = allMasters.where((m) => !hiddenIds.contains(m.id)).toList();
    final hasNamedBays = slots.hasNamedBays;
    final boardMode = ref.watch(scheduleBoardModeProvider);
    final orgSched = ref.watch(organizationProvider).valueOrNull?.schedulingMode ?? 'staff_based';
    final bayScheduleEnabled = hasNamedBays && orgSched == 'bay_based';
    final effectiveBoardMode = bayScheduleEnabled ? boardMode : ScheduleBoardMode.byMasters;
    final useBayColumns = effectiveBoardMode == ScheduleBoardMode.byBays && slots.bays.isNotEmpty;
    final unassigned = useBayColumns
        ? dayOrders
            .where((o) =>
                (o.masterId == null || o.masterId!.isEmpty) ||
                (o.bayId == null || o.bayId!.isEmpty))
            .toList()
        : dayOrders.where((o) => o.masterId == null || o.masterId!.isEmpty).toList();
    final totalSlots = _totalSlots(slots);
    final bodyHeight = totalSlots * _kRowHeight;
    final selectedOrderId = ref.watch(scheduleSelectedOrderIdProvider);
    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        _buildToolbarRow(
          dayOrders.length,
          unassigned.length,
          masters.length,
          slots.bays.length,
          useBayColumns,
        ),
        if (hasNamedBays && !bayScheduleEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Посты настроены, но в организации включён режим «по мастерам». Чтобы закреплять заказы за постами: «Слоты и подтверждение» → режим «По постам».',
              style: TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary, height: 1.35),
            ),
          ),
        if (bayScheduleEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<ScheduleBoardMode>(
                segments: const [
                  ButtonSegment(
                    value: ScheduleBoardMode.byMasters,
                    label: Text('По мастерам'),
                    icon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: ScheduleBoardMode.byBays,
                    label: Text('По постам'),
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                  ),
                ],
                selected: <ScheduleBoardMode>{boardMode},
                onSelectionChanged: (s) {
                  ref.read(scheduleBoardModeProvider.notifier).state = s.first;
                },
              ),
            ),
          ),
        _buildTableHeaderRow(
          masters: masters,
          bays: slots.bays,
          useBayColumns: useBayColumns,
          horizontalHeaderScroll: _horizontalHeaderScrollController,
        ),
        // Один вертикальный скролл: время, нераспределённые и колонки мастеров. В конце дня после 4 прокруток — следующий день.
        Expanded(
          child: ClipRect(
            child: Listener(
              onPointerSignal: _handleWheelAtBottom,
              behavior: HitTestBehavior.translucent,
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: SingleChildScrollView(
                controller: _verticalScrollController,
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  height: bodyHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTimeColumnBody(slots, totalSlots),
                          _buildUnassignedColumnBody(slots, unassigned, selectedOrderId),
                          Expanded(
                            child: Scrollbar(
                              controller: _horizontalBodyScrollController,
                              thumbVisibility: useBayColumns ? slots.bays.length > 2 : masters.length > 2,
                              child: SingleChildScrollView(
                                controller: _horizontalBodyScrollController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  height: bodyHeight,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (useBayColumns)
                                        for (int i = 0; i < slots.bays.length; i++)
                                          _BayColumnBody(
                                            key: ValueKey(slots.bays[i].id),
                                            bay: slots.bays[i],
                                            date: widget.selectedDate,
                                            dayOrders: dayOrders,
                                            slots: slots,
                                            totalSlots: totalSlots,
                                            selectedOrderId: selectedOrderId,
                                            onAssignToBayColumn: (orderId, slotIndex) =>
                                                _onAssignOrderToBay(orderId, slots.bays[i].id, slotIndex),
                                            onOrderTap: _onOrderTap,
                                            onOrderContextMenu: _onOrderContextMenu,
                                            onRequestAssign: _showMasterPickerForOrder,
                                            onEmptySlotTap: () => _scrollToMasterColumn(i),
                                            onEmptySlotDragUpdate: _onEmptySlotDragUpdate,
                                          )
                                      else
                                        for (int i = 0; i < masters.length; i++)
                                          _MasterColumnBody(
                                            key: ValueKey(masters[i].id),
                                            master: masters[i],
                                            masterIndex: i,
                                            date: widget.selectedDate,
                                            dayOrders: dayOrders,
                                            slots: slots,
                                            totalSlots: totalSlots,
                                            selectedOrderId: selectedOrderId,
                                            onAssignOrder: _onAssignOrder,
                                            onOrderTap: _onOrderTap,
                                            onOrderContextMenu: _onOrderContextMenu,
                                            onRequestAssign: _showMasterPickerForOrder,
                                            onEmptySlotTap: () => _scrollToMasterColumn(i),
                                            onEmptySlotDragUpdate: _onEmptySlotDragUpdate,
                                          ),
                                      if (!useBayColumns)
                                        _AddMasterColumnBody(
                                          totalSlots: totalSlots,
                                          onAddTap: () => _showAddMasterDialog(context),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderRow({
    required List<StaffEntry> masters,
    required List<ServiceBay> bays,
    required bool useBayColumns,
    required ScrollController horizontalHeaderScroll,
  }) {
    return IntrinsicHeight(
      child: Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.nestedBg,
        border: Border(bottom: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kTimeColWidth,
            child: Center(
              child: Text(
                'Время',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColorsDesktop.textSecondary,
                ),
              ),
            ),
          ),
          Container(
            width: _kUnassignedColWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColorsDesktop.border)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Нераспределённые заказы',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColorsDesktop.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: horizontalHeaderScroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (useBayColumns)
                    for (final bay in bays)
                      _BayColumnHeader(bay: bay)
                  else ...[
                    for (final master in masters)
                      _MasterColumnHeader(
                        master: master,
                        date: widget.selectedDate,
                        onRemove: () => ref.read(scheduleHiddenMasterIdsProvider.notifier).update((s) => {...s, master.id}),
                      ),
                    _AddMasterHeaderCell(onAddTap: () => _showAddMasterDialog(context)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// Одна рабочая строка: навигация по дню, дата (клик — календарь), Сегодня, счётчики, поиск (адаптивный).
  Widget _buildToolbarRow(
    int totalOrders,
    int unassignedCount,
    int mastersCount,
    int baysCount,
    bool useBayColumns,
  ) {
    final today = DateTime.now();
    final isToday = widget.selectedDate.year == today.year &&
        widget.selectedDate.month == today.month &&
        widget.selectedDate.day == today.day;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColorsDesktop.nestedBg,
        border: Border(bottom: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () {
              final prev = widget.selectedDate.subtract(const Duration(days: 1));
              widget.onDateChanged?.call(prev);
            },
            tooltip: 'Предыдущий день',
            style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
          ),
          const SizedBox(width: 4),
          _DateWithWheel(
            date: widget.selectedDate,
            onDateChanged: widget.onDateChanged,
            lastWheelTimeMs: _lastWheelTimeMs,
            throttleMs: _kWheelThrottleMs,
            onWheelUsed: () => setState(() => _lastWheelTimeMs = DateTime.now().millisecondsSinceEpoch),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && mounted) widget.onDateChanged?.call(picked);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () {
              final next = widget.selectedDate.add(const Duration(days: 1));
              widget.onDateChanged?.call(next);
            },
            tooltip: 'Следующий день',
            style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: isToday ? null : () => widget.onDateChanged?.call(DateTime(today.year, today.month, today.day)),
            child: const Text('Сегодня'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Text(
                  'Заказов: $totalOrders',
                  style: const TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 12),
                Text(
                  'Нераспр.: $unassignedCount',
                  style: const TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 12),
                Text(
                  useBayColumns ? 'Постов: $baysCount' : 'В смене: $mastersCount',
                  style: const TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск…',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColorsDesktop.textPlaceholder),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColorsDesktop.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColorsDesktop.border),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColorsDesktop.textTertiary),
                    ),
                    style: const TextStyle(fontSize: 12, color: AppColorsDesktop.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded, size: 20),
                  tooltip: 'Фильтры',
                  style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumnBody(SlotsSettings slots, int totalSlots) {
    return Container(
      width: _kTimeColWidth,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.nestedBg,
        border: Border(right: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          totalSlots,
          (i) => SizedBox(
            height: _kRowHeight,
            child: Center(
              child: Text(
                _slotTime(i, slots),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColorsDesktop.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnassignedColumnBody(SlotsSettings slots, List<Order> unassigned, String? selectedOrderId) {
    final totalSlots = _totalSlots(slots);
    final bodyHeight = totalSlots * _kRowHeight;
    return SizedBox(
      height: bodyHeight,
      width: _kUnassignedColWidth,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColorsDesktop.surface,
          border: Border(right: BorderSide(color: AppColorsDesktop.border)),
        ),
        child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (int i = 0; i < totalSlots; i++)
            Positioned(
              top: i * _kRowHeight,
              left: 0,
              right: 0,
              height: _kRowHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: i < totalSlots - 1
                        ? BorderSide(color: AppColorsDesktop.border.withValues(alpha: 0.5))
                        : BorderSide.none,
                  ),
                ),
              ),
            ),
          for (final o in unassigned)
            Positioned(
              top: _orderStartSlot(o, slots) * _kRowHeight + 4,
              left: 4,
              right: 4,
              height: (_orderSlotSpan(o, slots) * _kRowHeight - 8).clamp(_kRowHeight - 8, double.infinity),
              child: _DesktopScheduleOrderCard(
                order: o,
                isSelected: selectedOrderId == o.id,
                showAssignButton: true,
                onTap: () => _onOrderTap(o.id),
                onContextMenu: () => _onOrderContextMenu(context, o),
                isDraggable: o.status.isActive,
                onAssignOrder: _onAssignOrder,
                onRequestAssign: _showMasterPickerForOrder,
              ),
            ),
        ],
        ),
      ),
    );
  }

  /// Показывает модалку «Уведомить клиента о смещении времени?» при переносе в другой слот.
  /// Возвращает true = «Да, отправить запрос согласования», false = «Нет», null = отмена.
  Future<bool?> _showTimeShiftDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смещение времени'),
        content: const Text(
          'Уведомить клиента о смещении времени?\n\n'
          'Да — отправить запрос согласования в чат.\n'
          'Нет — применить новое время без уведомления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет, применить без согласования'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да, отправить запрос согласования'),
          ),
        ],
      ),
    );
  }

  void _onAssignOrder(String orderId, String masterId, int slotIndex) async {
    final repo = ref.read(orderRepositoryProvider.notifier);
    final order = ref.read(orderRepositoryProvider).where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;
    final staff = ref.read(staffRepositoryProvider);
    final master = staff.where((e) => e.id == masterId).firstOrNull;
    if (master == null) return;
    final slots = ref.read(settingsRepositoryProvider).slotsSettings;
    final dayStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final startMinutes = _dayStartMinutes(slots) + slotIndex * 30;
    final start = dayStart.add(Duration(minutes: startMinutes));
    int spanMin = order.estimatedMinutesForDisplay;
    if (spanMin <= 0 && order.plannedStartTime != null && order.plannedEndTime != null) {
      spanMin = order.plannedEndTime!.difference(order.plannedStartTime!).inMinutes;
    }
    if (spanMin <= 0) spanMin = 60;
    final end = start.add(Duration(minutes: spanMin));

    final oldStart = order.plannedStartTime ?? order.effectiveDateTime;
    final timeShift = (start.difference(oldStart).inMinutes).abs() > 0;
    final needTimeShiftModal = timeShift &&
        order.status != OrderStatus.pendingApproval &&
        order.plannedStartTime != null;

    if (needTimeShiftModal && mounted) {
      final choice = await _showTimeShiftDialog();
      if (choice == null || !mounted) return;
      final requestApproval = choice == true;
      await _applyAssignOrder(repo, orderId, master, start, end);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestApproval
                ? 'Запрос согласования отправлен клиенту'
                : 'Назначено: ${master.name}',
          ),
          backgroundColor: requestApproval ? AppColorsDesktop.info : AppColorsDesktop.success,
        ),
      );
      return;
    }

    await _applyAssignOrder(repo, orderId, master, start, end);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Назначено: ${master.name}'), backgroundColor: AppColorsDesktop.success),
      );
    }
  }

  Future<void> _applyAssignOrder(
    OrderRepository repo,
    String orderId,
    StaffEntry master,
    DateTime start,
    DateTime end,
  ) async {
    final result = await repo.assignMaster(orderId, StaffMember(id: master.id, name: master.name, roleLabel: master.role.label));
    if (result.errorOrNull != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorOrNull!.message), backgroundColor: AppColorsDesktop.error),
      );
      return;
    }
    await repo.updateOrderTime(orderId, plannedStartTime: start, plannedEndTime: end);
  }

  void _onAssignOrderToBay(String orderId, String bayId, int slotIndex) async {
    final repo = ref.read(orderRepositoryProvider.notifier);
    final order = ref.read(orderRepositoryProvider).where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;
    final slots = ref.read(settingsRepositoryProvider).slotsSettings;
    final bay = slots.bays.where((b) => b.id == bayId).firstOrNull;
    if (bay == null) return;
    final dayStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final startMinutes = _dayStartMinutes(slots) + slotIndex * 30;
    final start = dayStart.add(Duration(minutes: startMinutes));
    int spanMin = order.estimatedMinutesForDisplay;
    if (spanMin <= 0 && order.plannedStartTime != null && order.plannedEndTime != null) {
      spanMin = order.plannedEndTime!.difference(order.plannedStartTime!).inMinutes;
    }
    if (spanMin <= 0) spanMin = 60;
    final end = start.add(Duration(minutes: spanMin));

    final oldStart = order.plannedStartTime ?? order.effectiveDateTime;
    final timeShift = (start.difference(oldStart).inMinutes).abs() > 0;
    final needTimeShiftModal = timeShift &&
        order.status != OrderStatus.pendingApproval &&
        order.plannedStartTime != null;

    if (needTimeShiftModal && mounted) {
      final choice = await _showTimeShiftDialog();
      if (choice == null || !mounted) return;
      final requestApproval = choice == true;
      await _applyAssignBay(repo, orderId, bay, start, end);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestApproval
                ? 'Запрос согласования отправлен клиенту'
                : 'Назначен пост: ${bay.name}',
          ),
          backgroundColor: requestApproval ? AppColorsDesktop.info : AppColorsDesktop.success,
        ),
      );
      return;
    }

    await _applyAssignBay(repo, orderId, bay, start, end);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Назначен пост: ${bay.name}'), backgroundColor: AppColorsDesktop.success),
      );
    }
  }

  Future<void> _applyAssignBay(
    OrderRepository repo,
    String orderId,
    ServiceBay bay,
    DateTime start,
    DateTime end,
  ) async {
    final result = await repo.assignBay(orderId, bay.id);
    if (result.errorOrNull != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorOrNull!.message), backgroundColor: AppColorsDesktop.error),
      );
      return;
    }
    await repo.updateOrderTime(orderId, plannedStartTime: start, plannedEndTime: end);
  }

  void _onOrderTap(String orderId) {
    final current = ref.read(scheduleSelectedOrderIdProvider);
    ref.read(scheduleSelectedOrderIdProvider.notifier).state =
        current == orderId ? null : orderId;
  }

  void _onOrderContextMenu(BuildContext context, Order order) {
    // Контекстное меню показывается из карточки заказа (ПКМ) с правильной позицией.
  }

  void _showMasterPickerForOrder(Order order) {
    final u = ref.read(authProvider).user;
    final staff = filterMastersForScheduleRole(
      mastersOnShiftForDate(ref.read(staffRepositoryProvider), widget.selectedDate),
      u?.role,
      u?.id,
    );
    if (staff.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Назначить мастера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: staff
              .map((m) => ListTile(
                    title: Text(m.name),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onAssignOrder(order.id, m.id, _orderStartSlot(order, ref.read(settingsRepositoryProvider).slotsSettings));
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// Диалог выбора сотрудника из персонала для добавления в таблицу расписания (показывает скрытых мастеров).
  void _scrollToMasterColumn(int masterIndex) {
    if (!_horizontalBodyScrollController.hasClients) return;
    final offset = (masterIndex * _kMasterColWidth).clamp(0.0, _horizontalBodyScrollController.position.maxScrollExtent);
    _horizontalBodyScrollController.animateTo(offset, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _onEmptySlotDragUpdate(double deltaDx) {
    if (!_horizontalBodyScrollController.hasClients) return;
    final pos = _horizontalBodyScrollController.position;
    final newOffset = (pos.pixels - deltaDx).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _horizontalBodyScrollController.jumpTo(newOffset);
  }

  void _showAddMasterDialog(BuildContext context) {
    final hiddenIds = ref.read(scheduleHiddenMasterIdsProvider);
    final authUser = ref.read(authProvider).user;
    final staff = ref.read(staffRepositoryProvider);
    final hiddenMasters = filterMastersForScheduleRole(
      staff
          .where((e) => e.isActive && e.role == StaffRole.master && hiddenIds.contains(e.id))
          .toList(),
      authUser?.role,
      authUser?.id,
    );
    if (hiddenMasters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все мастера уже отображаются в таблице')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить в таблицу'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: hiddenMasters
                .map((m) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(_masterInitials(m), style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(m.name),
                      subtitle: Text(m.role.label),
                      onTap: () {
                        ref.read(scheduleHiddenMasterIdsProvider.notifier).update((s) {
                          final next = {...s};
                          next.remove(m.id);
                          return next;
                        });
                        Navigator.pop(ctx);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Блок даты: клик открывает календарь, колесо мыши переключает день (с throttle).
class _DateWithWheel extends StatelessWidget {
  const _DateWithWheel({
    required this.date,
    required this.onDateChanged,
    required this.lastWheelTimeMs,
    required this.throttleMs,
    required this.onWheelUsed,
    this.onTap,
  });

  final DateTime date;
  final void Function(DateTime)? onDateChanged;
  final int lastWheelTimeMs;
  final int throttleMs;
  final VoidCallback? onWheelUsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is! PointerScrollEvent || onDateChanged == null) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastWheelTimeMs < throttleMs) return;
        final delta = event.scrollDelta.dy;
        if (delta == 0) return;
        final next = delta > 0
            ? date.add(const Duration(days: 1))
            : date.subtract(const Duration(days: 1));
        onDateChanged!(next);
        onWheelUsed?.call();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              formatDate(date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColorsDesktop.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ячейка шапки «Добавить в таблицу» — выбор сотрудника из персонала.
class _AddMasterHeaderCell extends StatelessWidget {
  const _AddMasterHeaderCell({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColorsDesktop.nestedBg,
      child: InkWell(
        onTap: onAddTap,
        child: Container(
          width: _kMasterColWidth,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColorsDesktop.border)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(Icons.person_add_rounded, size: 22, color: AppColorsDesktop.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Добавить в таблицу',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColorsDesktop.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Тело колонки «Добавить в таблицу» — по высоте сетки, кнопка по центру.
class _AddMasterColumnBody extends StatelessWidget {
  const _AddMasterColumnBody({required this.totalSlots, required this.onAddTap});

  final int totalSlots;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kMasterColWidth,
      height: totalSlots * _kRowHeight,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.surface,
        border: Border(right: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Center(
        child: TextButton.icon(
          onPressed: onAddTap,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить в таблицу'),
          style: TextButton.styleFrom(foregroundColor: AppColorsDesktop.primary),
        ),
      ),
    );
  }
}

/// Шапка колонки мастера: аватар по центру сверху, жирное имя, смена и время.
class _MasterColumnHeader extends StatelessWidget {
  const _MasterColumnHeader({required this.master, required this.date, required this.onRemove});

  final StaffEntry master;
  final DateTime date;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = date.weekday % 7;
    final scheduleSlot = master.schedule.where((s) => s.dayOfWeek == dayOfWeek).firstOrNull;
    final isDayOff = scheduleSlot == null || !scheduleSlot.isWorkingDay;
    final workTime = scheduleSlot != null ? '${scheduleSlot.startTime}–${scheduleSlot.endTime}' : '—';

    return Container(
      width: _kMasterColWidth,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: const BoxDecoration(
        color: AppColorsDesktop.nestedBg,
        border: Border(right: BorderSide(color: AppColorsDesktop.border)),
      ),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: onRemove,
              tooltip: 'Убрать из таблицы',
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColorsDesktop.textTertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColorsDesktop.primary,
                    child: Text(
                      _masterInitials(master),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  master.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColorsDesktop.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  workTime,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColorsDesktop.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  isDayOff ? 'Выходной' : 'В смене',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDayOff ? AppColorsDesktop.textTertiary : AppColorsDesktop.statusCompleted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Шапка колонки поста (режим «по постам»): иконка сверху, жирное имя, подпись «Пост».
class _BayColumnHeader extends StatelessWidget {
  const _BayColumnHeader({required this.bay});

  final ServiceBay bay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kMasterColWidth,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: const BoxDecoration(
        color: AppColorsDesktop.nestedBg,
        border: Border(right: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(Icons.grid_view_rounded, size: 22, color: AppColorsDesktop.primary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 8),
          Text(
            bay.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColorsDesktop.textPrimary,
              height: 1.2,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Пост',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColorsDesktop.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Тело колонки поста: заказы с данным bay_id, дроп в слот назначает пост и время.
class _BayColumnBody extends StatelessWidget {
  const _BayColumnBody({
    super.key,
    required this.bay,
    required this.date,
    required this.dayOrders,
    required this.slots,
    required this.totalSlots,
    this.selectedOrderId,
    required this.onAssignToBayColumn,
    required this.onOrderTap,
    required this.onOrderContextMenu,
    required this.onRequestAssign,
    this.onEmptySlotTap,
    this.onEmptySlotDragUpdate,
  });

  final ServiceBay bay;
  final DateTime date;
  final List<Order> dayOrders;
  final SlotsSettings slots;
  final int totalSlots;
  final String? selectedOrderId;
  final void Function(String orderId, int slotIndex) onAssignToBayColumn;
  final void Function(String orderId) onOrderTap;
  final void Function(BuildContext context, Order order) onOrderContextMenu;
  final void Function(Order order) onRequestAssign;
  final VoidCallback? onEmptySlotTap;
  final void Function(double deltaDx)? onEmptySlotDragUpdate;

  @override
  Widget build(BuildContext context) {
    final bayOrders = dayOrders.where((o) => o.bayId == bay.id).toList();

    return Container(
      width: _kMasterColWidth,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.surface,
        border: Border(right: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (int i = 0; i < totalSlots; i++)
            Positioned(
              top: i * _kRowHeight,
              left: 0,
              right: 0,
              height: _kRowHeight,
              child: _SlotCell(
                slotIndex: i,
                ordersInSlot: bayOrders.where((o) => _orderStartSlot(o, slots) == i).toList(),
                isWorkingTime: true,
                onAssignDrop: onAssignToBayColumn,
                onEmptySlotTap: onEmptySlotTap,
                onEmptySlotDragUpdate: onEmptySlotDragUpdate,
              ),
            ),
          for (final o in bayOrders)
            Positioned(
              top: _orderStartSlot(o, slots) * _kRowHeight + 4,
              left: 4,
              right: 4,
              height: (_orderSlotSpan(o, slots) * _kRowHeight - 8).clamp(_kRowHeight - 8, double.infinity),
              child: _DesktopScheduleOrderCard(
                order: o,
                isSelected: selectedOrderId == o.id,
                showAssignButton: false,
                onTap: () => onOrderTap(o.id),
                onContextMenu: () => onOrderContextMenu(context, o),
                isDraggable: o.status.isActive,
                onAssignOrder: (orderId, _, slot) => onAssignToBayColumn(orderId, slot),
                slotSpan: _orderSlotSpan(o, slots),
                onRequestAssign: onRequestAssign,
              ),
            ),
        ],
      ),
    );
  }
}

/// Тело колонки мастера: сетка слотов и карточки заказов (скроллится вместе с временем).
class _MasterColumnBody extends StatelessWidget {
  const _MasterColumnBody({
    super.key,
    required this.master,
    required this.masterIndex,
    required this.date,
    required this.dayOrders,
    required this.slots,
    required this.totalSlots,
    this.selectedOrderId,
    required this.onAssignOrder,
    required this.onOrderTap,
    required this.onOrderContextMenu,
    required this.onRequestAssign,
    this.onEmptySlotTap,
    this.onEmptySlotDragUpdate,
  });

  final StaffEntry master;
  final int masterIndex;
  final DateTime date;
  final List<Order> dayOrders;
  final SlotsSettings slots;
  final int totalSlots;
  final String? selectedOrderId;
  final void Function(String orderId, String masterId, int slotIndex) onAssignOrder;
  final void Function(String orderId) onOrderTap;
  final void Function(BuildContext context, Order order) onOrderContextMenu;
  final void Function(Order order) onRequestAssign;
  final VoidCallback? onEmptySlotTap;
  final void Function(double deltaDx)? onEmptySlotDragUpdate;

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = date.weekday % 7;
    final scheduleSlot = master.schedule.where((s) => s.dayOfWeek == dayOfWeek).firstOrNull;
    final isDayOff = scheduleSlot == null || !scheduleSlot.isWorkingDay;
    final masterOrders = dayOrders.where((o) => o.masterId == master.id).toList();

    return Container(
      width: _kMasterColWidth,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.surface,
        border: Border(right: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: isDayOff
          ? Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColorsDesktop.nestedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ВЫХОДНОЙ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColorsDesktop.textTertiary,
                  ),
                ),
              ),
            )
          : Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (int i = 0; i < totalSlots; i++)
                  Positioned(
                    top: i * _kRowHeight,
                    left: 0,
                    right: 0,
                    height: _kRowHeight,
                    child: _SlotCell(
                      slotIndex: i,
                      ordersInSlot: masterOrders
                          .where((o) => _orderStartSlot(o, slots) == i)
                          .toList(),
                      isWorkingTime: _isSlotInMasterWorkRange(master, date, i, slots),
                      onAssignDrop: (orderId, si) => onAssignOrder(orderId, master.id, si),
                      onEmptySlotTap: onEmptySlotTap,
                      onEmptySlotDragUpdate: onEmptySlotDragUpdate,
                    ),
                  ),
                for (final o in masterOrders)
                  Positioned(
                    top: _orderStartSlot(o, slots) * _kRowHeight + 4,
                    left: 4,
                    right: 4,
                    height: (_orderSlotSpan(o, slots) * _kRowHeight - 8).clamp(_kRowHeight - 8, double.infinity),
                    child: _DesktopScheduleOrderCard(
                      order: o,
                      isSelected: selectedOrderId == o.id,
                      showAssignButton: false,
                      onTap: () => onOrderTap(o.id),
                      onContextMenu: () => onOrderContextMenu(context, o),
                      isDraggable: o.status.isActive,
                      onAssignOrder: onAssignOrder,
                      slotSpan: _orderSlotSpan(o, slots),
                      onRequestAssign: onRequestAssign,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slotIndex,
    required this.ordersInSlot,
    required this.isWorkingTime,
    required this.onAssignDrop,
    this.onEmptySlotTap,
    this.onEmptySlotDragUpdate,
  });

  final int slotIndex;
  final List<Order> ordersInSlot;
  final bool isWorkingTime;
  final void Function(String orderId, int slotIndex) onAssignDrop;
  final VoidCallback? onEmptySlotTap;
  final void Function(double deltaDx)? onEmptySlotDragUpdate;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Order>(
      onAcceptWithDetails: (details) {
        onAssignDrop(details.data.id, slotIndex);
      },
      onWillAcceptWithDetails: (_) => isWorkingTime && ordersInSlot.isEmpty,
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = isWorkingTime && candidateData.isNotEmpty && ordersInSlot.isEmpty;
        final isForbidden = candidateData.isNotEmpty && (!isWorkingTime || ordersInSlot.isNotEmpty);
        final isEmptyWorking = isWorkingTime && ordersInSlot.isEmpty && candidateData.isEmpty;
        Color bg = AppColorsDesktop.surface;
        if (!isWorkingTime) {
          bg = AppColorsDesktop.nestedBg;
        } else if (isForbidden) {
          bg = AppColorsDesktop.error.withValues(alpha: 0.08);
        } else if (isDropTarget) {
          bg = AppColorsDesktop.success.withValues(alpha: 0.12);
        }
        Widget cell = Container(
          height: _kRowHeight,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: isDropTarget ? BorderRadius.circular(6) : BorderRadius.zero,
            border: isDropTarget
                ? Border.all(color: AppColorsDesktop.success, width: 2, strokeAlign: BorderSide.strokeAlignInside)
                : Border(bottom: BorderSide(color: AppColorsDesktop.border.withValues(alpha: 0.5))),
          ),
          child: Center(
            child: isForbidden
                ? Tooltip(
                    message: ordersInSlot.isNotEmpty ? 'Слот занят' : 'Вне рабочих часов',
                    child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColorsDesktop.error.withValues(alpha: 0.8)),
                  )
                : Text(
                    isDropTarget ? 'Перетащите сюда' : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDropTarget ? AppColorsDesktop.success : AppColorsDesktop.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        );
        if (isEmptyWorking) {
          cell = MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              onTap: onEmptySlotTap,
              onPanUpdate: onEmptySlotDragUpdate != null
                  ? (details) => onEmptySlotDragUpdate!(details.delta.dx)
                  : null,
              behavior: HitTestBehavior.opaque,
              child: cell,
            ),
          );
        }
        return cell;
      },
    );
  }
}

class _DesktopScheduleOrderCard extends ConsumerStatefulWidget {
  const _DesktopScheduleOrderCard({
    required this.order,
    required this.isSelected,
    required this.showAssignButton,
    required this.onTap,
    required this.onContextMenu,
    required this.isDraggable,
    required this.onAssignOrder,
    this.slotSpan = 1,
    this.onRequestAssign,
  });

  final Order order;
  final bool isSelected;
  final bool showAssignButton;
  final VoidCallback onTap;
  final VoidCallback onContextMenu;
  final bool isDraggable;
  final void Function(String orderId, String masterId, int slotIndex) onAssignOrder;
  final int slotSpan;
  final void Function(Order order)? onRequestAssign;

  @override
  ConsumerState<_DesktopScheduleOrderCard> createState() => _DesktopScheduleOrderCardState();
}

class _DesktopScheduleOrderCardState extends ConsumerState<_DesktopScheduleOrderCard> {
  bool _hover = false;

  List<Widget> _contextMasterBayLines(Order order, ScheduleBoardMode boardMode, bool hasNamedBays, {required bool compact}) {
    if (!hasNamedBays) return <Widget>[];
    final fs = compact ? 8.0 : 9.0;
    final secondary = AppColorsDesktop.textSecondary;
    const primaryBlue = Color(0xFF2563EB);
    if (boardMode == ScheduleBoardMode.byBays) {
      final hasMaster = order.masterName != null && order.masterName!.trim().isNotEmpty;
      return [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            hasMaster ? 'Мастер: ${order.masterName!.trim()}' : 'Мастер не назначен',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w600,
              color: hasMaster ? primaryBlue : AppColorsDesktop.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    }
    if (order.bayName != null && order.bayName!.trim().isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            'Пост: ${order.bayName!.trim()}',
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    }
    if (order.bayId != null && order.bayId!.trim().isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            'Пост: ${order.bayId!.trim()}',
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    }
    return <Widget>[];
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasNamedBays = ref.watch(settingsRepositoryProvider).slotsSettings.hasNamedBays;
    final boardMode =
        hasNamedBays ? ref.watch(scheduleBoardModeProvider) : ScheduleBoardMode.byMasters;
    final start = order.plannedStartTime ?? order.effectiveDateTime;
    final startLocal = start.isUtc ? start.toLocal() : start;
    final bg = _cardBgForStatus(order.status);
    final accent = _cardAccentForStatus(order.status);
    final isSelected = widget.isSelected;
    final isHighlight = isSelected || _hover;
    final slotSpan = widget.slotSpan;
    final compact = slotSpan == 1;

    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          widget.onContextMenu();
          final canMutate = order.status.isActive;
          showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              details.globalPosition.dx + 1,
              details.globalPosition.dy + 1,
            ),
            items: [
              const PopupMenuItem(value: 'open', child: Text('Открыть')),
              if (canMutate) ...[
                const PopupMenuItem(value: 'assign', child: Text('Назначить мастера')),
                const PopupMenuItem(value: 'move', child: Text('Перенести')),
              ],
              const PopupMenuItem(value: 'chat', child: Text('Открыть чат')),
              if (canMutate) const PopupMenuItem(value: 'approval', child: Text('Запросить согласование')),
              if (canMutate) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'cancel', child: Text('Отменить')),
              ],
            ],
          ).then((v) {
            if (v == 'open') widget.onTap();
            if (v == 'assign') widget.onRequestAssign?.call(order);
          });
        },
        child: Material(
          color: isSelected
              ? _selectedCardBgForStatus(order.status)
              : (isHighlight ? bg : bg),
          borderRadius: BorderRadius.circular(10),
          elevation: isSelected ? 2 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: AppColorsDesktop.textPrimary,
                fontSize: 12,
                inherit: false,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 8),
                height: compact ? (_kRowHeight - 8) : double.infinity,
                clipBehavior: compact ? Clip.hardEdge : Clip.none,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: _selectedCardBorderForStatus(order.status), width: 2)
                      : isHighlight
                          ? Border.all(color: AppColorsDesktop.primary.withValues(alpha: 0.5), width: 1.5)
                          : Border(
                              left: BorderSide(
                                color: order.status == OrderStatus.pendingApproval
                                    ? AppColorsDesktop.statusApproval
                                    : accent,
                                width: 2,
                              ),
                            ),
                ),
                child: compact
                    ? _buildCompactContent(order, startLocal, accent, boardMode, hasNamedBays)
                    : _buildFullContent(order, startLocal, accent, boardMode, hasNamedBays),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.isDraggable) {
      final feedbackHeight = (widget.slotSpan * _kRowHeight - 8).clamp(_kRowHeight - 8, 280.0);
      card = Draggable<Order>(
        data: order,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: 0.92,
            child: SizedBox(
              width: _kUnassignedColWidth - 16,
              height: feedbackHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: card,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: card,
        ),
        child: card,
      );
    }
    return card;
  }

  /// Один слот: номер крупно, время справа с цветом, авто; верх прокручивается, статус закреплён снизу.
  Widget _buildCompactContent(
    Order order,
    DateTime startLocal,
    Color accent,
    ScheduleBoardMode boardMode,
    bool hasNamedBays,
  ) {
    final timeRange = _orderTimeRangeString(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColorsDesktop.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isDraggable) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.drag_indicator_rounded, size: 12, color: AppColorsDesktop.textTertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  order.carInfo.isNotEmpty ? order.carInfo : 'Автомобиль не указан',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColorsDesktop.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                ..._contextMasterBayLines(order, boardMode, hasNamedBays, compact: true),
                if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'Гос. ${order.licensePlate!.trim()}',
                      style: const TextStyle(fontSize: 9, color: AppColorsDesktop.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (order.comment != null && order.comment!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    order.comment!,
                    style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: AppColorsDesktop.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
            ),
            child: Text(
              order.status.label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  /// Несколько слотов: номер крупно, время справа; авто; состав (доп. работы — оранжевым); стоимость; статус внизу.
  Widget _buildFullContent(
    Order order,
    DateTime startLocal,
    Color accent,
    ScheduleBoardMode boardMode,
    bool hasNamedBays,
  ) {
    final timeRange = _orderTimeRangeString(order);
    const double fontSize = 10;
    final disp = order.itemsForDisplay;
    final canSeePrices = disp.any((i) => i.priceKopecks != null);
    final totalKopecks = order.totalKopecksForDisplay;
    final mainItems = disp.where((i) => !i.isAdditional).toList();
    final addItems = disp.where((i) => i.isAdditional).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColorsDesktop.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isDraggable) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.drag_indicator_rounded, size: 14, color: AppColorsDesktop.textTertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.carInfo.isNotEmpty ? order.carInfo : 'Автомобиль не указан',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColorsDesktop.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ..._contextMasterBayLines(order, boardMode, hasNamedBays, compact: false),
                if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'Гос. номер: ${order.licensePlate!.trim()}',
                      style: const TextStyle(fontSize: 9, color: AppColorsDesktop.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (order.masterName != null && order.masterName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Назначен: ${order.masterName}',
                    style: TextStyle(fontSize: fontSize, color: accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (order.clientName != null && order.clientName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Клиент: ${order.clientName}',
                    style: const TextStyle(fontSize: fontSize, color: AppColorsDesktop.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (disp.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Состав заказа',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColorsDesktop.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...mainItems.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            item.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 12,
                            color: item.isCompleted ? AppColorsDesktop.statusCompleted : AppColorsDesktop.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                                color: AppColorsDesktop.textPrimary,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...addItems.take(2).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            item.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 12,
                            color: item.isCompleted ? AppColorsDesktop.statusCompleted : AppColorsDesktop.statusApproval,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: fontSize,
                                color: AppColorsDesktop.statusApproval,
                                fontWeight: FontWeight.w500,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (disp.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+ ещё ${disp.length - 5}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppColorsDesktop.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (order.comment != null && order.comment!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      order.comment!,
                      style: const TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: AppColorsDesktop.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else if (order.comment != null && order.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.comment!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: AppColorsDesktop.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (canSeePrices && totalKopecks > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Итого: ${formatMoney(totalKopecks)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColorsDesktop.accentMoney,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
            ),
            child: Text(
              order.status.label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

