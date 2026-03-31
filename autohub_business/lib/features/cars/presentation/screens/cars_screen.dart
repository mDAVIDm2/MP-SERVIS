import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/car_aggregate.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/presentation/widgets/orders_desktop_components.dart';
import '../../../orders/presentation/widgets/order_detail_panel.dart';
import '../providers/cars_providers.dart';
import '../widgets/car_detail_panel.dart';
import 'car_detail_screen.dart';

class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  String? _selectedCarId;
  String? _selectedOrderId;
  String? _filterBrand;
  int? _filterYear;
  final _filterModelController = TextEditingController();
  final _filterClientController = TextEditingController();
  final _filterModelFocus = FocusNode();
  final _filterClientFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _filterModelController.addListener(() => setState(() {}));
    _filterClientController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filterModelController.dispose();
    _filterClientController.dispose();
    _filterModelFocus.dispose();
    _filterClientFocus.dispose();
    super.dispose();
  }

  static String? _brandFromCarInfo(String carInfo) {
    final t = carInfo.trim();
    if (t.isEmpty) return null;
    final parts = t.split(RegExp(r'[\s,]+'));
    return parts.isNotEmpty ? parts.first : null;
  }

  static int? _yearFromCarInfo(String carInfo) {
    final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(carInfo);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static List<CarView> _applyFilters(
    List<CarView> cars, {
    String? brand,
    int? year,
    String? modelSubstring,
    String? clientSubstring,
  }) {
    return cars.where((c) {
      if (brand != null && brand.isNotEmpty) {
        final b = _brandFromCarInfo(c.carInfo);
        if (b == null || b.toLowerCase() != brand.toLowerCase()) return false;
      }
      if (year != null) {
        final y = _yearFromCarInfo(c.carInfo);
        if (y != year) return false;
      }
      if (modelSubstring != null && modelSubstring.trim().isNotEmpty) {
        final sub = modelSubstring.trim().toLowerCase();
        if (!c.carInfo.toLowerCase().contains(sub)) return false;
      }
      if (clientSubstring != null && clientSubstring.trim().isNotEmpty) {
        final name = (c.clientName ?? '').toLowerCase();
        if (name.isEmpty || !name.contains(clientSubstring.trim().toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cars = ref.watch(carsFromOrdersProvider);
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    if (!isDesktopPlatform) {
      return _buildMobile(context, cars, canSeePrices);
    }
    return _buildDesktop(context, ref, cars, canSeePrices);
  }

  Widget _buildDesktop(BuildContext context, WidgetRef ref, List<CarView> cars, bool canSeePrices) {
    final uniqueBrands = <String>{};
    final uniqueYears = <int>{};
    final uniqueClients = <String>{};
    for (final c in cars) {
      final b = _brandFromCarInfo(c.carInfo);
      if (b != null) uniqueBrands.add(b);
      final y = _yearFromCarInfo(c.carInfo);
      if (y != null) uniqueYears.add(y);
      final name = c.clientName?.trim();
      if (name != null && name.isNotEmpty) uniqueClients.add(name);
    }
    final sortedBrands = uniqueBrands.toList()..sort();
    final sortedYears = uniqueYears.toList()..sort();
    final sortedClients = uniqueClients.toList()..sort();

    final filteredCars = _applyFilters(
      cars,
      brand: _filterBrand,
      year: _filterYear,
      modelSubstring: _filterModelController.text,
      clientSubstring: _filterClientController.text,
    );

    CarView? selectedCar;
    if (_selectedCarId != null) {
      for (final c in cars) {
        if (c.id == _selectedCarId) {
          selectedCar = c;
          break;
        }
      }
    }
    final carOrders = selectedCar?.orders ?? <Order>[];
    final grouped = <DateTime, List<Order>>{};
    for (final o in carOrders) {
      final d = o.effectiveDateTime;
      final day = DateTime(d.year, d.month, d.day);
      grouped.putIfAbsent(day, () => []).add(o);
    }
    final sortedDays = grouped.keys.toList()..sort();

    final hasActiveFilters = _filterBrand != null ||
        _filterYear != null ||
        (_filterModelController.text.trim().isNotEmpty) ||
        (_filterClientController.text.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesktopDesignSystem.pagePadding,
                    12,
                    DesktopDesignSystem.pagePadding,
                    8,
                  ),
                  child: _CarsFilterBar(
                    brands: sortedBrands,
                    years: sortedYears,
                    clientSuggestions: sortedClients,
                    selectedBrand: _filterBrand,
                    selectedYear: _filterYear,
                    modelController: _filterModelController,
                    clientController: _filterClientController,
                    modelFocus: _filterModelFocus,
                    clientFocus: _filterClientFocus,
                    hasActiveFilters: hasActiveFilters,
                    onBrandChanged: (v) => setState(() => _filterBrand = v),
                    onYearChanged: (v) => setState(() => _filterYear = v),
                    onFiltersChanged: () => setState(() {}),
                    onClearFilters: () {
                      setState(() {
                        _filterBrand = null;
                        _filterYear = null;
                        _filterModelController.clear();
                        _filterClientController.clear();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filteredCars.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car_outlined, size: 64, color: AppColorsDesktop.textTertiary),
                              const SizedBox(height: 16),
                              Text(
                                cars.isEmpty
                                    ? 'Нет данных об автомобилях'
                                    : 'Нет автомобилей по выбранному фильтру',
                                style: DesktopDesignSystem.bodySecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cars.isEmpty
                                    ? 'Автомобили появятся после создания заказов'
                                    : 'Измените или сбросьте фильтры',
                                style: DesktopDesignSystem.meta.copyWith(color: AppColorsDesktop.textTertiary),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: DesktopDesignSystem.pagePadding),
                          children: [
                            ...filteredCars.map((car) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CarListCard(
                                    car: car,
                                    canSeePrices: canSeePrices,
                                    isSelected: _selectedCarId == car.id,
                                    onTap: () => setState(() {
                                      _selectedCarId = car.id;
                                      _selectedOrderId = null;
                                    }),
                                  ),
                                )),
                            if (selectedCar != null) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 2, bottom: 10),
                                child: Text(
                                  'Заказы по автомобилю · ${carOrders.length} ${_orderWord(carOrders.length)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColorsDesktop.textPrimary,
                                  ),
                                ),
                              ),
                              if (carOrders.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Нет заказов по этому автомобилю',
                                      style: DesktopDesignSystem.bodySecondary,
                                    ),
                                  ),
                                )
                              else
                                ...sortedDays.map((day) {
                                  final dayOrders = grouped[day]!;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: OrdersDaySection(
                                      dateLabel: _dayLabel(day),
                                      orders: dayOrders,
                                      selectedOrderId: _selectedOrderId,
                                      canSeePrices: canSeePrices,
                                      onSelectOrder: (id) => setState(() => _selectedOrderId = id),
                                      compactDensity: false,
                                    ),
                                  );
                                }),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 32,
            child: _selectedOrderId != null
                ? OrderDetailPanel(
                    orderId: _selectedOrderId!,
                    onClose: () => setState(() => _selectedOrderId = null),
                  )
                : selectedCar != null
                    ? CarDetailPanel(
                        car: selectedCar,
                        onClose: () => setState(() {
                          _selectedCarId = null;
                          _selectedOrderId = null;
                        }),
                        canSeePrices: canSeePrices,
                      )
                    : const _CarsPanelPlaceholder(),
          ),
        ],
      ),
    );
  }

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

  static String _orderWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'заказ';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'заказа';
    return 'заказов';
  }

  Widget _buildMobile(BuildContext context, List<CarView> cars, bool canSeePrices) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автомобили')),
      body: cars.isEmpty
          ? const Center(child: Text('Нет данных об автомобилях'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cars.length,
              itemBuilder: (context, i) {
                final car = cars[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(car.carInfo),
                    subtitle: Text(
                      '${car.orderCount} заказов${car.clientName != null ? " · ${car.clientName}" : ""}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CarDetailScreen(carId: car.id, carInfo: car.carInfo),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Панель фильтров: марка, год, модель/поколение, клиент (с автодополнением).
class _CarsFilterBar extends StatefulWidget {
  const _CarsFilterBar({
    required this.brands,
    required this.years,
    required this.clientSuggestions,
    required this.selectedBrand,
    required this.selectedYear,
    required this.modelController,
    required this.clientController,
    required this.modelFocus,
    required this.clientFocus,
    required this.hasActiveFilters,
    required this.onBrandChanged,
    required this.onYearChanged,
    required this.onFiltersChanged,
    required this.onClearFilters,
  });

  final List<String> brands;
  final List<int> years;
  final List<String> clientSuggestions;
  final String? selectedBrand;
  final int? selectedYear;
  final TextEditingController modelController;
  final TextEditingController clientController;
  final FocusNode modelFocus;
  final FocusNode clientFocus;
  final bool hasActiveFilters;
  final void Function(String?) onBrandChanged;
  final void Function(int?) onYearChanged;
  final VoidCallback onFiltersChanged;
  final VoidCallback onClearFilters;

  @override
  State<_CarsFilterBar> createState() => _CarsFilterBarState();
}

class _CarsFilterBarState extends State<_CarsFilterBar> {
  final _clientOverlayKey = GlobalKey();
  OverlayEntry? _clientOverlayEntry;
  bool _clientSelectionInProgress = false;

  @override
  void initState() {
    super.initState();
    widget.clientFocus.addListener(_onClientFocusChange);
    widget.clientController.addListener(_onClientTextChange);
  }

  @override
  void dispose() {
    widget.clientFocus.removeListener(_onClientFocusChange);
    widget.clientController.removeListener(_onClientTextChange);
    _removeClientOverlay();
    super.dispose();
  }

  void _onClientFocusChange() {
    if (widget.clientFocus.hasFocus) {
      _showClientOverlay();
    } else {
      // Не закрывать оверлей сразу — дать время обработать тап по пункту списка.
      // Иначе оверлей удаляется до того, как сработает onTap у ListTile.
      if (!_clientSelectionInProgress) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          if (!_clientSelectionInProgress) _removeClientOverlay();
        });
      }
    }
  }

  void _onClientTextChange() {
    if (widget.clientFocus.hasFocus) {
      _showClientOverlay();
    }
  }

  List<String> _getFilteredClients() {
    final query = widget.clientController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.clientSuggestions;
    return widget.clientSuggestions
        .where((s) => s.toLowerCase().contains(query))
        .toList();
  }

  void _showClientOverlay() {
    _removeClientOverlay();
    final filtered = _getFilteredClients();

    final overlayState = Overlay.of(context);
    final keyContext = _clientOverlayKey.currentContext;
    final box = keyContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final controller = widget.clientController;
    final focusNode = widget.clientFocus;
    final onFiltersChanged = widget.onFiltersChanged;

    _clientOverlayEntry = OverlayEntry(
      builder: (ctx) => _ClientDropdownOverlay(
        suggestions: filtered,
        anchor: box,
        onSelect: (name) {
          _clientSelectionInProgress = true;
          // Отложить обновление на следующий кадр, чтобы тап успел обработаться до потери фокуса.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            controller.text = name;
            controller.selection = TextSelection.collapsed(offset: name.length);
            onFiltersChanged();
            _removeClientOverlay();
            focusNode.unfocus();
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) _clientSelectionInProgress = false;
            });
          });
        },
        onClose: () {
          _removeClientOverlay();
        },
      ),
    );
    overlayState.insert(_clientOverlayEntry!);
  }

  void _removeClientOverlay() {
    _clientOverlayEntry?.remove();
    _clientOverlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 20, color: AppColorsDesktop.primary),
              const SizedBox(width: 8),
              Text(
                'Фильтр',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColorsDesktop.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              if (widget.hasActiveFilters)
                TextButton.icon(
                  onPressed: widget.onClearFilters,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Сбросить'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColorsDesktop.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 0),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DropdownButtonFormField<String?>(
                      value: widget.selectedBrand,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Марка',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Все', overflow: TextOverflow.ellipsis)),
                        ...widget.brands.map((b) => DropdownMenuItem<String?>(value: b, child: Text(b, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: widget.onBrandChanged,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: DropdownButtonFormField<int?>(
                      value: widget.selectedYear,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Год',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Все', overflow: TextOverflow.ellipsis)),
                        ...widget.years.map((y) => DropdownMenuItem<int?>(value: y, child: Text('$y'))),
                      ],
                      onChanged: widget.onYearChanged,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: TextField(
                      controller: widget.modelController,
                      focusNode: widget.modelFocus,
                      onChanged: (_) => widget.onFiltersChanged(),
                      decoration: InputDecoration(
                        labelText: 'Модель / поколение',
                        hintText: 'Например: Camry, E60',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 0),
                  child: Padding(
                    key: _clientOverlayKey,
                    padding: const EdgeInsets.only(left: 6),
                    child: TextField(
                    controller: widget.clientController,
                    focusNode: widget.clientFocus,
                    onChanged: (_) {
                      widget.onFiltersChanged();
                      if (widget.clientFocus.hasFocus) _showClientOverlay();
                    },
                    onTap: () => _showClientOverlay(),
                    decoration: InputDecoration(
                      labelText: 'Клиент',
                      hintText: 'Ввести или выбрать из списка',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: widget.clientSuggestions.isNotEmpty
                          ? Icon(Icons.arrow_drop_down_rounded, color: AppColorsDesktop.textSecondary, size: 24)
                          : null,
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Оверлей выпадающего списка клиентов под полем ввода.
class _ClientDropdownOverlay extends StatelessWidget {
  const _ClientDropdownOverlay({
    required this.suggestions,
    required this.anchor,
    required this.onSelect,
    required this.onClose,
  });

  final List<String> suggestions;
  final RenderBox anchor;
  final void Function(String) onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pos = anchor.localToGlobal(Offset.zero);
    final size = anchor.size;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: pos.dx,
          top: pos.dy + size.height + 4,
          width: size.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColorsDesktop.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (_, i) {
                  final name = suggestions[i];
                  return InkWell(
                    onTap: () => onSelect(name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Плейсхолдер правой панели: «Выберите автомобиль».
class _CarsPanelPlaceholder extends StatelessWidget {
  const _CarsPanelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kOrderDetailPanelWidth,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.background,
        border: Border(left: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_outlined, size: 40, color: AppColorsDesktop.textTertiary),
              const SizedBox(height: 14),
              Text(
                'Выберите автомобиль',
                style: DesktopDesignSystem.sectionTitle.copyWith(
                  fontSize: 15,
                  color: AppColorsDesktop.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Справа отобразятся данные авто, владелец, аналитика и заказы',
                textAlign: TextAlign.center,
                style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarListCard extends StatelessWidget {
  const _CarListCard({
    required this.car,
    required this.canSeePrices,
    required this.isSelected,
    required this.onTap,
  });

  final CarView car;
  final bool canSeePrices;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = car.lastOrder;
    return Material(
      color: isSelected
          ? AppColorsDesktop.primary.withValues(alpha: 0.08)
          : AppColorsDesktop.surface,
      borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
      elevation: isSelected ? 1 : 0,
      shadowColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
            border: Border.all(
              color: isSelected ? AppColorsDesktop.primary : AppColorsDesktop.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: DesktopDesignSystem.shadowCard,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColorsDesktop.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car_rounded, color: AppColorsDesktop.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.carInfo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColorsDesktop.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (car.licensePlate != null && car.licensePlate!.isNotEmpty)
                          Text(
                            car.licensePlate!,
                            style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12),
                          ),
                        if (car.vin != null && car.vin!.isNotEmpty) ...[
                          if (car.licensePlate != null && car.licensePlate!.isNotEmpty)
                            Text(' · ', style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12)),
                          Text('VIN: ${car.vin}', style: DesktopDesignSystem.meta.copyWith(fontSize: 11)),
                        ],
                      ],
                    ),
                    if (car.clientName != null && car.clientName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Владелец: ${car.clientName}',
                        style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (last != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Последнее обращение: ${formatDateShort(last.effectiveDateTime)} · ${last.status.label}',
                        style: DesktopDesignSystem.meta.copyWith(fontSize: 11, color: AppColorsDesktop.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColorsDesktop.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${car.orderCount} ${_orderWord(car.orderCount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColorsDesktop.primary,
                      ),
                    ),
                  ),
                  if (canSeePrices && car.totalKopecks > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(car.totalKopecks),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColorsDesktop.accentMoney,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected ? AppColorsDesktop.primary : AppColorsDesktop.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _orderWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'заказ';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'заказа';
    return 'заказов';
  }
}
