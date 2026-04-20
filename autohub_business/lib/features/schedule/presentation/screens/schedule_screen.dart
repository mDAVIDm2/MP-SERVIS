import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/utils/schedule_masters_filter.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/utils/formatters.dart' show formatDate, formatTime, formatTimeOrNull;
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../orders/presentation/widgets/order_detail_panel.dart';
import 'schedule_desktop_grid.dart';
import '../providers/schedule_board_provider.dart';

/// Выбранный заказ для правой инспектор-панели на desktop.
final scheduleSelectedOrderIdProvider = StateProvider<String?>((ref) => null);

/// ID мастеров, скрытых из таблицы расписания (владелец/админ не показываются; можно убрать мастера из вида).
final scheduleHiddenMasterIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Шаг сетки по времени (минуты).
const int _kSlotMinutes = 30;
/// Высота одной строки слота (пиксели).
const double _kRowHeight = 72.0;
/// Ширина колонки времени.
const double _kTimeColWidth = 52.0;
/// Ширина колонки нераспределённых заказов.
const double _kUnassignedColWidth = 152.0;
/// Ширина колонки мастера.
const double _kMasterColWidth = 120.0;

int _scheduleDayStartMinutes(SlotsSettings slots) =>
    slots.startHour * 60 + slots.startMinute;
int _scheduleDayEndMinutes(SlotsSettings slots) =>
    slots.endHour * 60 + slots.endMinute;
int _scheduleTotalSlotsFor(SlotsSettings slots) =>
    ((_scheduleDayEndMinutes(slots) - _scheduleDayStartMinutes(slots)) / _kSlotMinutes).floor();
String _scheduleSlotTime(int index, SlotsSettings slots) {
  final startMinutes = _scheduleDayStartMinutes(slots);
  final minutes = startMinutes + index * _kSlotMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

DateTime _orderScheduleStartLocal(Order o) {
  final start = o.plannedStartTime ?? o.effectiveDateTime;
  return start.isUtc ? start.toLocal() : start;
}

DateTime _orderScheduleActualEndLocal(Order o) {
  final startLocal = _orderScheduleStartLocal(o);
  if (o.plannedEndTime != null) {
    final e = o.plannedEndTime!;
    return e.isUtc ? e.toLocal() : e;
  }
  var totalMin = o.items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
  if (totalMin <= 0) totalMin = 60;
  return startLocal.add(Duration(minutes: totalMin));
}

String _orderScheduleTimeRangeLabel(Order o) {
  final a = _orderScheduleStartLocal(o);
  final b = _orderScheduleActualEndLocal(o);
  return '${formatTimeOrNull(a)}–${formatTimeOrNull(b)}';
}

/// Данные перетаскивания: снятие мастера или перенос нераспределённого заказа по сетке.
class _ScheduleDragData {
  const _ScheduleDragData({required this.order, required this.allowSlotSnap});

  final Order order;
  /// true — нераспределённый заказ: подсветка слота и смена планового времени.
  final bool allowSlotSnap;
}

/// Подсветка при перетаскивании — обновляется без setState на всей странице (иначе срывается LongPressDraggable).
class _ScheduleHoverUi {
  const _ScheduleHoverUi({this.slot, this.unassignedRelease = false, this.overMasterColumn = false});

  final int? slot;
  final bool unassignedRelease;
  /// Для нераспределённого заказа: палец над колонкой мастера (подсветка слота только справа).
  final bool overMasterColumn;
}

/// Экран расписания для Владельца/Администратора: сетка с закреплёнными колонками (время + нераспределённые)
/// и горизонтальным скроллом колонок мастеров. Для роли master этот экран не используется — у мастера свой MasterScheduleScreen.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  late PageController _dayPageController;
  int _currentMasterIndex = 0;
  int _currentBayIndex = 0;
  static const int _dayPageOffset = 60;

  @override
  void initState() {
    super.initState();
    _dayPageController = PageController(initialPage: _dayPageOffset);
  }

  @override
  void dispose() {
    _dayPageController.dispose();
    super.dispose();
  }

  DateTime _dateForDayPage(int index) {
    return DateTime.now().subtract(Duration(days: _dayPageOffset)).add(Duration(days: index));
  }

  int _dayPageForDate(DateTime d) {
    final start = DateTime.now().subtract(Duration(days: _dayPageOffset));
    return d.difference(start).inDays.clamp(0, _dayPageOffset * 2 - 1);
  }

  /// Индекс слота по времени. Время приводится к локальному (исправляет отображение заказа 9–11 не в ячейке 8:00).
  static int _slotIndex(DateTime dt, SlotsSettings slots) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    final minutes = local.hour * 60 + local.minute;
    final startMinutes = _scheduleDayStartMinutes(slots);
    final total = _scheduleTotalSlotsFor(slots);
    final slot = (minutes - startMinutes) ~/ _kSlotMinutes;
    return slot.clamp(0, total - 1);
  }

  /// Индекс слота по времени начала заказа.
  int _orderStartSlot(Order o, SlotsSettings slots) {
    final start = o.plannedStartTime ?? o.effectiveDateTime;
    return _slotIndex(start, slots);
  }

  /// Сколько слотов занимает заказ (минимум 1). Конец — по верхней границе слота (ceil): 10:00–11:15 → слоты до 11:30.
  int _orderSlotSpan(Order o, SlotsSettings slots) {
    final gridStartMin = _scheduleDayStartMinutes(slots);
    final totalSlots = _scheduleTotalSlotsFor(slots);
    if (totalSlots <= 0) return 1;

    final start = o.plannedStartTime ?? o.effectiveDateTime;
    final localStart = start.isUtc ? start.toLocal() : start;
    final endLocal = _orderScheduleActualEndLocal(o);

    final startMinAbs = localStart.hour * 60 + localStart.minute;
    final endMinAbs = endLocal.hour * 60 + endLocal.minute;

    var startOffset = startMinAbs - gridStartMin;
    var endOffset = endMinAbs - gridStartMin;
    if (endOffset <= startOffset) endOffset = startOffset + _kSlotMinutes;

    final startSlot = (startOffset ~/ _kSlotMinutes).clamp(0, totalSlots - 1);
    final endSlotExclusive = ((endOffset + _kSlotMinutes - 1) ~/ _kSlotMinutes).clamp(startSlot + 1, totalSlots);
    var span = endSlotExclusive - startSlot;
    if (span < 1) span = 1;
    return span;
  }

  List<Order> _ordersForDayWithDate(List<Order> orders, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return orders
        .where((o) =>
            o.effectiveDateTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
            o.effectiveDateTime.isBefore(end) &&
            o.status != OrderStatus.cancelled)
        .toList();
  }


  /// Совпадает ли плановое окно «с–по» с уже сохранённым (дата и время до минуты).
  bool _ordersSamePlannedWindow(Order o, DateTime newStart, DateTime newEnd) {
    final os = _orderScheduleStartLocal(o);
    final oe = _orderScheduleActualEndLocal(o);
    final ns = newStart.isUtc ? newStart.toLocal() : newStart;
    final ne = newEnd.isUtc ? newEnd.toLocal() : newEnd;
    return os.year == ns.year &&
        os.month == ns.month &&
        os.day == ns.day &&
        os.hour == ns.hour &&
        os.minute == ns.minute &&
        oe.year == ne.year &&
        oe.month == ne.month &&
        oe.day == ne.day &&
        oe.hour == ne.hour &&
        oe.minute == ne.minute;
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderRepositoryProvider);
    final staff = ref.watch(staffRepositoryProvider);
    final slots = ref.watch(settingsRepositoryProvider).slotsSettings;
    final authUser = ref.watch(authProvider).user;

    final selectedOrderId = isDesktopPlatform ? ref.watch(scheduleSelectedOrderIdProvider) : null;
    final effectiveBackground = isDesktopPlatform ? AppColorsDesktop.background : AppColors.background;

    final scheduleBodyDesktop = isDesktopPlatform
        ? ScheduleDesktopGrid(
            selectedDate: _selectedDate,
            onDateChanged: (d) {
              setState(() => _selectedDate = d);
              if (!isDesktopPlatform && _dayPageController.hasClients) {
                _dayPageController.jumpToPage(_dayPageForDate(d));
              }
            },
          )
        : null;

    final boardMode = ref.watch(scheduleBoardModeProvider);
    final hasNamedBays = slots.hasNamedBays;
    final orgScheduling = ref.watch(organizationProvider).valueOrNull?.schedulingMode ?? 'staff_based';
    final bayScheduleEnabled = hasNamedBays && orgScheduling == 'bay_based';
    final effectiveBoardMode =
        bayScheduleEnabled ? boardMode : ScheduleBoardMode.byMasters;

    final scheduleBody = PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _dayPageController,
      onPageChanged: (i) {
        final newDate = _dateForDayPage(i);
        final newMasters = filterMastersForScheduleRole(
          mastersOnShiftForDate(staff, newDate),
          authUser?.role,
          authUser?.id,
        );
        setState(() {
          _selectedDate = newDate;
          if (newMasters.isNotEmpty && _currentMasterIndex >= newMasters.length) {
            _currentMasterIndex = newMasters.length - 1;
          }
          final nb = ref.read(settingsRepositoryProvider).slotsSettings.bays;
          if (nb.isNotEmpty && _currentBayIndex >= nb.length) {
            _currentBayIndex = nb.length - 1;
          }
        });
      },
      itemCount: _dayPageOffset * 2,
      itemBuilder: (context, dayIndex) {
        final date = _dateForDayPage(dayIndex);
        final dayOrdersForDate = _ordersForDayWithDate(orders, date);
        final unassignedForDate = bayScheduleEnabled && effectiveBoardMode == ScheduleBoardMode.byBays
            ? dayOrdersForDate
                .where((o) =>
                    (o.masterId == null || o.masterId!.isEmpty) ||
                    (o.bayId == null || o.bayId!.isEmpty))
                .toList()
            : dayOrdersForDate.where((o) => o.masterId == null || o.masterId!.isEmpty).toList();
        final mastersForDate = filterMastersForScheduleRole(
          mastersOnShiftForDate(staff, date),
          authUser?.role,
          authUser?.id,
        );
        final safeMasterIndex = mastersForDate.isEmpty ? 0 : _currentMasterIndex.clamp(0, mastersForDate.length - 1);
        final namedBays = slots.bays;
        final safeBayIndex = namedBays.isEmpty ? 0 : _currentBayIndex.clamp(0, namedBays.length - 1);
        return _ScheduleDayPage(
          date: date,
          dayIndex: dayIndex,
          totalDayPages: _dayPageOffset * 2,
          dayPageController: _dayPageController,
          dayOrdersForDate: dayOrdersForDate,
          unassignedForDate: unassignedForDate,
          mastersForDate: mastersForDate,
          currentMasterIndex: safeMasterIndex,
          onMasterIndexChanged: (i) => setState(() => _currentMasterIndex = i),
          boardMode: effectiveBoardMode,
          namedBays: namedBays,
          currentBayIndex: safeBayIndex,
          onBayIndexChanged: (i) => setState(() => _currentBayIndex = i),
          slots: slots,
          orderStartSlot: (o) => _orderStartSlot(o, slots),
          orderSlotSpan: (o) => _orderSlotSpan(o, slots),
          buildOrderCard: (o, showAssign, span) => _buildOrderCard(
                o,
                showAssignButton: showAssign,
                slotSpan: span,
                boardMode: effectiveBoardMode,
                hasNamedBays: hasNamedBays,
              ),
          onRequestClearMaster: (o) async {
            final repo = ref.read(orderRepositoryProvider.notifier);
            final r = await repo.clearMaster(o.id);
            if (!context.mounted) return;
            final err = r.errorOrNull;
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message), backgroundColor: AppColors.error));
            }
          },
          onRescheduleToSlot: (order, targetSlotIndex, dayDate) async {
            final repo = ref.read(orderRepositoryProvider.notifier);
            final orderApi = ref.read(orderApiServiceProvider);
            final chatApi = ref.read(chatApiServiceProvider);
            final slotsSet = ref.read(settingsRepositoryProvider).slotsSettings;
            final gridStartMin = _scheduleDayStartMinutes(slotsSet);
            final totalSlots = _scheduleTotalSlotsFor(slotsSet);
            final span = _orderSlotSpan(order, slotsSet);
            final maxStart = (totalSlots - span).clamp(0, totalSlots - 1);
            final slot = targetSlotIndex.clamp(0, maxStart);
            final day = DateTime(dayDate.year, dayDate.month, dayDate.day);
            final startMinutes = gridStartMin + slot * _kSlotMinutes;
            final newStart = DateTime(day.year, day.month, day.day, startMinutes ~/ 60, startMinutes % 60);
            final fresh = repo.getById(order.id) ?? order;
            final oldStart = _orderScheduleStartLocal(fresh);
            final oldEnd = _orderScheduleActualEndLocal(fresh);
            final newEnd = newStart.add(oldEnd.difference(oldStart));
            if (_ordersSamePlannedWindow(fresh, newStart, newEnd)) {
              return;
            }
            final r = await repo.updateOrderTime(order.id, plannedStartTime: newStart, plannedEndTime: newEnd);
            if (!context.mounted) return;
            if (r.errorOrNull != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.errorOrNull!.message), backgroundColor: AppColors.error));
              return;
            }
            final chatIdRes = await orderApi.getChatForOrder(order.id);
            if (!context.mounted) return;
            final chatId = chatIdRes.dataOrNull;
            if (chatId != null && chatId.isNotEmpty) {
              final msg =
                  'Запись заказа ${order.orderNumber} перенесена на ${formatDate(newStart)} ${formatTime(newStart)}–${formatTime(newEnd)}.';
              await chatApi.sendMessage(chatId, msg);
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Время записи обновлено; клиенту отправлено сообщение в чат')),
            );
          },
          onAssignUnassignedToMasterSlot: (order, targetSlotIndex, dayDate, master) async {
            final repo = ref.read(orderRepositoryProvider.notifier);
            final orderApi = ref.read(orderApiServiceProvider);
            final chatApi = ref.read(chatApiServiceProvider);
            final slotsSet = ref.read(settingsRepositoryProvider).slotsSettings;
            final gridStartMin = _scheduleDayStartMinutes(slotsSet);
            final totalSlots = _scheduleTotalSlotsFor(slotsSet);
            final span = _orderSlotSpan(order, slotsSet);
            final maxStart = (totalSlots - span).clamp(0, totalSlots - 1);
            final slot = targetSlotIndex.clamp(0, maxStart);
            final day = DateTime(dayDate.year, dayDate.month, dayDate.day);
            final startMinutes = gridStartMin + slot * _kSlotMinutes;
            final newStart = DateTime(day.year, day.month, day.day, startMinutes ~/ 60, startMinutes % 60);
            final fresh = repo.getById(order.id) ?? order;
            final oldStart = _orderScheduleStartLocal(fresh);
            final oldEnd = _orderScheduleActualEndLocal(fresh);
            final newEnd = newStart.add(oldEnd.difference(oldStart));
            final sameTime = _ordersSamePlannedWindow(fresh, newStart, newEnd);
            final staffMember = StaffMember(id: master.id, name: master.name, roleLabel: master.role.label);

            if (sameTime) {
              final rAssign = await repo.assignMaster(order.id, staffMember);
              if (!context.mounted) return;
              if (rAssign.errorOrNull != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(rAssign.errorOrNull!.message), backgroundColor: AppColors.error),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Назначен мастер ${master.name}')),
              );
              return;
            }

            // Сначала время, потом мастер: иначе refreshOrder после updateOrderTime перезапишет заказ с API
            // и сотрёт оптимистично назначенного мастера (заказ останется в «нераспределённые»).
            final rTime = await repo.updateOrderTime(order.id, plannedStartTime: newStart, plannedEndTime: newEnd);
            if (!context.mounted) return;
            if (rTime.errorOrNull != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(rTime.errorOrNull!.message), backgroundColor: AppColors.error),
              );
              return;
            }
            final rAssign = await repo.assignMaster(order.id, staffMember);
            if (!context.mounted) return;
            if (rAssign.errorOrNull != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(rAssign.errorOrNull!.message), backgroundColor: AppColors.error),
              );
              return;
            }
            final chatIdRes = await orderApi.getChatForOrder(order.id);
            if (!context.mounted) return;
            final chatId = chatIdRes.dataOrNull;
            if (chatId != null && chatId.isNotEmpty) {
              final msg =
                  'Запись заказа ${order.orderNumber} перенесена на ${formatDate(newStart)} ${formatTime(newStart)}–${formatTime(newEnd)}.';
              await chatApi.sendMessage(chatId, msg);
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Назначен мастер ${master.name}; время обновлено; сообщение в чат отправлено')),
            );
          },
          onAssignUnassignedToBaySlot: (order, targetSlotIndex, dayDate, bay) async {
            final repo = ref.read(orderRepositoryProvider.notifier);
            final orderApi = ref.read(orderApiServiceProvider);
            final chatApi = ref.read(chatApiServiceProvider);
            final slotsSet = ref.read(settingsRepositoryProvider).slotsSettings;
            final gridStartMin = _scheduleDayStartMinutes(slotsSet);
            final totalSlots = _scheduleTotalSlotsFor(slotsSet);
            final span = _orderSlotSpan(order, slotsSet);
            final maxStart = (totalSlots - span).clamp(0, totalSlots - 1);
            final slot = targetSlotIndex.clamp(0, maxStart);
            final day = DateTime(dayDate.year, dayDate.month, dayDate.day);
            final startMinutes = gridStartMin + slot * _kSlotMinutes;
            final newStart = DateTime(day.year, day.month, day.day, startMinutes ~/ 60, startMinutes % 60);
            final fresh = repo.getById(order.id) ?? order;
            final oldStart = _orderScheduleStartLocal(fresh);
            final oldEnd = _orderScheduleActualEndLocal(fresh);
            final newEnd = newStart.add(oldEnd.difference(oldStart));
            final sameTime = _ordersSamePlannedWindow(fresh, newStart, newEnd);

            if (sameTime) {
              final rAssign = await repo.assignBay(order.id, bay.id);
              if (!context.mounted) return;
              if (rAssign.errorOrNull != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(rAssign.errorOrNull!.message), backgroundColor: AppColors.error),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Назначен пост ${bay.name}')),
              );
              return;
            }

            final rTime = await repo.updateOrderTime(order.id, plannedStartTime: newStart, plannedEndTime: newEnd);
            if (!context.mounted) return;
            if (rTime.errorOrNull != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(rTime.errorOrNull!.message), backgroundColor: AppColors.error),
              );
              return;
            }
            final rAssign = await repo.assignBay(order.id, bay.id);
            if (!context.mounted) return;
            if (rAssign.errorOrNull != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(rAssign.errorOrNull!.message), backgroundColor: AppColors.error),
              );
              return;
            }
            final chatIdRes = await orderApi.getChatForOrder(order.id);
            if (!context.mounted) return;
            final chatId = chatIdRes.dataOrNull;
            if (chatId != null && chatId.isNotEmpty) {
              final msg =
                  'Запись заказа ${order.orderNumber} перенесена на ${formatDate(newStart)} ${formatTime(newStart)}–${formatTime(newEnd)}.';
              await chatApi.sendMessage(chatId, msg);
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Назначен пост; время обновлено; сообщение в чат отправлено')),
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: effectiveBackground,
      // На desktop заголовок и навигация по дате — в ScheduleDesktopGrid (один page header + toolbar).
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: Text('Расписание • ${formatDate(_selectedDate)}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && mounted) {
                      setState(() => _selectedDate = picked);
                      _dayPageController.jumpToPage(_dayPageForDate(picked));
                    }
                  },
                ),
              ],
            ),
      body: isDesktopPlatform
          ? ClipRect(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: scheduleBodyDesktop ?? scheduleBody),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerRight,
                    child: selectedOrderId != null
                        ? OrderDetailPanel(
                            key: ValueKey(selectedOrderId),
                            orderId: selectedOrderId,
                            onClose: () => ref.read(scheduleSelectedOrderIdProvider.notifier).state = null,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasNamedBays && !bayScheduleEnabled)
                  Material(
                    color: AppColors.nestedBg,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.9)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Посты настроены. Включите режим «По постам» в «Слоты и подтверждение», чтобы назначать заказы на пост в расписании.',
                              style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (bayScheduleEnabled)
                  Material(
                    color: AppColors.cardBg,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: SegmentedButton<ScheduleBoardMode>(
                        segments: const [
                          ButtonSegment(
                            value: ScheduleBoardMode.byMasters,
                            label: Text('Мастера'),
                            icon: Icon(Icons.person_outline_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: ScheduleBoardMode.byBays,
                            label: Text('Посты'),
                            icon: Icon(Icons.grid_view_rounded, size: 18),
                          ),
                        ],
                        selected: <ScheduleBoardMode>{boardMode},
                        onSelectionChanged: (s) {
                          ref.read(scheduleBoardModeProvider.notifier).state = s.first;
                          setState(() {
                            _currentMasterIndex = 0;
                            _currentBayIndex = 0;
                          });
                        },
                      ),
                    ),
                  ),
                Expanded(child: scheduleBody),
              ],
            ),
    );
  }

  /// Бейдж статуса заказа для нижней зоны мини-карточки расписания.
  Widget _scheduleOrderStatusPill(Order o, double maxWidth) {
    final c = o.status.color;
    final maxW = maxWidth > 0 ? maxWidth : 120.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              o.status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Order o, {
    required bool showAssignButton,
    required int slotSpan,
    required ScheduleBoardMode boardMode,
    required bool hasNamedBays,
  }) {
    final isCompactSlot = slotSpan == 1;
    final mainItems = o.items.where((i) => !i.isAdditional).toList();
    final addItems = o.items.where((i) => i.isAdditional).toList();
    final hasItems = o.items.isNotEmpty;
    final isTerminalSchedule = o.status == OrderStatus.done || o.status == OrderStatus.completed;
    final timeRangeLabel = _orderScheduleTimeRangeLabel(o);
    final needsAssignMaster =
        showAssignButton && o.status.isActive && (o.masterId == null || o.masterId!.trim().isEmpty);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      color: isTerminalSchedule ? AppColors.nestedBg : AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isTerminalSchedule ? AppColors.statusCompleted.withValues(alpha: 0.45) : AppColors.border,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isDesktopPlatform) {
            ref.read(scheduleSelectedOrderIdProvider.notifier).state = o.id;
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(isCompactSlot ? 4 : 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boundedH = constraints.maxHeight.isFinite;
              final horizontalPad = isCompactSlot ? 8.0 : 16.0;
              final footerW = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth - horizontalPad).clamp(1.0, double.infinity)
                  : 160.0;
              final statusFooter = _scheduleOrderStatusPill(o, footerW);

              final assignFooter = needsAssignMaster
                  ? _AssignMasterButton(order: o, onAssigned: () => setState(() {}))
                  : null;

              final footerColumn = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (assignFooter != null) assignFooter,
                  if (assignFooter != null) const SizedBox(height: 3),
                  Center(child: statusFooter),
                ],
              );

              final mainScroll = ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o.orderNumber,
                                        style: TextStyle(
                                          fontSize: isCompactSlot ? 11 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        timeRangeLabel,
                                        style: TextStyle(
                                          fontSize: isCompactSlot ? 8 : 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  o.carInfo.isNotEmpty ? o.carInfo : 'Автомобиль не указан',
                                  style: TextStyle(fontSize: isCompactSlot ? 9 : 10, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (hasNamedBays && boardMode == ScheduleBoardMode.byBays) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      (o.masterName != null && o.masterName!.trim().isNotEmpty)
                                          ? 'Мастер: ${o.masterName!.trim()}'
                                          : 'Мастер не назначен',
                                      style: TextStyle(
                                        fontSize: isCompactSlot ? 8 : 9,
                                        fontWeight: FontWeight.w600,
                                        color: (o.masterName != null && o.masterName!.trim().isNotEmpty)
                                            ? AppColors.primary
                                            : AppColors.textTertiary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                if (hasNamedBays && boardMode == ScheduleBoardMode.byMasters) ...[
                                  if (o.bayName != null && o.bayName!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        'Пост: ${o.bayName!.trim()}',
                                        style: TextStyle(
                                          fontSize: isCompactSlot ? 8 : 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  else if (o.bayId != null && o.bayId!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        'Пост: ${o.bayId!.trim()}',
                                        style: TextStyle(
                                          fontSize: isCompactSlot ? 8 : 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                if (o.vin != null && o.vin!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'VIN: ${o.vin!.trim()}',
                                      style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (o.licensePlate != null && o.licensePlate!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      'Гос. ${o.licensePlate!.trim()}',
                                      style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (hasItems && !isCompactSlot) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Состав заказа',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...mainItems.take(3).map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            item.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                            size: 10,
                                            color: item.isCompleted ? AppColors.statusCompleted : AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(fontSize: 9, color: AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ...addItems.take(2).map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            item.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                            size: 10,
                                            color: item.isCompleted ? AppColors.statusCompleted : AppColors.statusApproval,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(fontSize: 9, color: AppColors.statusApproval),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (hasItems && isCompactSlot) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    mainItems.map((i) => i.name).take(2).join(', '),
                                    style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              final scaledFooter = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: footerW > 0 ? footerW : constraints.maxWidth,
                  child: footerColumn,
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (boundedH)
                    Expanded(child: mainScroll)
                  else
                    mainScroll,
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: scaledFooter,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Одна страница дня: свои scroll-контроллеры (нет «attached to multiple»), свайп по мастерам — GestureDetector.
class _ScheduleDayPage extends StatefulWidget {
  const _ScheduleDayPage({
    required this.date,
    required this.dayIndex,
    required this.totalDayPages,
    required this.dayPageController,
    required this.dayOrdersForDate,
    required this.unassignedForDate,
    required this.mastersForDate,
    required this.currentMasterIndex,
    required this.onMasterIndexChanged,
    required this.boardMode,
    required this.namedBays,
    required this.currentBayIndex,
    required this.onBayIndexChanged,
    required this.slots,
    required this.orderStartSlot,
    required this.orderSlotSpan,
    required this.buildOrderCard,
    required this.onRequestClearMaster,
    required this.onRescheduleToSlot,
    required this.onAssignUnassignedToMasterSlot,
    required this.onAssignUnassignedToBaySlot,
  });


  final DateTime date;
  final int dayIndex;
  final int totalDayPages;
  final PageController dayPageController;
  final List<Order> dayOrdersForDate;
  final List<Order> unassignedForDate;
  final List<StaffEntry> mastersForDate;
  final int currentMasterIndex;
  final void Function(int) onMasterIndexChanged;
  final ScheduleBoardMode boardMode;
  final List<ServiceBay> namedBays;
  final int currentBayIndex;
  final void Function(int) onBayIndexChanged;
  final SlotsSettings slots;
  final int Function(Order) orderStartSlot;
  final int Function(Order) orderSlotSpan;
  final Widget Function(Order o, bool showAssignButton, int slotSpan) buildOrderCard;
  final Future<void> Function(Order order) onRequestClearMaster;
  final Future<void> Function(Order order, int targetSlotIndex, DateTime dayDate) onRescheduleToSlot;
  /// Нераспределённый заказ отпущен в колонке выбранного мастера: назначить мастера и время по слоту.
  final Future<void> Function(Order order, int targetSlotIndex, DateTime dayDate, StaffEntry master) onAssignUnassignedToMasterSlot;
  /// Нераспределённый заказ отпущен в колонке выбранного поста: назначить пост и время по слоту.
  final Future<void> Function(Order order, int targetSlotIndex, DateTime dayDate, ServiceBay bay) onAssignUnassignedToBaySlot;

  @override
  State<_ScheduleDayPage> createState() => _ScheduleDayPageState();
}

class _ScheduleDayPageState extends State<_ScheduleDayPage> {
  late LinkedScrollControllerGroup _linked;
  late ScrollController _leftScrollController;
  late ScrollController _rightScrollController;

  final GlobalKey _leftGridContentKey = GlobalKey();
  /// Сетка слотов справа — тот же scroll, что у колонки мастера; слот по Y берём отсюда, когда палец над мастером.
  final GlobalKey _rightGridContentKey = GlobalKey();
  final GlobalKey _scheduleAreaKey = GlobalKey();
  /// Точная область колонки мастера (для отпускания перетаскивания — не только по расчёту dx).
  final GlobalKey _masterColumnPaneKey = GlobalKey();

  /// Активная сессия перетаскивания — overlay DragTarget, без пересборки карточек.
  final ValueNotifier<_ScheduleDragData?> _dragSession = ValueNotifier<_ScheduleDragData?>(null);
  final ValueNotifier<_ScheduleHoverUi> _hoverUi = ValueNotifier<_ScheduleHoverUi>(const _ScheduleHoverUi());

  /// Последнее известное положение из onMove (onAccept иногда даёт чуть другой global — без этого уходит в onRescheduleToSlot).
  bool _dragPointerOverMasterColumn = false;

  late final Listenable _dragPaintListenable;

  @override
  void initState() {
    super.initState();
    _linked = LinkedScrollControllerGroup();
    _leftScrollController = _linked.addAndGet();
    _rightScrollController = _linked.addAndGet();
    _dragPaintListenable = Listenable.merge([_dragSession, _hoverUi]);
  }

  @override
  void dispose() {
    _dragSession.dispose();
    _hoverUi.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  int get _totalSlots => _scheduleTotalSlotsFor(widget.slots);
  String _slotTime(int index) => _scheduleSlotTime(index, widget.slots);

  int _slotIndexFromGlobal(Offset global, {required bool useRightColumnGrid}) {
    final primaryKey = useRightColumnGrid ? _rightGridContentKey : _leftGridContentKey;
    final fallbackKey = useRightColumnGrid ? _leftGridContentKey : _rightGridContentKey;
    RenderBox? gridBox = primaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null || !gridBox.hasSize) {
      gridBox = fallbackKey.currentContext?.findRenderObject() as RenderBox?;
    }
    if (gridBox == null || !gridBox.hasSize) return 0;
    final y = gridBox.globalToLocal(global).dy;
    return (y / _kRowHeight).floor().clamp(0, _totalSlots - 1);
  }

  bool _inUnassignedColumnFromGlobal(Offset global) {
    final areaBox = _scheduleAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (areaBox == null || !areaBox.hasSize) return false;
    final lx = areaBox.globalToLocal(global).dx;
    return lx >= _kTimeColWidth && lx < _kTimeColWidth + _kUnassignedColWidth;
  }

  /// Колонка текущего мастера: hit-test по реальному RenderBox (устойчивее, чем только dx от края Stack).
  bool _inMasterColumnFromGlobal(Offset global) {
    final box = _masterColumnPaneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final local = box.globalToLocal(global);
      if ((Offset.zero & box.size).contains(local)) return true;
    }
    final areaBox = _scheduleAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (areaBox == null || !areaBox.hasSize) return false;
    final lx = areaBox.globalToLocal(global).dx;
    return lx >= _kTimeColWidth + _kUnassignedColWidth;
  }

  void _onDragMove(DragTargetDetails<_ScheduleDragData> d) {
    final inUna = _inUnassignedColumnFromGlobal(d.offset);
    if (d.data.allowSlotSnap) {
      final overMaster = _inMasterColumnFromGlobal(d.offset);
      _dragPointerOverMasterColumn = overMaster;
      final slot = _slotIndexFromGlobal(d.offset, useRightColumnGrid: overMaster);
      _hoverUi.value = _ScheduleHoverUi(slot: slot, unassignedRelease: false, overMasterColumn: overMaster);
    } else {
      _hoverUi.value = _ScheduleHoverUi(slot: null, unassignedRelease: inUna);
    }
  }

  Future<void> _onDragAccept(DragTargetDetails<_ScheduleDragData> d) async {
    if (!mounted) return;
    final g = d.offset;
    final data = d.data;
    try {
      if (data.allowSlotSnap) {
        final useBayColumns =
            widget.boardMode == ScheduleBoardMode.byBays && widget.namedBays.isNotEmpty;
        final hasRightColumn =
            useBayColumns ? widget.namedBays.isNotEmpty : widget.mastersForDate.isNotEmpty;
        final inMaster =
            (_inMasterColumnFromGlobal(g) || _dragPointerOverMasterColumn) && hasRightColumn;
        final slot = _slotIndexFromGlobal(g, useRightColumnGrid: inMaster);
        if (inMaster) {
          if (useBayColumns) {
            final bay = widget.namedBays[widget.currentBayIndex.clamp(0, widget.namedBays.length - 1)];
            await widget.onAssignUnassignedToBaySlot(data.order, slot, widget.date, bay);
          } else {
            final master = widget.mastersForDate[widget.currentMasterIndex.clamp(0, widget.mastersForDate.length - 1)];
            await widget.onAssignUnassignedToMasterSlot(data.order, slot, widget.date, master);
          }
        } else {
          await widget.onRescheduleToSlot(data.order, slot, widget.date);
        }
      } else if (_inUnassignedColumnFromGlobal(g)) {
        await widget.onRequestClearMaster(data.order);
      }
    } finally {
      if (mounted) _resetDragUi();
    }
  }

  void _resetDragUi() {
    _dragSession.value = null;
    _dragPointerOverMasterColumn = false;
    _hoverUi.value = const _ScheduleHoverUi();
  }

  /// Удержание 1 с: снятие мастера — в колонку «Нераспределённые».
  /// [feedbackHeight] обязателен: иначе у feedback неограниченная высота и ломается Column+Expanded внутри карточки.
  Widget _wrapMasterLongPressDraggable({required Order order, required Widget card, required double feedbackHeight}) {
    final mid = order.masterId;
    if (!order.status.isActive || mid == null || mid.isEmpty) return card;
    return LongPressDraggable<_ScheduleDragData>(
      delay: const Duration(seconds: 1),
      data: _ScheduleDragData(order: order, allowSlotSnap: false),
      hapticFeedbackOnStart: true,
      onDragStarted: () {
        _dragSession.value = _ScheduleDragData(order: order, allowSlotSnap: false);
      },
      onDragEnd: (_) => _resetDragUi(),
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: _kMasterColWidth - 12,
          height: feedbackHeight,
          child: Opacity(
            opacity: 0.95,
            child: card,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  /// Удержание 1 с: перенос по сетке времени с подсветкой слота.
  Widget _wrapUnassignedLongPressDraggable({required Order order, required Widget card, required double feedbackHeight}) {
    if (!order.status.isActive) return card;
    return LongPressDraggable<_ScheduleDragData>(
      delay: const Duration(seconds: 1),
      data: _ScheduleDragData(order: order, allowSlotSnap: true),
      hapticFeedbackOnStart: true,
      onDragStarted: () {
        _dragSession.value = _ScheduleDragData(order: order, allowSlotSnap: true);
      },
      onDragEnd: (_) => _resetDragUi(),
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: _kUnassignedColWidth - 12,
          height: feedbackHeight,
          child: Opacity(
            opacity: 0.95,
            child: card,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  List<Widget> _slotGridLines() {
    return [
      for (int i = 0; i < _totalSlots; i++)
        Positioned(
          top: i * _kRowHeight,
          left: 0,
          right: 0,
          height: _kRowHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.border),
                bottom: i < _totalSlots - 1 ? BorderSide(color: AppColors.border.withValues(alpha: 0.5)) : BorderSide.none,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _leftColumnDragHighlights() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _dragPaintListenable,
        builder: (context, _) {
          final session = _dragSession.value;
          final h = _hoverUi.value;
          final showUna = session?.allowSlotSnap != true && h.unassignedRelease;
          final showSlot = session?.allowSlotSnap == true && h.slot != null && !h.overMasterColumn;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (showUna)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                    ),
                  ),
                ),
              if (showSlot)
                Positioned(
                  top: h.slot! * _kRowHeight + 1,
                  left: 0,
                  right: 0,
                  height: _kRowHeight - 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary, width: 2),
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _rightColumnSlotHighlight() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _dragPaintListenable,
        builder: (context, _) {
          final session = _dragSession.value;
          final h = _hoverUi.value;
          final show = session?.allowSlotSnap == true && h.slot != null && h.overMasterColumn;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (show)
                Positioned(
                  top: h.slot! * _kRowHeight + 1,
                  left: 0,
                  right: 0,
                  height: _kRowHeight - 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary, width: 2),
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final useBayColumns = w.boardMode == ScheduleBoardMode.byBays && w.namedBays.isNotEmpty;
    final List<Order> columnOrders;
    if (useBayColumns) {
      final bi = w.currentBayIndex.clamp(0, w.namedBays.length - 1);
      final bay = w.namedBays[bi];
      columnOrders = w.dayOrdersForDate.where((o) => o.bayId == bay.id).toList();
    } else {
      columnOrders = w.mastersForDate.isEmpty
          ? <Order>[]
          : w.dayOrdersForDate
              .where((o) => o.masterId == w.mastersForDate[w.currentMasterIndex.clamp(0, w.mastersForDate.length - 1)].id)
              .toList();
    }

    // Без mainAxisSize.min: иначе у Expanded неограниченная высота → RenderFlex unbounded.
    return Column(
      children: [
        _buildDayNav(),
        _buildHeader(),
        Expanded(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            key: _scheduleAreaKey,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _kTimeColWidth + _kUnassignedColWidth,
                    child: SingleChildScrollView(
                      controller: _leftScrollController,
                      child: SizedBox(
                        key: _leftGridContentKey,
                        height: _totalSlots * _kRowHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: _kTimeColWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  _totalSlots,
                                  (i) => SizedBox(
                                    height: _kRowHeight,
                                    child: Center(
                                      child: Text(
                                        _slotTime(i),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ..._slotGridLines(),
                                  _leftColumnDragHighlights(),
                                  ...w.unassignedForDate.map((o) {
                                    final span = w.orderSlotSpan(o);
                                    final h = (span * _kRowHeight - 8).clamp(_kRowHeight - 8, double.infinity).toDouble();
                                    return Positioned(
                                      top: w.orderStartSlot(o) * _kRowHeight + 4,
                                      left: 4,
                                      right: 4,
                                      height: h,
                                      child: _wrapUnassignedLongPressDraggable(
                                        order: o,
                                        feedbackHeight: h,
                                        card: w.buildOrderCard(o, true, span),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: _masterColumnPaneKey,
                      child: useBayColumns
                          ? (w.namedBays.isEmpty
                              ? Center(
                                  child: Text(
                                    'Добавьте посты в настройках слотов',
                                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : GestureDetector(
                                  behavior: HitTestBehavior.deferToChild,
                                  onHorizontalDragEnd: (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    final n = w.namedBays.length;
                                    if (n <= 1) return;
                                    if (v > 50) {
                                      w.onBayIndexChanged((w.currentBayIndex - 1).clamp(0, n - 1));
                                    }
                                    if (v < -50) {
                                      w.onBayIndexChanged((w.currentBayIndex + 1).clamp(0, n - 1));
                                    }
                                  },
                                  child: SingleChildScrollView(
                                    controller: _rightScrollController,
                                    child: SizedBox(
                                      key: _rightGridContentKey,
                                      height: _totalSlots * _kRowHeight,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ..._slotGridLines(),
                                          _rightColumnSlotHighlight(),
                                          ...columnOrders.map((o) {
                                            final span = w.orderSlotSpan(o);
                                            final h = (span * _kRowHeight - 8).clamp(_kRowHeight - 8, double.infinity).toDouble();
                                            return Positioned(
                                              top: w.orderStartSlot(o) * _kRowHeight + 4,
                                              left: 4,
                                              right: 4,
                                              height: h,
                                              child: _wrapMasterLongPressDraggable(
                                                order: o,
                                                feedbackHeight: h,
                                                card: w.buildOrderCard(o, false, span),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ))
                          : (w.mastersForDate.isEmpty
                              ? Center(child: Text('Нет мастеров в этот день', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)))
                              : GestureDetector(
                                  behavior: HitTestBehavior.deferToChild,
                                  onHorizontalDragEnd: (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (v > 50) {
                                      w.onMasterIndexChanged((w.currentMasterIndex - 1).clamp(0, w.mastersForDate.length - 1));
                                    }
                                    if (v < -50) {
                                      w.onMasterIndexChanged((w.currentMasterIndex + 1).clamp(0, w.mastersForDate.length - 1));
                                    }
                                  },
                                  child: SingleChildScrollView(
                                    controller: _rightScrollController,
                                    child: SizedBox(
                                      key: _rightGridContentKey,
                                      height: _totalSlots * _kRowHeight,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ..._slotGridLines(),
                                          _rightColumnSlotHighlight(),
                                          ...columnOrders.map((o) {
                                            final span = w.orderSlotSpan(o);
                                            final h = (span * _kRowHeight - 8).clamp(_kRowHeight - 8, double.infinity).toDouble();
                                            return Positioned(
                                              top: w.orderStartSlot(o) * _kRowHeight + 4,
                                              left: 4,
                                              right: 4,
                                              height: h,
                                              child: _wrapMasterLongPressDraggable(
                                                order: o,
                                                feedbackHeight: h,
                                                card: w.buildOrderCard(o, false, span),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                )),
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<_ScheduleDragData?>(
                valueListenable: _dragSession,
                builder: (context, session, _) {
                  if (session == null) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: DragTarget<_ScheduleDragData>(
                      onWillAcceptWithDetails: (_) => true,
                      onMove: _onDragMove,
                      onLeave: (_) {
                        _hoverUi.value = const _ScheduleHoverUi();
                      },
                      onAcceptWithDetails: (details) {
                        // Не await — иначе цель может не завершить accept; сброс UI в finally внутри _onDragAccept.
                        unawaited(_onDragAccept(details));
                      },
                      builder: (context, candidate, rejected) => const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayNav() {
    final w = widget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: w.dayIndex > 0
                ? () => w.dayPageController.animateToPage(w.dayIndex - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${formatDate(w.date)} (${w.dayOrdersForDate.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: w.dayIndex < w.totalDayPages - 1
                ? () => w.dayPageController.animateToPage(w.dayIndex + 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                : null,
          ),
        ],
      ),
    );
  }

  /// Зона ФИО / поста; компактные стрелки по краям — больше ширины под длинное имя на узком экране.
  Widget _scheduleColumnNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBg.withValues(alpha: 0.94),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  /// Широкая зона для ФИО / названия поста; стрелки по краям.
  Widget _scheduleColumnTitleNav({
    required String title,
    required String subtitle,
    required bool canPrev,
    required bool canNext,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
  }) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.25,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _scheduleColumnNavButton(
                icon: Icons.chevron_left_rounded,
                onPressed: canPrev ? onPrev : null,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _scheduleColumnNavButton(
                icon: Icons.chevron_right_rounded,
                onPressed: canNext ? onNext : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final useBayColumns = widget.boardMode == ScheduleBoardMode.byBays && widget.namedBays.isNotEmpty;
    final masters = widget.mastersForDate;
    final currentIndex = widget.currentMasterIndex;
    final total = masters.length;
    final bayIndex = widget.currentBayIndex.clamp(0, widget.namedBays.isEmpty ? 0 : widget.namedBays.length - 1);
    final orderCount = useBayColumns
        ? (widget.namedBays.isEmpty
            ? 0
            : widget.dayOrdersForDate.where((o) => o.bayId == widget.namedBays[bayIndex].id).length)
        : (masters.isEmpty ? 0 : widget.dayOrdersForDate.where((o) => o.masterId == masters[currentIndex].id).length);
    final subtitle = orderCount == 0 ? 'Нет заказов' : '$orderCount ${_orderCountLabel(orderCount)}';
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.nestedBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _kTimeColWidth + _kUnassignedColWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Нераспределённые',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'заказы',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.primary.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: useBayColumns
                ? (widget.namedBays.isEmpty
                    ? const SizedBox.shrink()
                    : _scheduleColumnTitleNav(
                        title: widget.namedBays[bayIndex].name,
                        subtitle: subtitle,
                        canPrev: widget.namedBays.length > 1 && bayIndex > 0,
                        canNext: widget.namedBays.length > 1 && bayIndex < widget.namedBays.length - 1,
                        onPrev: () => widget.onBayIndexChanged(bayIndex - 1),
                        onNext: () => widget.onBayIndexChanged(bayIndex + 1),
                      ))
                : (masters.isEmpty
                    ? const SizedBox.shrink()
                    : _scheduleColumnTitleNav(
                        title: masters[currentIndex].name,
                        subtitle: subtitle,
                        canPrev: total > 1 && currentIndex > 0,
                        canNext: total > 1 && currentIndex < total - 1,
                        onPrev: () => widget.onMasterIndexChanged(currentIndex - 1),
                        onNext: () => widget.onMasterIndexChanged(currentIndex + 1),
                      )),
          ),
        ],
      ),
    );
  }

  static String _orderCountLabel(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'заказов';
    if (m10 == 1) return 'заказ';
    if (m10 >= 2 && m10 <= 4) return 'заказа';
    return 'заказов';
  }
}

/// Кнопка «Назначить мастера» в нижней полосе мини-карточки (не выходит за границы: Row + Flexible, масштаб через FittedBox родителя).
class _AssignMasterButton extends StatelessWidget {
  const _AssignMasterButton({required this.order, required this.onAssigned});

  final Order order;
  final VoidCallback onAssigned;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final u = ref.watch(authProvider).user;
        final staff = filterMastersForScheduleRole(
          ref.watch(staffRepositoryProvider).where((e) => e.isActive && e.role == StaffRole.master).toList(),
          u?.role,
          u?.id,
        );
        final staffMembers = ref.watch(staffListProvider);
        final repo = ref.read(orderRepositoryProvider.notifier);

        if (staff.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text(
              'Нет мастеров',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMasterPicker(context, ref, staffMembers, repo),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_rounded, size: 12, color: AppColors.primary.withValues(alpha: 0.95)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Назначить мастера',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMasterPicker(BuildContext context, WidgetRef ref, List<StaffMember> staffMembers, OrderRepository repo) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Назначить мастера', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
            ...staffMembers.map((m) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  title: Text(m.name),
                  subtitle: Text(m.roleLabel ?? 'Мастер', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await repo.assignMaster(order.id, m);
                    if (!context.mounted) return;
                    if (result.errorOrNull == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Назначен: ${m.name}'), backgroundColor: AppColors.cardBg));
                      onAssigned();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorOrNull!.message), backgroundColor: AppColors.error));
                    }
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
