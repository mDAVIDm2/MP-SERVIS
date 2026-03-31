import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/organization_business_kind.dart';
import '../../../../core/utils/formatters.dart';

/// Период фильтра: Сегодня, Завтра, Неделя, Все.
enum OrdersPeriodFilter {
  today,
  tomorrow,
  week,
  all,
}

/// Сортировка списка заказов.
enum OrdersSort {
  byTime,
  byCreated,
  byStatus,
  byMaster,
}

/// Цвет и стиль карточки по статусу (ТЗ п.4).
Color _statusPillColor(OrderStatus s) {
  switch (s) {
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

/// Лёгкий акцент фона карточки по статусу (оранжевый для согласования, красноватый для отмены).
Color? _cardAccentBg(OrderStatus s) {
  if (s == OrderStatus.pendingApproval) return AppColorsDesktop.statusApproval.withValues(alpha: 0.06);
  if (s == OrderStatus.cancelled) return AppColorsDesktop.error.withValues(alpha: 0.04);
  return null;
}

/// Левая граница карточки по статусу (оранжевая полоска для «Требует согласования»).
Color? _cardLeftBorder(OrderStatus s) {
  if (s == OrderStatus.pendingApproval) return AppColorsDesktop.statusApproval;
  return null;
}

// --- OrdersFilterBar ---

/// Уровень 2: панель фильтров и управления (вкладки, период, дата, статус, мастер, поиск, сортировка).
class OrdersFilterBar extends StatelessWidget {
  const OrdersFilterBar({
    super.key,
    required this.activeTabIndex,
    required this.onTabChanged,
    this.period = OrdersPeriodFilter.all,
    this.onPeriodChanged,
    this.selectedDateFrom,
    this.selectedDateTo,
    this.onDateRangeTap,
    this.statusFilter,
    this.onStatusFilterChanged,
    this.masterId,
    this.masterOptions = const [],
    this.onMasterChanged,
    this.searchController,
    this.onSearchQueryChanged,
    this.sort = OrdersSort.byTime,
    this.onSortChanged,
    this.hasActiveFilters = false,
    this.onResetFilters,
    this.compactDensity = false,
    this.onDensityChanged,
    this.organizationKindCode,
    this.organizationKindOptions = const [],
    this.onOrganizationKindChanged,
  });

  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final OrdersPeriodFilter period;
  final ValueChanged<OrdersPeriodFilter>? onPeriodChanged;
  final DateTime? selectedDateFrom;
  final DateTime? selectedDateTo;
  final VoidCallback? onDateRangeTap;
  final OrderStatus? statusFilter;
  final ValueChanged<OrderStatus?>? onStatusFilterChanged;
  final String? masterId;
  final List<MasterOption> masterOptions;
  final ValueChanged<String?>? onMasterChanged;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchQueryChanged;
  final OrdersSort sort;
  final ValueChanged<OrdersSort>? onSortChanged;
  final bool hasActiveFilters;
  final VoidCallback? onResetFilters;
  final bool compactDensity;
  final ValueChanged<bool>? onDensityChanged;
  /// null — все типы точек; иначе код `organization_business_kind`.
  final String? organizationKindCode;
  final List<({String? code, String label})> organizationKindOptions;
  final ValueChanged<String?>? onOrganizationKindChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        border: const Border(bottom: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Первый ряд: фильтры слева, поиск растягивается по ширине
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Активные'), icon: Icon(Icons.schedule_rounded, size: 16)),
                      ButtonSegment(value: 1, label: Text('История'), icon: Icon(Icons.history_rounded, size: 16)),
                    ],
                    selected: {activeTabIndex},
                    onSelectionChanged: (s) => onTabChanged(s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                    ),
                  ),
                  if (onPeriodChanged != null) ...[
                    const SizedBox(width: 8),
                    _periodChip('Сегодня', OrdersPeriodFilter.today),
                    const SizedBox(width: 4),
                    _periodChip('Завтра', OrdersPeriodFilter.tomorrow),
                    const SizedBox(width: 4),
                    _periodChip('Неделя', OrdersPeriodFilter.week),
                    const SizedBox(width: 4),
                    _periodChip('Все', OrdersPeriodFilter.all),
                  ],
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onDateRangeTap,
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: Text(
                      selectedDateFrom != null && selectedDateTo != null
                          ? '${formatDate(selectedDateFrom!)} – ${formatDate(selectedDateTo!)}'
                          : 'Выбор даты',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColorsDesktop.primary,
                      side: const BorderSide(color: AppColorsDesktop.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<OrderStatus?>(
                      value: statusFilter,
                      hint: const Text('Статус', style: TextStyle(fontSize: 12)),
                      isExpanded: false,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Все статусы')),
                        ...OrderStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                      ],
                      onChanged: onStatusFilterChanged,
                    ),
                  ),
                ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Номер, клиент, авто…',
                      hintStyle: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColorsDesktop.textTertiary),
                      filled: true,
                      fillColor: AppColorsDesktop.nestedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      isDense: true,
                    ),
                    style: DesktopDesignSystem.body.copyWith(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Второй ряд: мастера, сортировка, плотность, сброс
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (masterOptions.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: masterId?.isEmpty == true ? null : masterId,
                    hint: const Text('Все мастера', style: TextStyle(fontSize: 12)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все мастера')),
                      ...masterOptions.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                    ],
                    onChanged: onMasterChanged,
                  ),
                ),
              if (organizationKindOptions.isNotEmpty && onOrganizationKindChanged != null)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: organizationKindCode,
                    hint: const Text('Вид точки', style: TextStyle(fontSize: 12)),
                    items: organizationKindOptions
                        .map(
                          (o) => DropdownMenuItem<String?>(
                            value: o.code,
                            child: Text(o.label, style: const TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                    onChanged: onOrganizationKindChanged,
                  ),
                ),
              DropdownButtonHideUnderline(
                child: DropdownButton<OrdersSort>(
                  value: sort,
                  items: const [
                    DropdownMenuItem(value: OrdersSort.byTime, child: Text('По времени')),
                    DropdownMenuItem(value: OrdersSort.byCreated, child: Text('По дате создания')),
                    DropdownMenuItem(value: OrdersSort.byStatus, child: Text('По статусу')),
                    DropdownMenuItem(value: OrdersSort.byMaster, child: Text('По мастеру')),
                  ],
                  onChanged: (v) => v != null ? onSortChanged?.call(v) : null,
                ),
              ),
              if (onDensityChanged != null) ...[
                const SizedBox(width: 4),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Комфортно')),
                    ButtonSegment(value: true, label: Text('Компактно')),
                  ],
                  selected: {compactDensity},
                  onSelectionChanged: (s) => onDensityChanged!(s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                  ),
                ),
              ],
              if (hasActiveFilters && onResetFilters != null)
                TextButton.icon(
                  onPressed: onResetFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Сбросить фильтры'),
                  style: TextButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary, padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, OrdersPeriodFilter value) {
    final selected = period == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onPeriodChanged?.call(value),
      selectedColor: AppColorsDesktop.primary.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? AppColorsDesktop.primary : AppColorsDesktop.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Для выбора мастера в фильтре.
class MasterOption {
  final String id;
  final String name;
  const MasterOption({required this.id, required this.name});
}

// --- OrdersPageHeader ---

/// Уровень 1: один заголовок страницы «Заказы», справа — уведомления, overflow (поиск в панели фильтров).
class OrdersPageHeader extends StatelessWidget {
  const OrdersPageHeader({
    super.key,
    this.onNotificationsTap,
    this.onOverflowTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onOverflowTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: DesktopDesignSystem.pagePadding),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        border: const Border(bottom: BorderSide(color: AppColorsDesktop.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Заказы',
            style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 20),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: onNotificationsTap,
            style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
            tooltip: 'Уведомления',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onPressed: onOverflowTap,
            style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
            tooltip: 'Ещё',
          ),
        ],
      ),
    );
  }
}

// --- OrderStatusPill ---

/// Бейдж статуса: аккуратный, выразительный, не кислотный (ТЗ п.2.3).
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status, this.compact = false});

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _statusPillColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// --- OrderServicesPreview ---

/// Превью 2–3 услуг в карточке списка + «Доп. работы: N» (ТЗ п.3).
class OrderServicesPreview extends StatelessWidget {
  const OrderServicesPreview({
    super.key,
    required this.order,
    required this.canSeePrices,
    this.maxVisible = 3,
    this.compact = false,
  });

  final Order order;
  final bool canSeePrices;
  final int maxVisible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mainItems = order.itemsForDisplay.where((i) => !i.isAdditional).toList();
    final addItems = order.itemsForDisplay.where((i) => i.isAdditional).toList();
    final mainShow = mainItems.take(maxVisible).toList();
    final mainRest = mainItems.length - mainShow.length;
    final hasAdditional = addItems.isNotEmpty;
    final fs = compact ? 11.0 : 12.0;
    final iconSz = compact ? 12.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in mainShow)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 2 : 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: iconSz,
                  color: item.isCompleted ? AppColorsDesktop.success : AppColorsDesktop.textTertiary,
                ),
                SizedBox(width: compact ? 4 : 6),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: fs,
                      color: AppColorsDesktop.textPrimary,
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canSeePrices && item.priceKopecks != null)
                  Text(
                    formatMoney(item.priceKopecks!),
                    style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: AppColorsDesktop.textPrimary),
                  ),
              ],
            ),
          ),
        if (hasAdditional)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 2 : 4),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, size: iconSz, color: AppColorsDesktop.statusApproval),
                SizedBox(width: compact ? 4 : 6),
                Text(
                  'Доп. работы: ${addItems.length}',
                  style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.w500, color: AppColorsDesktop.statusApproval),
                ),
              ],
            ),
          ),
        if (mainRest > 0)
          Text(
            'ещё +$mainRest позиций',
            style: DesktopDesignSystem.meta.copyWith(fontSize: compact ? 10 : 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

// --- OrderListCardCompact ---

/// Компактная карточка заказа: приоритет — авто, статус, время, мастер, итог (ТЗ п.2.1–2.5, 4).
class OrderListCardCompact extends StatelessWidget {
  const OrderListCardCompact({
    super.key,
    required this.order,
    required this.isSelected,
    required this.canSeePrices,
    required this.onTap,
    this.onClientTap,
    this.compactDensity = false,
  });

  final Order order;
  final bool isSelected;
  final bool canSeePrices;
  final VoidCallback onTap;
  final VoidCallback? onClientTap;
  final bool compactDensity;

  @override
  Widget build(BuildContext context) {
    final accentBg = _cardAccentBg(order.status);
    final leftBorder = _cardLeftBorder(order.status);
    final start = order.plannedStartTime ?? order.dateTime;
    final end = order.plannedEndTime;
    final durationMin = order.estimatedMinutesForDisplay;
    final endComputed = end ?? start?.add(Duration(minutes: durationMin > 0 ? durationMin : 60));
    String timeLabel;
    if (start != null && endComputed != null) {
      timeLabel = '${formatOrderDatePart(start)} · ${formatTime(start)}–${formatTime(endComputed)}';
    } else if (start != null) {
      timeLabel = '${formatOrderDatePart(start)} · ${formatTime(start)}';
    } else {
      timeLabel = '—';
    }

    final disp = order.itemsForDisplay;
    final mainKopecks = disp
        .where((i) => !i.isAdditional && i.priceKopecks != null)
        .fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final addKopecks = disp
        .where((i) => i.isAdditional && i.priceKopecks != null)
        .fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final total = order.totalKopecksForDisplay;

    final pad = compactDensity ? 10.0 : 16.0;
    final spacing = compactDensity ? 6.0 : 10.0;
    final spacingBlock = compactDensity ? 8.0 : 12.0;

    return Material(
      color: isSelected
          ? AppColorsDesktop.primary.withValues(alpha: 0.08)
          : (accentBg ?? AppColorsDesktop.surface),
      borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
      elevation: isSelected ? 1 : 0,
      shadowColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        child: Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            borderRadius: leftBorder != null ? BorderRadius.zero : BorderRadius.circular(DesktopDesignSystem.radiusCard),
            border: Border(
              left: leftBorder != null ? BorderSide(color: leftBorder, width: 4) : BorderSide(color: isSelected ? AppColorsDesktop.primary : AppColorsDesktop.border, width: isSelected ? 2 : 1),
              top: BorderSide(color: isSelected ? AppColorsDesktop.primary : AppColorsDesktop.border, width: isSelected ? 2 : 1),
              right: BorderSide(color: isSelected ? AppColorsDesktop.primary : AppColorsDesktop.border, width: isSelected ? 2 : 1),
              bottom: BorderSide(color: isSelected ? AppColorsDesktop.primary : AppColorsDesktop.border, width: isSelected ? 2 : 1),
            ),
            boxShadow: DesktopDesignSystem.shadowCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ряд 1: номер слева, статус по центру, период брони в правом верхнем углу
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '#${order.orderNumber}',
                        style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: compactDensity ? 14 : 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  OrderStatusPill(status: order.status, compact: compactDensity),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: compactDensity ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          color: AppColorsDesktop.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacingBlock),
              // Блок «Автомобиль»: марка/модель/год и при наличии VIN, гос. номер
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: compactDensity ? 6 : 8),
                decoration: BoxDecoration(
                  color: AppColorsDesktop.nestedBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColorsDesktop.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_car_rounded, size: compactDensity ? 14 : 16, color: AppColorsDesktop.primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.carInfo.isNotEmpty ? order.carInfo : 'Автомобиль не указан',
                            style: TextStyle(
                              fontSize: compactDensity ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: AppColorsDesktop.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (order.vin != null && order.vin!.trim().isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        'VIN: ${order.vin!.trim()}',
                        style: TextStyle(fontSize: compactDensity ? 10 : 11, color: AppColorsDesktop.textSecondary, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        'Гос. номер: ${order.licensePlate!.trim()}',
                        style: TextStyle(fontSize: compactDensity ? 10 : 11, color: AppColorsDesktop.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: spacing),
              // Клиент — второй уровень; по клику открываем карточку и прокручиваем к блоку «Клиент»
              if (order.clientName != null && order.clientName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: onClientTap != null
                      ? MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => onClientTap!(),
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              order.clientName!,
                              style: DesktopDesignSystem.bodySecondary.copyWith(
                                fontSize: compactDensity ? 11 : 12,
                                color: AppColorsDesktop.statusApproval,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColorsDesktop.statusApproval,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      : Text(
                          order.clientName!,
                          style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: compactDensity ? 11 : 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              // Мастер — обязательно видим (ТЗ п.2.5)
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: compactDensity ? 12 : 14, color: AppColorsDesktop.textTertiary),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.masterName ?? 'Не назначен',
                      style: TextStyle(
                        fontSize: compactDensity ? 11 : 12,
                        fontWeight: FontWeight.w500,
                        color: order.masterName == null ? AppColorsDesktop.statusApproval : AppColorsDesktop.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (order.bayName != null && order.bayName!.trim().isNotEmpty) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.garage_outlined, size: compactDensity ? 12 : 14, color: AppColorsDesktop.textTertiary),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.bayName!.trim(),
                        style: TextStyle(fontSize: compactDensity ? 10 : 11, color: AppColorsDesktop.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty) ...[
                SizedBox(height: 3),
                Text(
                  OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind),
                  style: TextStyle(fontSize: compactDensity ? 10 : 11, color: AppColorsDesktop.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: spacingBlock),
              OrderServicesPreview(order: order, canSeePrices: canSeePrices, compact: compactDensity),
              SizedBox(height: spacingBlock),
              Divider(height: 1, color: AppColorsDesktop.border),
              SizedBox(height: spacing),
              // Финансовый блок: чисто, база — серый, доп — оранжевый, итог — главный акцент справа
              if (canSeePrices && total > 0) ...[
                if (mainKopecks > 0 && addKopecks > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Базовая стоимость', style: DesktopDesignSystem.meta.copyWith(fontSize: compactDensity ? 10 : 11, color: AppColorsDesktop.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(formatMoney(mainKopecks), style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: compactDensity ? 10 : 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                if (addKopecks > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Доп. работы', style: DesktopDesignSystem.meta.copyWith(fontSize: compactDensity ? 10 : 11, color: AppColorsDesktop.statusApproval), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text('+${formatMoney(addKopecks)}', style: TextStyle(fontSize: compactDensity ? 10 : 11, fontWeight: FontWeight.w600, color: AppColorsDesktop.statusApproval), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text('Итого', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: compactDensity ? 12 : 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      formatMoney(total),
                      style: TextStyle(
                        fontSize: compactDensity ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        color: AppColorsDesktop.accentMoney,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- OrdersDaySection ---

/// Секция «Сегодня, 6 марта · 8 заказов» с карточками.
class OrdersDaySection extends StatelessWidget {
  const OrdersDaySection({
    super.key,
    required this.dateLabel,
    required this.orders,
    required this.selectedOrderId,
    required this.canSeePrices,
    required this.onSelectOrder,
    this.onSelectOrderScrollToClient,
    this.compactDensity = false,
  });

  final String dateLabel;
  final List<Order> orders;
  final String? selectedOrderId;
  final bool canSeePrices;
  final void Function(String id) onSelectOrder;
  final void Function(String id)? onSelectOrderScrollToClient;
  final bool compactDensity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10, top: 6),
          child: Text(
            '$dateLabel · ${orders.length} ${_orderWord(orders.length)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColorsDesktop.textPrimary,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...orders.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrderListCardCompact(
                order: o,
                isSelected: selectedOrderId == o.id,
                canSeePrices: canSeePrices,
                onTap: () => onSelectOrder(o.id),
                onClientTap: (o.clientName != null && o.clientName!.isNotEmpty && onSelectOrderScrollToClient != null)
                    ? () => onSelectOrderScrollToClient!(o.id)
                    : null,
                compactDensity: compactDensity,
              ),
            )),
      ],
    );
  }

  static String _orderWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'заказ';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'заказа';
    return 'заказов';
  }
}

// --- OrdersGroupedList ---

/// Группировка заказов по дням и отображение секций.
class OrdersGroupedList extends StatelessWidget {
  const OrdersGroupedList({
    super.key,
    required this.orders,
    required this.selectedOrderId,
    required this.onSelectOrder,
    this.onSelectOrderScrollToClient,
    required this.canSeePrices,
    this.emptyMessage = 'Нет заказов по выбранным фильтрам',
    this.onResetFilters,
    this.compactDensity = false,
    this.scrollController,
    this.scrollToTodayKey,
  });

  final List<Order> orders;
  final String? selectedOrderId;
  final void Function(String id) onSelectOrder;
  final void Function(String id)? onSelectOrderScrollToClient;
  final bool canSeePrices;
  final String emptyMessage;
  final VoidCallback? onResetFilters;
  final bool compactDensity;
  /// Контроллер прокрутки списка (родитель прокручивает к сегодняшнему дню по оценённому offset).
  final ScrollController? scrollController;
  /// Ключ секции «сегодня» — после animateTo родитель вызывает ensureVisible для точной позиции.
  final GlobalKey? scrollToTodayKey;

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Сегодня, ${formatDateShort(date)}';
    if (d == tomorrow) return 'Завтра, ${formatDateShort(date)}';
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final wd = date.weekday - 1;
    return '${weekdays[wd]}, ${formatDateShort(date)}';
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColorsDesktop.textTertiary),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: DesktopDesignSystem.bodySecondary,
              textAlign: TextAlign.center,
            ),
            if (onResetFilters != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Сбросить фильтры'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColorsDesktop.primary,
                  side: const BorderSide(color: AppColorsDesktop.border),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final grouped = <DateTime, List<Order>>{};
    for (final o in orders) {
      final d = o.effectiveDateTime;
      final day = DateTime(d.year, d.month, d.day);
      grouped.putIfAbsent(day, () => []).add(o);
    }
    final sortedDays = grouped.keys.toList()..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
      itemCount: sortedDays.length,
      itemBuilder: (context, i) {
        final day = sortedDays[i];
        final dayOrders = grouped[day]!;
        final section = Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: OrdersDaySection(
            dateLabel: _dayLabel(day),
            orders: dayOrders,
            selectedOrderId: selectedOrderId,
            canSeePrices: canSeePrices,
            onSelectOrder: onSelectOrder,
            onSelectOrderScrollToClient: onSelectOrderScrollToClient,
            compactDensity: compactDensity,
          ),
        );
        if (day == today && scrollToTodayKey != null) {
          return KeyedSubtree(key: scrollToTodayKey, child: section);
        }
        return section;
      },
    );
  }
}
