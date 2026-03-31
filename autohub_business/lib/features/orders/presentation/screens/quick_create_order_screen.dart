import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/russian_plate_utils.dart';
import '../../../../core/api/services/api_services_providers.dart';
import 'order_detail_screen.dart';

/// Экран быстрого создания заказа (кнопка-ключик): состав, авто, время, мастер, клиент.
class QuickCreateOrderScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const QuickCreateOrderScreen({super.key, this.initialDate});

  @override
  ConsumerState<QuickCreateOrderScreen> createState() => _QuickCreateOrderScreenState();
}

class _CarOption {
  final String carId;
  final String carInfo;
  final String? vin;
  final String? licensePlate;

  const _CarOption({required this.carId, required this.carInfo, this.vin, this.licensePlate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _CarOption && other.carId == carId && other.carInfo == carInfo);

  @override
  int get hashCode => Object.hash(carId, carInfo);
}

class _ClientOption {
  final String name;
  final String? phone;

  const _ClientOption({required this.name, this.phone});
  String get displayLabel => phone != null && phone!.isNotEmpty ? '$name • $phone' : name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _ClientOption && other.name == name && other.phone == phone);

  @override
  int get hashCode => Object.hash(name, phone);
}

String _qcNormalizePhone(String? phone) {
  if (phone == null) return '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) return '7${digits.substring(1)}';
  return digits;
}

bool _qcCarMatchesSearch(_CarOption c, String query) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) return true;
  String normPlate(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');
  final qPlate = normPlate(t);
  return c.carInfo.toLowerCase().contains(t) ||
      (c.vin ?? '').toLowerCase().contains(t) ||
      normPlate(c.licensePlate ?? '').contains(qPlate);
}

class _QuickCreateOrderScreenState extends ConsumerState<QuickCreateOrderScreen> {
  late DateTime _dateTime;
  final _carInfoController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _commentController = TextEditingController();
  final _selectedServices = <ServiceItem>[];
  final _customItems = <OrderItem>[];
  bool _carFromList = true;
  _CarOption? _selectedCar;
  _ClientOption? _selectedClient;
  /// Список клиентов держим открытым по TapRegion, а не только по focus (иначе клик по строке снимает focus и список исчезает до onTap).
  bool _clientPickerPinned = false;
  StaffMember? _selectedMaster;
  /// Пост при режиме «по постам»; null — сервер подберёт свободный пост.
  String? _selectedBayId;
  bool _saving = false;
  bool _newCarExpanded = false;
  final _newCarVinController = TextEditingController();
  final _newCarPlateController = TextEditingController();
  final _newCarColorController = TextEditingController();
  final _newCarMileageController = TextEditingController();
  final _newBrandController = TextEditingController();
  final _newModelController = TextEditingController();
  final _newGenerationController = TextEditingController();
  bool _newCarStructured = false;
  final _clientPhoneFocusNode = FocusNode();
  final _clientNameFocusNode = FocusNode();
  final _carSearchController = TextEditingController();
  final _carFocusNode = FocusNode();
  /// Выбор времени из сетки слотов или вручную.
  bool _manualTime = false;
  final _manualHourController = TextEditingController();
  final _manualMinuteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _dateTime = initial;
    if (_dateTime.hour == 0 && _dateTime.minute == 0) {
      _dateTime = _dateTime.copyWith(hour: 9, minute: 0);
    }
    _manualHourController.text = _dateTime.hour.toString();
    _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
    _clientPhoneFocusNode.addListener(_onClientFieldFocusChanged);
    _clientNameFocusNode.addListener(_onClientFieldFocusChanged);
    _carFocusNode.addListener(() => setState(() {}));
  }

  void _onClientFieldFocusChanged() {
    if (_clientPhoneFocusNode.hasFocus || _clientNameFocusNode.hasFocus) {
      setState(() => _clientPickerPinned = true);
    }
    setState(() {});
  }

  void _resetNewCarStructured() {
    _newCarStructured = false;
    _newBrandController.clear();
    _newModelController.clear();
    _newGenerationController.clear();
  }

  void _applyCatalogSuggestion(QuickRefCarPick p) {
    setState(() {
      _newCarStructured = true;
      _newBrandController.text = p.brandName;
      _newModelController.text = p.modelName;
      _newGenerationController.clear();
      _carInfoController.clear();
    });
  }

  @override
  void dispose() {
    _clientPhoneFocusNode.removeListener(_onClientFieldFocusChanged);
    _clientNameFocusNode.removeListener(_onClientFieldFocusChanged);
    _carInfoController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _commentController.dispose();
    _manualHourController.dispose();
    _manualMinuteController.dispose();
    _newCarVinController.dispose();
    _newCarPlateController.dispose();
    _newCarColorController.dispose();
    _newCarMileageController.dispose();
    _newBrandController.dispose();
    _newModelController.dispose();
    _newGenerationController.dispose();
    _clientPhoneFocusNode.dispose();
    _clientNameFocusNode.dispose();
    _carSearchController.dispose();
    _carFocusNode.dispose();
    super.dispose();
  }

  static List<_ClientOption> _uniqueClientsFromOrders(List<Order> orders) {
    final seen = <String>{};
    final list = <_ClientOption>[];
    for (final o in orders) {
      final name = (o.clientName ?? '').trim();
      final phone = (o.clientPhone ?? '').trim();
      if (name.isEmpty && phone.isEmpty) continue;
      final key = '$name|$phone';
      if (seen.contains(key)) continue;
      seen.add(key);
      list.add(_ClientOption(name: name.isEmpty ? 'Без имени' : name, phone: phone.isEmpty ? null : phone));
    }
    list.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return list;
  }

  /// Занятые слоты на выбранный день по заказам (пересечение по времени 30 мин).
  static Set<String> _occupiedSlotKeys(List<Order> orders, DateTime day, SlotsSettings slots) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final keys = <String>{};
    for (final o in orders) {
      final dt = o.dateTime ?? o.plannedStartTime ?? o.effectiveDateTime;
      final dayO = DateTime(dt.year, dt.month, dt.day);
      if (dayO != dayStart) continue;
      final end = o.plannedEndTime ?? dt.add(Duration(minutes: o.items.fold<int>(0, (s, i) => s + i.estimatedMinutes)));
      var m = dt.hour * 60 + dt.minute;
      final endM = end.hour * 60 + end.minute;
      while (m < endM) {
        final h = m ~/ 60;
        final min = m % 60;
        keys.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
        m += 30;
      }
    }
    return keys;
  }

  /// Список слотов 30 мин от начала до конца рабочего дня.
  static List<DateTime> _timeSlotsForDay(SlotsSettings slots, DateTime day) {
    final startM = slots.startHour * 60 + slots.startMinute;
    final endM = slots.endHour * 60 + slots.endMinute;
    final list = <DateTime>[];
    for (var m = startM; m < endM; m += 30) {
      final h = m ~/ 60;
      final min = m % 60;
      list.add(DateTime(day.year, day.month, day.day, h, min));
    }
    return list;
  }

  void _applyManualTime() {
    final h = int.tryParse(_manualHourController.text) ?? _dateTime.hour;
    final min = int.tryParse(_manualMinuteController.text) ?? _dateTime.minute;
    setState(() {
      _manualTime = true;
      _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, h.clamp(0, 23), min.clamp(0, 59));
      _manualHourController.text = _dateTime.hour.toString();
      _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
    });
  }

  static List<_CarOption> _uniqueCarsFromOrders(List<Order> orders) {
    final seen = <String>{};
    final list = <_CarOption>[];
    for (final o in orders) {
      final key = '${o.carId}|${o.carInfo}';
      if (seen.contains(key) || (o.carInfo.trim().isEmpty)) continue;
      seen.add(key);
      list.add(_CarOption(
        carId: o.carId,
        carInfo: o.carInfo,
        vin: o.vin?.trim().isEmpty == true ? null : o.vin,
        licensePlate: o.licensePlate?.trim().isEmpty == true ? null : o.licensePlate,
      ));
    }
    list.sort((a, b) => a.carInfo.compareTo(b.carInfo));
    return list;
  }

  List<_CarOption> _carsForClientPhone(List<Order> orders, String phoneNorm) {
    if (phoneNorm.isEmpty) return [];
    final seen = <String>{};
    final list = <_CarOption>[];
    for (final o in orders) {
      final p = _qcNormalizePhone(o.clientPhone);
      if (p.isEmpty || p != phoneNorm) continue;
      final key = '${o.carId}|${o.carInfo}';
      if (seen.contains(key) || o.carInfo.trim().isEmpty) continue;
      seen.add(key);
      list.add(_CarOption(
        carId: o.carId,
        carInfo: o.carInfo,
        vin: o.vin?.trim().isEmpty == true ? null : o.vin,
        licensePlate: o.licensePlate?.trim().isEmpty == true ? null : o.licensePlate,
      ));
    }
    list.sort((a, b) => a.carInfo.compareTo(b.carInfo));
    return list;
  }

  String _effectivePhoneNorm() {
    final a = _qcNormalizePhone(_clientPhoneController.text);
    if (a.isNotEmpty) return a;
    return _qcNormalizePhone(_selectedClient?.phone);
  }

  List<_ClientOption> _filterClientsForQuickCreate(List<_ClientOption> all, String phoneRaw, String nameRaw) {
    final phoneQ = _qcNormalizePhone(phoneRaw);
    final nameQ = nameRaw.trim().toLowerCase();
    if (phoneQ.isEmpty && nameQ.isEmpty) return all;
    return all
        .where((c) {
          final cn = _qcNormalizePhone(c.phone);
          final phoneMatch = phoneQ.isNotEmpty && cn.contains(phoneQ);
          final nameMatch = nameQ.isNotEmpty && c.name.toLowerCase().contains(nameQ);
          return phoneMatch || nameMatch;
        })
        .toList();
  }

  void _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _manualHourController.text = _dateTime.hour.toString();
      _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
      _manualTime = false;
    });
  }

  void _toggleService(ServiceItem s) {
    setState(() {
      if (_selectedServices.any((e) => e.id == s.id)) {
        _selectedServices.removeWhere((e) => e.id == s.id);
      } else {
        _selectedServices.add(s);
      }
    });
  }

  void _addCustomItem(String name, int minutes, int priceKopecks) {
    setState(() {
      _customItems.add(OrderItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        priceKopecks: priceKopecks,
        estimatedMinutes: minutes,
      ));
    });
  }

  void _removeCustomItem(int index) {
    setState(() => _customItems.removeAt(index));
  }

  void _showAddCustomItemDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int minutes = 30;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Позиция от руки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Отмыть рабочую зону',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: minutes,
                decoration: const InputDecoration(labelText: 'Время, мин'),
                items: [15, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m мин'))).toList(),
                onChanged: (v) => setDialogState(() => minutes = v ?? 30),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Цена, ₽', hintText: '1000'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final priceRub = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
                final priceKopecks = (priceRub * 100).round();
                _addCustomItem(name, minutes, priceKopecks);
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final items = _selectedServices
        .map((s) => OrderItem(
              id: s.id,
              name: s.name,
              priceKopecks: s.priceKopecks,
              estimatedMinutes: s.durationMinutes,
            ))
        .toList();
    items.addAll(_customItems);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну позицию в состав проекта')),
      );
      return;
    }
    setState(() => _saving = true);

    String carId;
    String carInfo;
    final knownCars = _uniqueCarsFromOrders(ref.read(orderRepositoryProvider));
    final catalogForNew = ref.read(quickOrderCatalogPicksProvider).valueOrNull ?? [];
    final composedNew = !_carFromList
        ? composeNewVehicleForOrder(
            structured: _newCarStructured,
            brand: _newBrandController.text,
            model: _newModelController.text,
            generation: _newGenerationController.text,
            freeLine: _carInfoController.text,
            explicitPlateRaw: _newCarPlateController.text,
            catalog: catalogForNew,
          )
        : null;

    if (_carFromList && _selectedCar != null) {
      final sid = _selectedCar!.carId;
      if (sid.startsWith('catalog:')) {
        carId = 'new_${DateTime.now().millisecondsSinceEpoch}';
        carInfo = _selectedCar!.carInfo;
      } else {
        carId = sid;
        carInfo = _selectedCar!.carInfo;
      }
    } else if (_carFromList && knownCars.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите авто из списка или укажите новую')),
      );
      setState(() => _saving = false);
      return;
    } else {
      final c = composedNew!;
      carInfo = c.carInfo.trim().isEmpty ? 'Автомобиль' : c.carInfo.trim();
      carId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    }

    String? orderVin;
    String? orderPlate;
    String? orderColor;
    int? orderMileage;
    if (_carFromList && _selectedCar != null && !_selectedCar!.carId.startsWith('catalog:')) {
      orderVin = _selectedCar!.vin;
      orderPlate = _selectedCar!.licensePlate;
    } else {
      final v = _newCarVinController.text.trim();
      final p = _newCarPlateController.text.trim();
      final c = _newCarColorController.text.trim();
      final m = int.tryParse(_newCarMileageController.text.replaceAll(' ', ''));
      orderVin = v.isEmpty ? null : v;
      if (!_carFromList) {
        final expPlate = normalizePlateInput(p);
        orderPlate = composedNew?.licensePlate ?? (isValidRussianPlateCompact(expPlate) ? expPlate : null);
      } else {
        orderPlate = p.isEmpty ? null : p;
      }
      orderColor = c.isEmpty ? null : c;
      orderMileage = m;
    }

    final order = Order(
      id: '',
      orderNumber: '',
      carId: carId,
      clientName: _clientNameController.text.trim().isEmpty ? null : _clientNameController.text.trim(),
      clientPhone: _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
      carInfo: carInfo,
      vin: orderVin,
      licensePlate: orderPlate,
      color: orderColor,
      mileage: orderMileage,
      status: OrderStatus.pendingConfirmation,
      dateTime: _dateTime,
      items: items,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      bayId: _selectedBayId,
    );

    final repo = ref.read(orderRepositoryProvider.notifier);
    Order addedOrder;
    try {
      addedOrder = await repo.addOrderAsync(order);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать заказ'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_selectedMaster != null) {
      await repo.assignMaster(addedOrder.id, _selectedMaster!);
      await ref.read(orderRepositoryProvider.notifier).refreshOrder(addedOrder.id);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Заказ ${addedOrder.orderNumber} создан'), backgroundColor: _success),
    );
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: addedOrder.id)),
      );
    }
  }

  List<OrderItem> get _allItems {
    final list = _selectedServices
        .map((s) => OrderItem(
              id: s.id,
              name: s.name,
              priceKopecks: s.priceKopecks,
              estimatedMinutes: s.durationMinutes,
            ))
        .toList();
    list.addAll(_customItems);
    return list;
  }

  int get _totalMinutes => _allItems.fold(0, (s, i) => s + i.estimatedMinutes);
  int get _totalKopecks => _allItems.fold(0, (s, i) => s + (i.priceKopecks ?? 0));

  bool get _isMobile => !isDesktopPlatform;
  double get _pagePadding => _isMobile ? 16 : DesktopDesignSystem.pagePadding;
  double get _cardRadius => _isMobile ? 12 : DesktopDesignSystem.radiusCardLarge;
  Color get _bg => _isMobile ? AppColors.background : AppColorsDesktop.background;
  Color get _surface => _isMobile ? AppColors.surface : AppColorsDesktop.surface;
  Color get _cardBorder => _isMobile ? AppColors.border : AppColorsDesktop.borderLight;
  Color get _textPrimary => _isMobile ? AppColors.textPrimary : AppColorsDesktop.textPrimary;
  Color get _textSecondary => _isMobile ? AppColors.textSecondary : AppColorsDesktop.textSecondary;
  Color get _textTertiary => _isMobile ? AppColors.textTertiary : AppColorsDesktop.textTertiary;
  Color get _primary => _isMobile ? AppColors.primary : AppColorsDesktop.primary;
  Color get _success => _isMobile ? AppColors.success : AppColorsDesktop.success;
  Color get _error => _isMobile ? AppColors.error : AppColorsDesktop.error;
  Color get _nestedBg => _isMobile ? AppColors.nestedBg : AppColorsDesktop.nestedBg;
  Color get _accentMoney => _isMobile ? AppColors.primary : AppColorsDesktop.accentMoney;
  Color get _accentMoneyLight => _isMobile ? AppColors.primary.withValues(alpha: 0.15) : AppColorsDesktop.accentMoneyLight;
  Color get _statusInProgress => _isMobile ? AppColors.statusInProgress : AppColorsDesktop.statusInProgress;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    final allServices = settings.services;
    final slots = settings.slotsSettings;
    final orders = ref.watch(orderRepositoryProvider);
    final catalogAsync = ref.watch(quickOrderCatalogPicksProvider);
    final catalogPicks = catalogAsync.valueOrNull ?? [];
    final allCars = _uniqueCarsFromOrders(orders);
    final phoneNorm = _effectivePhoneNorm();
    final clientCars = _carsForClientPhone(orders, phoneNorm);
    final clientCarIds = clientCars.map((c) => c.carId).toSet();
    final otherCars = allCars.where((c) => !clientCarIds.contains(c.carId)).toList();
    final allClients = _uniqueClientsFromOrders(orders);
    final filteredClients =
        _filterClientsForQuickCreate(allClients, _clientPhoneController.text, _clientNameController.text);
    final orgAsync = ref.watch(organizationProvider);
    final bayBased = orgAsync.valueOrNull?.schedulingMode == 'bay_based';
    final showBayPicker = slots.hasNamedBays && bayBased;
    final staff = ref.watch(staffListProvider);
    final timeSlots = _timeSlotsForDay(slots, _dateTime);
    final occupiedSlots = _occupiedSlotKeys(orders, _dateTime, slots);

    final body = LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final useWide = width >= 900 && isDesktopPlatform;
          if (!useWide) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(_pagePadding),
              child: _buildSingleColumn(
                settings.services,
                allCars,
                clientCars,
                otherCars,
                catalogPicks,
                allClients,
                filteredClients,
                staff,
                slots,
                timeSlots,
                occupiedSlots,
                showBayPicker,
              ),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(_pagePadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: _buildLeftColumn(
                    allCars,
                    clientCars,
                    otherCars,
                    catalogPicks,
                    allClients,
                    filteredClients,
                    slots,
                    showBayPicker,
                  ),
                ),
                const SizedBox(width: DesktopDesignSystem.blockSpacing),
                Expanded(
                  flex: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildCenterColumn(allServices),
                  ),
                ),
                const SizedBox(width: DesktopDesignSystem.blockSpacing),
                SizedBox(width: 320, child: _buildRightColumn(staff, slots, timeSlots, occupiedSlots)),
              ],
            ),
          );
        },
      );
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text('Создать заказ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isMobile
          ? Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: ColorScheme.dark(
                  primary: _primary,
                  surface: _surface,
                  onSurface: _textPrimary,
                  onPrimary: Colors.white,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  hintStyle: TextStyle(color: AppColors.textPlaceholder),
                  labelStyle: TextStyle(color: _textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primary)),
                ),
              ),
              child: body,
            )
          : body,
    );
  }

  Widget _buildSingleColumn(
    List<ServiceItem> allServices,
    List<_CarOption> allCars,
    List<_CarOption> clientCars,
    List<_CarOption> otherCars,
    List<QuickRefCarPick> catalogPicks,
    List<_ClientOption> allClients,
    List<_ClientOption> filteredClients,
    List<StaffMember> staff,
    SlotsSettings slots,
    List<DateTime> timeSlots,
    Set<String> occupiedSlots,
    bool showBayPicker,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLeftColumn(
            allCars,
            clientCars,
            otherCars,
            catalogPicks,
            allClients,
            filteredClients,
            slots,
            showBayPicker,
          ),
          const SizedBox(height: 24),
          _buildCenterColumn(allServices),
          const SizedBox(height: 24),
          _buildRightColumn(staff, slots, timeSlots, occupiedSlots),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: _primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
      ],
    );
  }

  StaffMember? _findMasterInList(List<StaffMember> staff) {
    if (_selectedMaster == null) return null;
    for (final m in staff) {
      if (m.id == _selectedMaster!.id) return m;
    }
    return null;
  }

  Widget _buildLeftColumn(
    List<_CarOption> allCars,
    List<_CarOption> clientCars,
    List<_CarOption> otherCars,
    List<QuickRefCarPick> catalogPicks,
    List<_ClientOption> allClients,
    List<_ClientOption> filteredClients,
    SlotsSettings slots,
    bool showBayPicker,
  ) {
    final phoneQuery = _qcNormalizePhone(_clientPhoneController.text);
    final carSearch = _carSearchController.text;
    final filteredClientCars = clientCars.where((c) => _qcCarMatchesSearch(c, carSearch)).toList();
    final filteredOtherCars = otherCars.where((c) => _qcCarMatchesSearch(c, carSearch)).toList();
    final qCat = carSearch.trim().toLowerCase();
    final filteredCatalogCars = catalogPicks
        .where((p) {
          if (qCat.length < 2) return false;
          final l = p.label.toLowerCase();
          return l.contains(qCat) || p.modelName.toLowerCase().startsWith(qCat);
        })
        .take(50)
        .map(
          (p) => _CarOption(
            carId: p.catalogCarId,
            carInfo: p.label,
            vin: null,
            licensePlate: null,
          ),
        )
        .toList();
    final newCarQuery = _carInfoController.text.trim().toLowerCase();
    final newCarSuggestions = !_carFromList && catalogPicks.isNotEmpty && newCarQuery.length >= 2
        ? catalogPicks
            .where((p) {
              final l = p.label.toLowerCase();
              return l.contains(newCarQuery) || p.modelName.toLowerCase().startsWith(newCarQuery);
            })
            .take(8)
            .toList()
        : const <QuickRefCarPick>[];
    final showClientPicker = _clientPickerPinned && filteredClients.isNotEmpty;
    final bayIds = slots.bays.map((b) => b.id).toSet();
    final bayDropdownValue = _selectedBayId != null && bayIds.contains(_selectedBayId) ? _selectedBayId : null;

    InputDecoration fieldDeco(String label, {String? hint, Widget? prefix}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_isMobile ? 10 : 8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_isMobile ? 10 : 8),
          borderSide: BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_isMobile ? 10 : 8),
          borderSide: BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
    }

    Widget carTile(_CarOption c) {
      final selected = _selectedCar != null && _selectedCar == c;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected ? _primary.withValues(alpha: 0.12) : _nestedBg,
          borderRadius: BorderRadius.circular(_isMobile ? 10 : 8),
          child: InkWell(
            onTap: () => setState(() {
              _selectedCar = c;
              _carFocusNode.unfocus();
            }),
            borderRadius: BorderRadius.circular(_isMobile ? 10 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_isMobile ? 10 : 8),
                border: Border.all(color: selected ? _primary : _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.carInfo,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                            fontSize: _isMobile ? 14 : 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle_rounded, size: 20, color: _primary),
                    ],
                  ),
                  if (c.vin != null && c.vin!.isNotEmpty || c.licensePlate != null && c.licensePlate!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (c.licensePlate != null && c.licensePlate!.isNotEmpty) c.licensePlate!,
                          if (c.vin != null && c.vin!.isNotEmpty) 'VIN ${c.vin}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: _isMobile ? null : DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.person_outline_rounded, 'Клиент'),
          const SizedBox(height: 10),
          TapRegion(
            onTapOutside: (_) => setState(() => _clientPickerPinned = false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _clientPhoneController,
                  focusNode: _clientPhoneFocusNode,
                  keyboardType: TextInputType.phone,
                  onTap: () => setState(() => _clientPickerPinned = true),
                  onChanged: (_) {
                    if (_selectedClient != null &&
                        _qcNormalizePhone(_selectedClient!.phone) != _qcNormalizePhone(_clientPhoneController.text)) {
                      setState(() => _selectedClient = null);
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: fieldDeco(
                    'Телефон',
                    hint: '+7 900 000-00-00',
                    prefix: Icon(Icons.phone_rounded, size: 20, color: _textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _clientNameController,
                  focusNode: _clientNameFocusNode,
                  onTap: () => setState(() => _clientPickerPinned = true),
                  onChanged: (_) {
                    if (_selectedClient != null && _clientNameController.text.trim() != _selectedClient!.name) {
                      setState(() => _selectedClient = null);
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: fieldDeco(
                    'Имя',
                    hint: 'Как обращаться',
                    prefix: Icon(Icons.badge_outlined, size: 20, color: _textSecondary),
                  ),
                ),
                if (showClientPicker) ...[
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: _isMobile ? 200 : 220),
                    child: Material(
                      elevation: _isMobile ? 6 : 4,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      color: _surface,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: filteredClients.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: _cardBorder),
                        itemBuilder: (context, i) {
                          final c = filteredClients[i];
                          final cn = _qcNormalizePhone(c.phone);
                          final phoneHit = phoneQuery.isNotEmpty && cn.contains(phoneQuery);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _clientPickerPinned = false;
                                _selectedClient = c;
                                _clientNameController.text = c.name;
                                _clientPhoneController.text = c.phone ?? '';
                                _clientPhoneFocusNode.unfocus();
                                _clientNameFocusNode.unfocus();
                              });
                            },
                            child: Container(
                              color: phoneHit ? _primary.withValues(alpha: 0.1) : null,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                                  if (c.phone != null && c.phone!.isNotEmpty)
                                    Text(
                                      c.phone!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: phoneHit ? FontWeight.w700 : FontWeight.w500,
                                        color: phoneHit ? _primary : _textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(Icons.directions_car_rounded, 'Автомобиль'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _carFromList,
                    onChanged: (v) => setState(() {
                      _carFromList = true;
                      _carInfoController.clear();
                      _resetNewCarStructured();
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    fillColor: WidgetStateProperty.resolveWith((_) => _primary),
                  ),
                  Text('Из базы', style: TextStyle(color: _textPrimary, fontSize: _isMobile ? 14 : 13)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: _carFromList,
                    onChanged: (v) => setState(() {
                      _carFromList = false;
                      _selectedCar = null;
                      _resetNewCarStructured();
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    fillColor: WidgetStateProperty.resolveWith((_) => _primary),
                  ),
                  Text('Новая машина', style: TextStyle(color: _textPrimary, fontSize: _isMobile ? 14 : 13)),
                ],
              ),
            ],
          ),
          if (_carFromList) ...[
            const SizedBox(height: 8),
            if (clientCars.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Сначала автомобили выбранного клиента (по телефону), затем остальные из базы.',
                  style: TextStyle(fontSize: 11, height: 1.25, color: _textTertiary),
                ),
              ),
            TextField(
              controller: _carSearchController,
              focusNode: _carFocusNode,
              onChanged: (_) => setState(() {}),
              decoration: fieldDeco(
                'Поиск авто',
                hint: 'Марка, модель, госномер или VIN',
                prefix: Icon(Icons.search_rounded, size: 20, color: _textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: _isMobile ? 220 : 280),
              child: Scrollbar(
                thumbVisibility: isDesktopPlatform,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (filteredClientCars.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Автомобили клиента',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                        ),
                      ),
                      ...filteredClientCars.map(carTile),
                      if (filteredOtherCars.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Divider(color: _cardBorder),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (filteredOtherCars.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          filteredClientCars.isNotEmpty ? 'Другие по заказам' : 'Автомобили по заказам',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary),
                        ),
                      ),
                      ...filteredOtherCars.map(carTile),
                    ],
                    if (filteredCatalogCars.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Divider(color: _cardBorder),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Справочник марок и моделей',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                        ),
                      ),
                      Text(
                        qCat.length < 2
                            ? 'Введите минимум 2 символа в поиске авто, чтобы показать варианты из справочника.'
                            : 'Выбор создаёт новое авто с этой маркой/моделью в заказе.',
                        style: TextStyle(fontSize: 11, height: 1.25, color: _textTertiary),
                      ),
                      const SizedBox(height: 6),
                      ...filteredCatalogCars.map(carTile),
                    ],
                    if (filteredClientCars.isEmpty && filteredOtherCars.isEmpty && filteredCatalogCars.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          allCars.isEmpty
                              ? 'Пока нет сохранённых авто — выберите «Новая машина».'
                              : 'Ничего не найдено — измените поиск или добавьте новую машину.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Новая машина будет привязана к клиенту в этом заказе (телефон и имя выше). Можно ввести строкой или выбрать подсказку из справочника.',
              style: TextStyle(fontSize: 11, height: 1.25, color: _textTertiary),
            ),
            const SizedBox(height: 8),
            if (!_newCarStructured) ...[
              TextField(
                controller: _carInfoController,
                onChanged: (_) => setState(() {}),
                decoration: fieldDeco(
                  'Марка, модель, госномер или текст',
                  hint: 'Например: Camry или Toyota Camry А123АА777',
                ),
              ),
              if (newCarSuggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Подсказки из справочника', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textSecondary)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Material(
                    color: _nestedBg,
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: newCarSuggestions.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: _cardBorder),
                      itemBuilder: (ctx, i) {
                        final p = newCarSuggestions[i];
                        return InkWell(
                          onTap: () => _applyCatalogSuggestion(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(p.label, style: TextStyle(fontSize: 13, color: _textPrimary)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(_resetNewCarStructured),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Ввести одной строкой'),
                ),
              ),
              TextField(
                controller: _newBrandController,
                onChanged: (_) => setState(() {}),
                decoration: fieldDeco('Марка', hint: 'Toyota'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newModelController,
                onChanged: (_) => setState(() {}),
                decoration: fieldDeco('Модель', hint: 'Camry'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newGenerationController,
                decoration: fieldDeco('Поколение (необязательно)', hint: 'XV70, рестайлинг…'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _carInfoController,
                onChanged: (_) => setState(() {}),
                decoration: fieldDeco(
                  'Дополнительно к названию (необязательно)',
                  hint: 'Цвет, примечание или номер в строке',
                ),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _newCarExpanded = !_newCarExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _cardBorder),
                  borderRadius: BorderRadius.circular(8),
                  color: _nestedBg,
                ),
                child: Row(
                  children: [
                    Icon(_newCarExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _newCarExpanded ? 'Свернуть: VIN, госномер, цвет, пробег' : 'VIN, госномер, цвет, пробег',
                        style: TextStyle(fontSize: 13, color: _primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_newCarExpanded) ...[
              const SizedBox(height: 8),
              Text(
                'Госномер РФ: буква $kRussianPlateLetters · 3 цифры · 2 буквы · 3 цифры (9 символов).',
                style: TextStyle(fontSize: 10, height: 1.3, color: _textTertiary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCarVinController,
                decoration: fieldDeco('VIN'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCarPlateController,
                decoration: fieldDeco('Гос. номер', hint: 'А123АА777'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCarColorController,
                decoration: fieldDeco('Цвет'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCarMileageController,
                decoration: fieldDeco('Пробег, км'),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
          if (showBayPicker) ...[
            const SizedBox(height: 20),
            _sectionHeader(Icons.garage_outlined, 'Пост / бокс'),
            const SizedBox(height: 8),
            Text(
              'Режим расписания «По постам». Можно выбрать пост или оставить автоназначение.',
              style: TextStyle(fontSize: 11, color: _textTertiary),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: bayDropdownValue,
              isExpanded: true,
              decoration: fieldDeco('Пост'),
              hint: const Text('Авто — свободный пост'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Не выбрано (свободный пост)'),
                ),
                ...slots.bays.map(
                  (b) => DropdownMenuItem<String?>(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedBayId = v),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: fieldDeco('Комментарий'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterColumn(List<ServiceItem> allServices) {
    final totalMin = _totalMinutes;
    final totalKop = _totalKopecks;
    final settings = ref.read(settingsRepositoryProvider);
    final categories = List<ServiceCategory>.from(settings.categories)..sort((a, b) => a.order.compareTo(b.order));
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final categoryIds = categories.map((c) => c.id).toSet();
    final servicesWithoutCategory = allServices.where((s) => !categoryIds.contains(s.categoryId)).toList();

    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: _isMobile ? null : DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.assignment_rounded, 'Состав проекта'),
          const SizedBox(height: 12),
          SizedBox(
            height: _isMobile ? 300 : 360,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(right: 4),
              children: [
                for (final cat in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  ...repo.servicesForCategory(cat.id).map((s) {
                    final selected = _selectedServices.any((e) => e.id == s.id);
                    return Material(
                      color: selected ? _primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggleService(s),
                        title: Text(s.name, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: _textPrimary)),
                        subtitle: Text('${formatMoney(s.priceKopecks)} • ${s.durationMinutes} мин', style: TextStyle(fontSize: 12, color: _textSecondary)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  }),
                ],
                if (servicesWithoutCategory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Прочее',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  ...servicesWithoutCategory.map((s) {
                    final selected = _selectedServices.any((e) => e.id == s.id);
                    return Material(
                      color: selected ? _primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggleService(s),
                        title: Text(s.name, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: _textPrimary)),
                        subtitle: Text('${formatMoney(s.priceKopecks)} • ${s.durationMinutes} мин', style: TextStyle(fontSize: 12, color: _textSecondary)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  }),
                ],
                OutlinedButton.icon(
                  onPressed: _showAddCustomItemDialog,
                  icon: Icon(Icons.add, size: 18, color: _primary),
                  label: Text('Позиция от руки', style: TextStyle(color: _primary)),
                  style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: _primary, side: BorderSide(color: _primary)),
                ),
                if (_customItems.isNotEmpty)
                  ..._customItems.asMap().entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accentMoneyLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _accentMoney.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.value.name, style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimary)),
                                  Text('${e.value.estimatedMinutes} мин • ${formatMoney(e.value.priceKopecks ?? 0)}', style: TextStyle(fontSize: 12, color: _textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: _textSecondary),
                              onPressed: () => _removeCustomItem(e.key),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _statusInProgress.withValues(alpha: 0.15),
                  _accentMoneyLight,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(_isMobile ? 12 : DesktopDesignSystem.radiusButton),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: _statusInProgress),
                      const SizedBox(width: 6),
                      Text('Время: ', style: TextStyle(fontSize: 12, color: _textSecondary)),
                      Flexible(
                        child: Text(
                          formatDurationMinutes(totalMin),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _statusInProgress),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Сумма: ', style: TextStyle(fontSize: 12, color: _textSecondary)),
                      Flexible(
                        child: Text(
                          formatMoney(totalKop),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _accentMoney),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(List<StaffMember> staff, SlotsSettings slots, List<DateTime> timeSlots, Set<String> occupiedSlots) {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: _isMobile ? null : DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.schedule_rounded, 'Время и мастер'),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: _nestedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 20, color: _textSecondary),
                  const SizedBox(width: 10),
                  Text(formatDate(_dateTime), style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                  const SizedBox(width: 12),
                  Text(formatTime(_dateTime), style: TextStyle(fontWeight: FontWeight.w600, color: _primary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Сетка времени', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary)),
              const SizedBox(width: 8),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _success.withValues(alpha: 0.6), shape: BoxShape.circle)),
              Text(' свободно', style: TextStyle(fontSize: 10, color: _textTertiary)),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _error.withValues(alpha: 0.6), shape: BoxShape.circle)),
              Text(' занято', style: TextStyle(fontSize: 10, color: _textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...timeSlots.map((slot) {
                final key = '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                final isOccupied = occupiedSlots.contains(key);
                final isSelected = _dateTime.hour == slot.hour && _dateTime.minute == slot.minute && !_manualTime;
                final Color bg = isSelected
                    ? _primary
                    : isOccupied
                        ? _error.withValues(alpha: 0.2)
                        : _success.withValues(alpha: 0.15);
                final Color border = isSelected
                    ? _primary
                    : isOccupied
                        ? _error
                        : _success.withValues(alpha: 0.6);
                final Color textColor = isSelected
                    ? Colors.white
                    : isOccupied
                        ? _error
                        : _textPrimary;
                return GestureDetector(
                  onTap: isOccupied
                      ? null
                      : () {
                          setState(() {
                            _manualTime = false;
                            _dateTime = slot;
                            _manualHourController.text = slot.hour.toString();
                            _manualMinuteController.text = slot.minute.toString().padLeft(2, '0');
                          });
                        },
                  child: Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualHourController,
                  decoration: const InputDecoration(
                    labelText: 'Час',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _applyManualTime(),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(
                child: TextField(
                  controller: _manualMinuteController,
                  decoration: const InputDecoration(
                    labelText: 'Мин',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _applyManualTime(),
                ),
              ),
              const SizedBox(width: 8),
              Text('вручную', style: TextStyle(fontSize: 12, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Мастер', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<StaffMember?>(
            value: _findMasterInList(staff),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Можно назначить позже'),
            items: [
              const DropdownMenuItem<StaffMember?>(value: null, child: Text('— Не назначен')),
              ...staff.map((m) => DropdownMenuItem<StaffMember?>(value: m, child: Text(m.name))),
            ],
            onChanged: (v) => setState(() => _selectedMaster = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
            ),
            child: _saving
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Создать заказ'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
