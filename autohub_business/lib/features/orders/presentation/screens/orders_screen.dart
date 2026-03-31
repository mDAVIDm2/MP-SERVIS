import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/api_failure_banner.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/widgets/mobile_order_card.dart';
import '../widgets/order_detail_panel.dart';
import '../widgets/orders_desktop_components.dart';

class OrderFilters {
  final Set<OrderStatus> statuses;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? masterId;
  final String? bayId;

  const OrderFilters({
    this.statuses = const {},
    this.dateFrom,
    this.dateTo,
    this.masterId,
    this.bayId,
  });

  bool get hasActive =>
      statuses.isNotEmpty ||
      dateFrom != null ||
      dateTo != null ||
      masterId != null ||
      (bayId != null && bayId!.isNotEmpty);

  List<Order> apply(List<Order> orders) {
    var list = orders;
    if (statuses.isNotEmpty) {
      list = list.where((o) => statuses.contains(o.status)).toList();
    }
    if (dateFrom != null) {
      final start = DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day);
      list = list.where((o) => !o.effectiveDateTime.isBefore(start)).toList();
    }
    if (dateTo != null) {
      final end = DateTime(dateTo!.year, dateTo!.month, dateTo!.day).add(const Duration(days: 1));
      list = list.where((o) => o.effectiveDateTime.isBefore(end)).toList();
    }
    if (masterId != null && masterId!.isNotEmpty) {
      list = list.where((o) => o.masterId == masterId).toList();
    }
    if (bayId != null && bayId!.isNotEmpty) {
      list = list.where((o) => o.bayId == bayId).toList();
    }
    return list;
  }
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.isTabSelected = true});

  /// Когда true, экран считается видимым (выбрана вкладка «Заказы»). Используется для прокрутки к сегодняшнему дню.
  final bool isTabSelected;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

/// Ориентировочная высота одной секции (день) — с запасом, чтобы секция «сегодня» точно отрисовалась; финальная позиция — через ensureVisible.
const double _kEstimatedSectionHeight = 420;

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderFilters _filters = const OrderFilters();
  String? _selectedOrderId;

  // Desktop: полное состояние панели фильтров
  int _tabIndex = 0;
  OrdersPeriodFilter _period = OrdersPeriodFilter.all;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  OrderStatus? _statusFilter;
  String? _masterId;
  late TextEditingController _searchController;
  OrdersSort _sort = OrdersSort.byTime;
  bool _compactDensity = false; // false = Комфортно, true = Компактно
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollToTodayKey = GlobalKey();
  bool _didScrollToToday = false;
  bool _scrollToClientWhenOpen = false;

  /// Мобильный список «Активные»: прокрутка к секции «Сегодня» при открытии вкладки «Заказы».
  final ScrollController _mobileActiveOrdersScrollController = ScrollController();
  final GlobalKey _mobileScrollToTodayKey = GlobalKey();
  bool _didScrollToTodayMobile = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (!mounted || isDesktopPlatform) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isDesktopPlatform && !oldWidget.isTabSelected && widget.isTabSelected) {
      _didScrollToTodayMobile = false;
    }
  }

  void _scrollMobileActiveListToToday(List<Order> activeFiltered) {
    if (isDesktopPlatform || !widget.isTabSelected || _didScrollToTodayMobile || activeFiltered.isEmpty) return;
    if (!_mobileActiveOrdersScrollController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hasToday = activeFiltered.any((o) {
      final d = o.effectiveDateTime;
      return DateTime(d.year, d.month, d.day) == today;
    });
    if (!hasToday) {
      _didScrollToTodayMobile = true;
      return;
    }
    _didScrollToTodayMobile = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _mobileScrollToTodayKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.12,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  Future<void> _scrollToTodayIfNeeded(List<Order> filtered) async {
    if (!widget.isTabSelected || _didScrollToToday || filtered.isEmpty || !_scrollController.hasClients) return;
    if (_period != OrdersPeriodFilter.all) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final grouped = <DateTime, List<Order>>{};
    for (final o in filtered) {
      final d = o.effectiveDateTime;
      final day = DateTime(d.year, d.month, d.day);
      grouped.putIfAbsent(day, () => []).add(o);
    }
    final sortedDays = grouped.keys.toList()..sort();
    final todayIndex = sortedDays.indexOf(today);
    if (todayIndex < 0) return;
    _didScrollToToday = true;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final offset = (todayIndex * _kEstimatedSectionHeight).clamp(0.0, maxExtent);
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _scrollToTodayKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _mobileActiveOrdersScrollController.dispose();
    super.dispose();
  }

  List<Order> _applyDesktopFilters(List<Order> orders) {
    var list = orders;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == OrdersPeriodFilter.today) {
      list = list.where((o) {
        final d = o.effectiveDateTime;
        final day = DateTime(d.year, d.month, d.day);
        return day == today;
      }).toList();
    } else if (_period == OrdersPeriodFilter.tomorrow) {
      final tomorrow = today.add(const Duration(days: 1));
      list = list.where((o) {
        final d = o.effectiveDateTime;
        final day = DateTime(d.year, d.month, d.day);
        return day == tomorrow;
      }).toList();
    } else if (_period == OrdersPeriodFilter.week) {
      final weekEnd = today.add(const Duration(days: 7));
      list = list.where((o) {
        final d = o.effectiveDateTime;
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(today) && day.isBefore(weekEnd);
      }).toList();
    }

    if (_dateFrom != null) {
      final start = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
      list = list.where((o) => !o.effectiveDateTime.isBefore(start)).toList();
    }
    if (_dateTo != null) {
      final end = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day).add(const Duration(days: 1));
      list = list.where((o) => o.effectiveDateTime.isBefore(end)).toList();
    }
    if (_statusFilter != null) {
      list = list.where((o) => o.status == _statusFilter).toList();
    }
    if (_masterId != null && _masterId!.isNotEmpty) {
      list = list.where((o) => o.masterId == _masterId).toList();
    }

    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        return (o.orderNumber.toLowerCase().contains(q)) ||
            (o.clientName?.toLowerCase().contains(q) ?? false) ||
            (o.clientPhone?.replaceAll(RegExp(r'\D'), '').contains(q) ?? false) ||
            (o.carInfo.toLowerCase().contains(q));
      }).toList();
    }

    switch (_sort) {
      case OrdersSort.byTime:
        list = list..sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));
        break;
      case OrdersSort.byCreated:
        list = list..sort((a, b) => (a.createdAt ?? a.effectiveDateTime).compareTo(b.createdAt ?? b.effectiveDateTime));
        break;
      case OrdersSort.byStatus:
        list = list..sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
      case OrdersSort.byMaster:
        list = list..sort((a, b) => (a.masterName ?? '').compareTo(b.masterName ?? ''));
        break;
    }
    return list;
  }

  bool get _hasActiveDesktopFilters =>
      _period != OrdersPeriodFilter.all ||
      _dateFrom != null ||
      _dateTo != null ||
      _statusFilter != null ||
      (_masterId != null && _masterId!.isNotEmpty) ||
      _searchController.text.trim().isNotEmpty;

  void _resetDesktopFilters() {
    setState(() {
      _period = OrdersPeriodFilter.all;
      _dateFrom = null;
      _dateTo = null;
      _statusFilter = null;
      _masterId = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderRepositoryProvider);
    final ordersLoadErr = ref.watch(ordersLoadErrorProvider);
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    final active = orders.where((o) => o.status.isActive).toList()
      ..sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));
    final history = orders.where((o) => !o.status.isActive).toList()
      ..sort((a, b) => b.effectiveDateTime.compareTo(a.effectiveDateTime));

    final useDesktopLayout = isDesktopPlatform;

    if (useDesktopLayout) {
      final baseList = _tabIndex == 0 ? active : history;
      final filtered = _applyDesktopFilters(baseList);
      if (widget.isTabSelected && filtered.isNotEmpty && !_didScrollToToday) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTodayIfNeeded(filtered));
        });
      }

      return Scaffold(
        backgroundColor: AppColorsDesktop.background,
        body: Column(
          children: [
            if (ordersLoadErr != null)
              ApiFailureBanner(
                message: ordersLoadErr,
                dense: true,
                onRetry: () => ref.read(orderRepositoryProvider.notifier).loadFromApi(),
              ),
            OrdersFilterBar(
              activeTabIndex: _tabIndex,
              onTabChanged: (i) => setState(() => _tabIndex = i),
              period: _period,
              onPeriodChanged: (p) => setState(() => _period = p),
              selectedDateFrom: _dateFrom,
              selectedDateTo: _dateTo,
              onDateRangeTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _dateFrom != null && _dateTo != null
                      ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
                      : null,
                );
                if (range != null) setState(() { _dateFrom = range.start; _dateTo = range.end; });
              },
              statusFilter: _statusFilter,
              onStatusFilterChanged: (s) => setState(() => _statusFilter = s),
              masterId: _masterId,
              masterOptions: ref.watch(staffListProvider).map((m) => MasterOption(id: m.id, name: m.name)).toList(),
              onMasterChanged: (id) => setState(() => _masterId = id),
              searchController: _searchController,
              onSearchQueryChanged: (_) => setState(() {}),
              sort: _sort,
              onSortChanged: (s) => setState(() => _sort = s),
              hasActiveFilters: _hasActiveDesktopFilters,
              onResetFilters: _resetDesktopFilters,
              compactDensity: _compactDensity,
              onDensityChanged: (v) => setState(() => _compactDensity = v),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 68,
                    child: OrdersGroupedList(
                      orders: filtered,
                      selectedOrderId: _selectedOrderId,
                      onSelectOrder: (id) => setState(() {
                        _selectedOrderId = id;
                        _scrollToClientWhenOpen = false;
                      }),
                      onSelectOrderScrollToClient: (id) => setState(() {
                        _selectedOrderId = id;
                        _scrollToClientWhenOpen = true;
                      }),
                      canSeePrices: canSeePrices,
                      emptyMessage: 'Нет заказов по выбранным фильтрам',
                      onResetFilters: _resetDesktopFilters,
                      compactDensity: _compactDensity,
                      scrollController: _scrollController,
                      scrollToTodayKey: _scrollToTodayKey,
                    ),
                  ),
                  Expanded(
                    flex: 32,
                    child: _selectedOrderId != null
                        ? OrderDetailPanel(
                            orderId: _selectedOrderId!,
                            onClose: () => setState(() => _selectedOrderId = null),
                            scrollToClientWhenOpen: _scrollToClientWhenOpen,
                            onScrollToClientDone: () => setState(() => _scrollToClientWhenOpen = false),
                          )
                        : const OrderDetailPlaceholder(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Мобильный layout
    final activeFiltered = _applyMobileOrderNumberSearch(_filters.apply(active));
    final historyFiltered = _applyMobileOrderNumberSearch(_filters.apply(history));

    if (widget.isTabSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollMobileActiveListToToday(activeFiltered);
        });
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Заказы'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filters.hasActive,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            if (ordersLoadErr != null)
              ApiFailureBanner(
                message: ordersLoadErr,
                dense: true,
                onRetry: () => ref.read(orderRepositoryProvider.notifier).loadFromApi(),
              ),
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'Активные'),
                Tab(text: 'История'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  return TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Поиск по номеру заказа',
                      hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.9)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Очистить',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.nestedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.65), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                },
              ),
            ),
            if (_filters.hasActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _filterSummary(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _filters = const OrderFilters();
                      }),
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _MobileOrdersList(
                    orders: activeFiltered,
                    canSeePrices: canSeePrices,
                    historyMode: false,
                    searchQueryActive: _searchController.text.trim().isNotEmpty,
                    scrollController: _mobileActiveOrdersScrollController,
                    scrollToTodaySectionKey: _mobileScrollToTodayKey,
                  ),
                  _MobileOrdersList(
                    orders: historyFiltered,
                    canSeePrices: canSeePrices,
                    historyMode: true,
                    searchQueryActive: _searchController.text.trim().isNotEmpty,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterSummary() {
    final parts = <String>[];
    if (_filters.statuses.isNotEmpty) {
      parts.add('Статусы: ${_filters.statuses.map((s) => s.label).join(", ")}');
    }
    if (_filters.dateFrom != null) parts.add('С ${formatDate(_filters.dateFrom!)}');
    if (_filters.dateTo != null) parts.add('По ${formatDate(_filters.dateTo!)}');
    if (_filters.masterId != null && _filters.masterId!.isNotEmpty) {
      parts.add('Мастер');
    }
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  /// Мобильный список: только номер заказа (с учётом # и цифр).
  List<Order> _applyMobileOrderNumberSearch(List<Order> list) {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) return list;
    final q = raw.toLowerCase();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return list.where((o) {
      final numLower = o.orderNumber.toLowerCase();
      final displayLower = o.displayNumber.toLowerCase();
      if (numLower.contains(q) || displayLower.contains(q)) return true;
      if (digits.isNotEmpty) {
        final orderDigits = o.orderNumber.replaceAll(RegExp(r'\D'), '');
        if (orderDigits.contains(digits)) return true;
      }
      return false;
    }).toList();
  }

  void _showFilterSheet(BuildContext context) {
    final staff = ref.read(staffListProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          var statuses = Set<OrderStatus>.from(_filters.statuses);
          var dateFrom = _filters.dateFrom;
          var dateTo = _filters.dateTo;
          var masterId = _filters.masterId;
          var bayId = _filters.bayId;
          final bays = ref.read(settingsRepositoryProvider).slotsSettings.bays;

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Статус',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OrderStatus.values.map((s) {
                    final selected = statuses.contains(s);
                    return FilterChip(
                      label: Text(s.label),
                      selected: selected,
                      onSelected: (v) {
                        setModalState(() {
                          if (v) {
                            statuses.add(s);
                          } else {
                            statuses.remove(s);
                          }
                        });
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.3),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Период',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(dateFrom != null ? formatDate(dateFrom) : 'С даты'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setModalState(() => dateFrom = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(dateTo != null ? formatDate(dateTo) : 'По дату'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setModalState(() => dateTo = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Мастер',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: (masterId == null || masterId.isEmpty) ? '' : masterId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: const Text('Любой'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Любой')),
                    ...staff.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                  ],
                  onChanged: (v) => setModalState(() => masterId = v?.isEmpty == true ? null : v),
                ),
                if (bays.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Пост / бокс',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: (bayId == null || bayId.isEmpty) ? '' : bayId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Любой'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Любой')),
                      ...bays.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setModalState(() => bayId = v?.isEmpty == true ? null : v),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          statuses = {};
                          dateFrom = null;
                          dateTo = null;
                          masterId = null;
                          bayId = null;
                        });
                      },
                      child: const Text('Сбросить'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _filters = OrderFilters(
                              statuses: statuses,
                              dateFrom: dateFrom,
                              dateTo: dateTo,
                              masterId: masterId,
                              bayId: bayId,
                            );
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Применить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Мобильный список с группировкой по календарным дням.
class _MobileOrdersList extends StatefulWidget {
  const _MobileOrdersList({
    required this.orders,
    required this.canSeePrices,
    required this.historyMode,
    required this.searchQueryActive,
    this.scrollController,
    this.scrollToTodaySectionKey,
  });

  final List<Order> orders;
  final bool canSeePrices;
  /// true — вкладка «История»: сначала более новые дни; false — «Активные»: сначала более ранние дни.
  final bool historyMode;
  final bool searchQueryActive;
  final ScrollController? scrollController;
  final GlobalKey? scrollToTodaySectionKey;

  @override
  State<_MobileOrdersList> createState() => _MobileOrdersListState();
}

class _MobileOrdersListState extends State<_MobileOrdersList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => !widget.historyMode;

  static List<MapEntry<DateTime, List<Order>>> _groupByDay(List<Order> orders, {required bool historyMode}) =>
      groupOrdersByCalendarDay(orders, historyMode: historyMode);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final orders = widget.orders;
    if (orders.isEmpty) {
      return Center(
        child: Text(
          widget.searchQueryActive ? 'Нет заказов по этому номеру' : 'Нет заказов',
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    final sections = _groupByDay(orders, historyMode: widget.historyMode);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (var s = 0; s < sections.length; s++) ...[
          MobileDayHeader(
            key: widget.scrollToTodaySectionKey != null &&
                    !widget.historyMode &&
                    sections[s].key.year == todayKey.year &&
                    sections[s].key.month == todayKey.month &&
                    sections[s].key.day == todayKey.day
                ? widget.scrollToTodaySectionKey
                : null,
            day: sections[s].key,
            isFirst: s == 0,
          ),
          ...sections[s].value.map((o) => MobileOrderCard(order: o, canSeePrices: widget.canSeePrices)),
        ],
      ],
    );
  }
}
