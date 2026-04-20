import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/utils/formatters.dart' show formatDate, formatTimeOrNull;
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

const int _kSlotMinutes = 30;
const double _kRowHeight = 72.0;
const double _kTimeColWidth = 52.0;
const int _kDayStartHour = 8;
const int _kDayEndHour = 21;

/// Расписание мастера: только колонка «Время» и колонка «Своё расписание» (заказы, назначенные на него).
/// Без горизонтального скролла и без нераспределённых заказов.
class MasterScheduleScreen extends ConsumerStatefulWidget {
  const MasterScheduleScreen({super.key});

  @override
  ConsumerState<MasterScheduleScreen> createState() => _MasterScheduleScreenState();
}

class _MasterScheduleScreenState extends ConsumerState<MasterScheduleScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  static int _slotIndex(DateTime dt) {
    final minutes = dt.hour * 60 + dt.minute;
    final startMinutes = _kDayStartHour * 60;
    final slot = (minutes - startMinutes) ~/ _kSlotMinutes;
    final total = ((_kDayEndHour - _kDayStartHour) * 60 / _kSlotMinutes).floor();
    return slot.clamp(0, total - 1);
  }

  static int get _totalSlots => ((_kDayEndHour - _kDayStartHour) * 60 / _kSlotMinutes).floor();

  static String _slotTime(int index) {
    final minutes = _kDayStartHour * 60 + index * _kSlotMinutes;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final myStaffId = ref.watch(currentMasterStaffIdProvider);
    final orders = ref.watch(orderRepositoryProvider);
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1));
    final dayOrders = orders
        .where((o) =>
            o.masterId == myStaffId &&
            !o.effectiveDateTime.isBefore(start) &&
            o.effectiveDateTime.isBefore(end) &&
            o.status != OrderStatus.cancelled)
        .toList();

    final desk = isDesktopPlatform;
    final border = desk ? AppColorsDesktop.border : AppColors.border;
    final borderSoft = desk ? AppColorsDesktop.border.withValues(alpha: 0.65) : AppColors.border.withValues(alpha: 0.5);
    final tp = desk ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final ts = desk ? AppColorsDesktop.textSecondary : AppColors.textSecondary;

    final scaffold = Scaffold(
      backgroundColor: desk ? AppColorsDesktop.background : AppColors.background,
      appBar: AppBar(
        title: const Text('Расписание'),
        backgroundColor: desk ? AppColorsDesktop.surface : null,
        foregroundColor: desk ? AppColorsDesktop.textPrimary : null,
        surfaceTintColor: desk ? Colors.transparent : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      formatDate(_selectedDate),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tp),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
          Expanded(
            child: myStaffId == null
                ? Center(
                    child: Text(
                      'Ваш профиль не найден в списке сотрудников.\nУточните у администратора.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ts),
                    ),
                  )
                : ListView.builder(
                    itemExtent: _kRowHeight,
                    itemCount: _totalSlots,
                    itemBuilder: (context, i) {
                      final inSlot = dayOrders
                          .where((o) => _slotIndex(o.plannedStartTime ?? o.effectiveDateTime) == i)
                          .toList();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: _kTimeColWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: border),
                                  bottom: i < _totalSlots - 1 ? BorderSide(color: borderSoft) : BorderSide.none,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _slotTime(i),
                                  style: TextStyle(fontSize: 11, color: ts, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: i < _totalSlots - 1 ? BorderSide(color: borderSoft) : BorderSide.none,
                                ),
                              ),
                              child: inSlot.isEmpty
                                  ? const SizedBox.shrink()
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.all(4),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: inSlot.map((o) => _orderCard(o, desk)).toList(),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return desk ? themeDesktopLight(child: scaffold) : scaffold;
  }

  Widget _orderCard(Order order, bool desk) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: desk ? AppColorsDesktop.surface : null,
      elevation: desk ? 0 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: desk ? AppColorsDesktop.border : AppColors.border.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          order.orderNumber,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: desk ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${order.carInfo}\n${formatTimeOrNull(order.dateTime)}',
          style: TextStyle(
            fontSize: 11,
            color: desk ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: order.status.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(order.status.label, style: TextStyle(fontSize: 10, color: order.status.color)),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
        ),
      ),
    );
  }
}
