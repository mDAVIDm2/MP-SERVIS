import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/russian_plate_utils.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../orders/application/order_creation_drafts_notifier.dart';
import '../../../orders/domain/order_creation_draft.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final OrderCreationDraft? resumeDraft;

  const CreateOrderScreen({super.key, this.initialDate, this.resumeDraft});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

String _normalizePhone(String? phone) {
  if (phone == null) return '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) return '7${digits.substring(1)}';
  return digits;
}

class _CarPick {
  final String carId;
  final String carInfo;
  final String? vin;
  final String? licensePlate;

  const _CarPick({
    required this.carId,
    required this.carInfo,
    this.vin,
    this.licensePlate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CarPick && other.carId == carId && other.carInfo == carInfo);

  @override
  int get hashCode => Object.hash(carId, carInfo);
}

bool _carPickMatches(_CarPick c, String query) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) return true;
  String normPlate(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');
  final qPlate = normPlate(t);
  return c.carInfo.toLowerCase().contains(t) ||
      (c.vin ?? '').toLowerCase().contains(t) ||
      normPlate(c.licensePlate ?? '').contains(qPlate);
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  late DateTime _dateTime;
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _carSearchController = TextEditingController();
  final _carInfoController = TextEditingController();
  final _vinController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _bodyTypeController = TextEditingController();
  final _colorController = TextEditingController();
  final _mileageController = TextEditingController();
  final _engineTypeController = TextEditingController();
  final _commentController = TextEditingController();
  final _selectedServices = <ServiceItem>[];
  final _customItems = <OrderItem>[];
  bool _carFromList = true;
  _CarPick? _pickedCar;
  String? _selectedBayId;
  String? _linkedDraftId;
  bool _saveSucceeded = false;

  @override
  void initState() {
    super.initState();
    DateTime initial;
    if (widget.resumeDraft != null) {
      final ds = widget.resumeDraft!.data['dateTime'] as String?;
      final parsed = ds != null ? DateTime.tryParse(ds) : null;
      initial = parsed ?? widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    } else {
      initial = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    }
    _dateTime = initial;
    if (_dateTime.hour == 0 && _dateTime.minute == 0) {
      _dateTime = _dateTime.copyWith(hour: 9, minute: 0);
    }
    if (widget.resumeDraft != null) {
      _linkedDraftId = widget.resumeDraft!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final d = widget.resumeDraft;
        if (d != null && d.source == OrderCreationDraft.kSourceCalendar) {
          _applyCalendarDraftData(d.data);
        }
      });
    }
  }

  void _applyCalendarDraftData(Map<String, dynamic> m) {
    final v = m['v'];
    if (v is! num || v.toInt() != 1) return;
    final settings = ref.read(settingsRepositoryProvider);
    final byId = {for (final s in settings.services) s.id: s};
    final ids = (m['selectedServiceIds'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final selected = <ServiceItem>[];
    for (final id in ids) {
      final s = byId[id];
      if (s != null) selected.add(s);
    }
    final customRaw = m['customItems'] as List?;
    final customs = <OrderItem>[];
    if (customRaw != null) {
      for (var i = 0; i < customRaw.length; i++) {
        final e = customRaw[i];
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        customs.add(OrderItem(
          id: 'draft_cal_${i}_${map['name']}',
          name: map['name'] as String? ?? '',
          priceKopecks: (map['priceKopecks'] as num?)?.toInt() ?? 0,
          estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 60,
        ));
      }
    }
    final dtStr = m['dateTime'] as String?;
    final dt = dtStr != null ? DateTime.tryParse(dtStr) : null;
    setState(() {
      if (dt != null) {
        _dateTime = dt;
      }
      _carFromList = m['carFromList'] as bool? ?? true;
      _clientNameController.text = m['clientName'] as String? ?? '';
      _clientPhoneController.text = m['clientPhone'] as String? ?? '';
      _carSearchController.text = m['carSearch'] as String? ?? '';
      _carInfoController.text = m['carInfo'] as String? ?? '';
      _vinController.text = m['vin'] as String? ?? '';
      _licensePlateController.text = m['licensePlate'] as String? ?? '';
      _bodyTypeController.text = m['bodyType'] as String? ?? '';
      _colorController.text = m['color'] as String? ?? '';
      _mileageController.text = m['mileage'] as String? ?? '';
      _engineTypeController.text = m['engineType'] as String? ?? '';
      _commentController.text = m['comment'] as String? ?? '';
      _selectedServices.clear();
      _selectedServices.addAll(selected);
      _customItems.clear();
      _customItems.addAll(customs);
      _selectedBayId = m['bayId'] as String?;
      final pk = m['pickedCar'];
      if (pk is Map) {
        final cm = Map<String, dynamic>.from(pk);
        _pickedCar = _CarPick(
          carId: cm['carId'] as String? ?? '',
          carInfo: cm['carInfo'] as String? ?? '',
          vin: cm['vin'] as String?,
          licensePlate: cm['licensePlate'] as String?,
        );
      } else {
        _pickedCar = null;
      }
    });
  }

  Map<String, dynamic> _calendarDraftSnapshot() {
    return {
      'v': 1,
      'dateTime': _dateTime.toIso8601String(),
      'clientName': _clientNameController.text,
      'clientPhone': _clientPhoneController.text,
      'carSearch': _carSearchController.text,
      'carInfo': _carInfoController.text,
      'vin': _vinController.text,
      'licensePlate': _licensePlateController.text,
      'bodyType': _bodyTypeController.text,
      'color': _colorController.text,
      'mileage': _mileageController.text,
      'engineType': _engineTypeController.text,
      'comment': _commentController.text,
      'carFromList': _carFromList,
      'pickedCar': _pickedCar == null
          ? null
          : {
              'carId': _pickedCar!.carId,
              'carInfo': _pickedCar!.carInfo,
              'vin': _pickedCar!.vin,
              'licensePlate': _pickedCar!.licensePlate,
            },
      'selectedServiceIds': _selectedServices.map((s) => s.id).toList(),
      'customItems': _customItems
          .map((i) => {
                'name': i.name,
                'priceKopecks': i.priceKopecks,
                'estimatedMinutes': i.estimatedMinutes,
              })
          .toList(),
      'bayId': _selectedBayId,
    };
  }

  bool _shouldSaveCalendarDraft() {
    if (_saveSucceeded) return false;
    if (_clientNameController.text.trim().isNotEmpty) return true;
    if (_clientPhoneController.text.trim().isNotEmpty) return true;
    if (_carInfoController.text.trim().isNotEmpty ||
        _carSearchController.text.trim().isNotEmpty ||
        _vinController.text.trim().isNotEmpty ||
        _licensePlateController.text.trim().isNotEmpty ||
        _bodyTypeController.text.trim().isNotEmpty ||
        _colorController.text.trim().isNotEmpty ||
        _mileageController.text.trim().isNotEmpty ||
        _engineTypeController.text.trim().isNotEmpty) {
      return true;
    }
    if (_commentController.text.trim().isNotEmpty) return true;
    if (_selectedServices.isNotEmpty || _customItems.isNotEmpty) return true;
    if (_pickedCar != null) return true;
    if (_selectedBayId != null && _selectedBayId!.trim().isNotEmpty) return true;
    return false;
  }

  @override
  void dispose() {
    if (!_saveSucceeded) {
      if (_shouldSaveCalendarDraft()) {
        final snap = _calendarDraftSnapshot();
        final existing = _linkedDraftId;
        Future(() async {
          try {
            await ref.read(orderCreationDraftsProvider.notifier).upsertFromSnapshot(
                  existingId: existing,
                  source: OrderCreationDraft.kSourceCalendar,
                  data: snap,
                );
          } catch (_) {}
        });
      } else if (_linkedDraftId != null) {
        final rid = _linkedDraftId!;
        Future(() async {
          try {
            await ref.read(orderCreationDraftsProvider.notifier).remove(rid);
          } catch (_) {}
        });
      }
    }
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _carSearchController.dispose();
    _carInfoController.dispose();
    _vinController.dispose();
    _licensePlateController.dispose();
    _bodyTypeController.dispose();
    _colorController.dispose();
    _mileageController.dispose();
    _engineTypeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  List<_CarPick> _uniqueCarPicks(List<Order> orders) {
    final seen = <String>{};
    final list = <_CarPick>[];
    for (final o in orders) {
      final key = '${o.carId}|${o.carInfo}';
      if (seen.contains(key) || o.carInfo.trim().isEmpty) continue;
      seen.add(key);
      list.add(_CarPick(
        carId: o.carId,
        carInfo: o.carInfo,
        vin: o.vin?.trim().isEmpty == true ? null : o.vin,
        licensePlate: o.licensePlate?.trim().isEmpty == true ? null : o.licensePlate,
      ));
    }
    list.sort((a, b) => a.carInfo.compareTo(b.carInfo));
    return list;
  }

  List<_CarPick> _clientCarPicks(List<Order> orders, String phoneNorm) {
    if (phoneNorm.isEmpty) return [];
    final seen = <String>{};
    final list = <_CarPick>[];
    for (final o in orders) {
      final p = _normalizePhone(o.clientPhone);
      if (p.isEmpty || p != phoneNorm) continue;
      final key = '${o.carId}|${o.carInfo}';
      if (seen.contains(key) || o.carInfo.trim().isEmpty) continue;
      seen.add(key);
      list.add(_CarPick(
        carId: o.carId,
        carInfo: o.carInfo,
        vin: o.vin?.trim().isEmpty == true ? null : o.vin,
        licensePlate: o.licensePlate?.trim().isEmpty == true ? null : o.licensePlate,
      ));
    }
    list.sort((a, b) => a.carInfo.compareTo(b.carInfo));
    return list;
  }

  void _applyPickedCar(_CarPick c) {
    _pickedCar = c;
    _carInfoController.text = c.carInfo;
    _vinController.text = c.vin ?? '';
    _licensePlateController.text = c.licensePlate ?? '';
  }

  void _clearCarFieldsForNew() {
    _carInfoController.clear();
    _vinController.clear();
    _licensePlateController.clear();
    _bodyTypeController.clear();
    _colorController.clear();
    _mileageController.clear();
    _engineTypeController.clear();
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

  void _showAddCustomItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int minutes = 30;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Позиция от руки', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Отмыть рабочую зону',
                ),
                style: const TextStyle(color: AppColors.textPrimary),
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
                style: const TextStyle(color: AppColors.textPrimary),
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
    final clientName = _clientNameController.text.trim();
    final carInfo = _carInfoController.text.trim();
    if (clientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя клиента'), backgroundColor: AppColors.cardBg),
      );
      return;
    }
    if (_carFromList && carInfo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите автомобиль или выберите из списка'), backgroundColor: AppColors.cardBg),
      );
      return;
    }
    final items = <OrderItem>[
      ..._selectedServices.map(
        (s) => OrderItem(
          id: s.id,
          name: s.name,
          priceKopecks: s.priceKopecks,
          estimatedMinutes: s.durationMinutes,
          serviceId: s.id,
          catalogItemId: s.catalogItemId,
        ),
      ),
      ..._customItems,
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите услуги или добавьте позицию от руки'), backgroundColor: AppColors.cardBg),
      );
      return;
    }

    final mileageVal = int.tryParse(_mileageController.text.trim());
    final catalogForNew = ref.read(quickOrderCatalogPicksProvider).valueOrNull ?? [];
    String useCarId;
    String resolvedCarInfo = carInfo;
    String? resolvedPlate = _licensePlateController.text.trim().isEmpty ? null : _licensePlateController.text.trim();
    if (_carFromList && _pickedCar != null) {
      if (_pickedCar!.carId.startsWith('catalog:')) {
        useCarId = 'new_${DateTime.now().millisecondsSinceEpoch}';
        resolvedCarInfo = _pickedCar!.carInfo;
      } else {
        useCarId = _pickedCar!.carId;
      }
    } else if (_carFromList) {
      final all = _uniqueCarPicks(ref.read(orderRepositoryProvider));
      if (all.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите авто из списка или переключитесь на «Новая машина»'), backgroundColor: AppColors.cardBg),
        );
        return;
      }
      useCarId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      useCarId = 'new_${DateTime.now().millisecondsSinceEpoch}';
      final composed = composeNewVehicleForOrder(
        structured: false,
        brand: '',
        model: '',
        generation: '',
        freeLine: _carInfoController.text,
        explicitPlateRaw: _licensePlateController.text,
        catalog: catalogForNew,
      );
      resolvedCarInfo = composed.carInfo.trim().isEmpty ? 'Автомобиль' : composed.carInfo.trim();
      final exp = normalizePlateInput(_licensePlateController.text.trim());
      resolvedPlate = composed.licensePlate ?? (isValidRussianPlateCompact(exp) ? exp : null);
    }

    final order = Order(
      id: '',
      orderNumber: '',
      carId: useCarId,
      clientName: clientName,
      clientPhone: _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
      carInfo: resolvedCarInfo,
      vin: _vinController.text.trim().isEmpty ? null : _vinController.text.trim(),
      licensePlate: resolvedPlate,
      bodyType: _bodyTypeController.text.trim().isEmpty ? null : _bodyTypeController.text.trim(),
      color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
      mileage: mileageVal,
      engineType: _engineTypeController.text.trim().isEmpty ? null : _engineTypeController.text.trim(),
      status: OrderStatus.pendingConfirmation,
      dateTime: _dateTime,
      items: items,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      bayId: _selectedBayId,
    );

    final repo = ref.read(orderRepositoryProvider.notifier);
    final addedOrder = await repo.addOrderAsync(order);

    if (mounted) {
      _saveSucceeded = true;
      final draftId = _linkedDraftId;
      if (draftId != null) {
        await ref.read(orderCreationDraftsProvider.notifier).remove(draftId);
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Заказ ${addedOrder.orderNumber} создан'),
          backgroundColor: AppColors.cardBg,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: addedOrder.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    final allServices = settings.services;
    final slots = settings.slotsSettings;
    final orders = ref.watch(orderRepositoryProvider);
    final orgAsync = ref.watch(organizationProvider);
    final bayBased = orgAsync.valueOrNull?.schedulingMode == 'bay_based';
    final showBayPicker = slots.hasNamedBays && bayBased;
    final phoneNorm = _normalizePhone(_clientPhoneController.text);
    final clientCars = _clientCarPicks(orders, phoneNorm);
    final allCars = _uniqueCarPicks(orders);
    final clientIds = clientCars.map((c) => c.carId).toSet();
    final otherCars = allCars.where((c) => !clientIds.contains(c.carId)).toList();
    final q = _carSearchController.text;
    final fClient = clientCars.where((c) => _carPickMatches(c, q)).toList();
    final fOther = otherCars.where((c) => _carPickMatches(c, q)).toList();
    final catalogPicks = ref.watch(quickOrderCatalogPicksProvider).valueOrNull ?? [];
    final qCat = q.trim().toLowerCase();
    final fCatalog = catalogPicks
        .where((p) {
          if (qCat.length < 2) return false;
          final l = p.label.toLowerCase();
          return l.contains(qCat) || p.modelName.toLowerCase().startsWith(qCat);
        })
        .take(50)
        .map(
          (p) => _CarPick(
            carId: p.catalogCarId,
            carInfo: p.label,
            vin: null,
            licensePlate: null,
          ),
        )
        .toList();
    final bayIds = slots.bays.map((b) => b.id).toSet();
    final bayValue = _selectedBayId != null && bayIds.contains(_selectedBayId) ? _selectedBayId : null;

    Widget carTile(_CarPick c) {
      final sel = _pickedCar == c;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.cardBg,
        child: ListTile(
          title: Text(c.carInfo, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: (c.licensePlate != null && c.licensePlate!.isNotEmpty) || (c.vin != null && c.vin!.isNotEmpty)
              ? Text(
                  [
                    if (c.licensePlate != null && c.licensePlate!.isNotEmpty) c.licensePlate!,
                    if (c.vin != null && c.vin!.isNotEmpty) 'VIN ${c.vin}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          trailing: sel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
          onTap: () => setState(() => _applyPickedCar(c)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Новый заказ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Дата и время'),
            subtitle: Text(formatDateTime(_dateTime)),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 16),
          const Text(
            'Клиент',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientPhoneController,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              hintText: '+7 999 123-45-67',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientNameController,
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Иван Петров',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Автомобиль',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Из базы'), icon: Icon(Icons.list_alt_rounded, size: 18)),
              ButtonSegment(value: false, label: Text('Новая'), icon: Icon(Icons.add_road_rounded, size: 18)),
            ],
            selected: {_carFromList},
            onSelectionChanged: (s) {
              setState(() {
                _carFromList = s.first;
                if (_carFromList) {
                  _clearCarFieldsForNew();
                  _pickedCar = null;
                } else {
                  _pickedCar = null;
                  _clearCarFieldsForNew();
                }
              });
            },
          ),
          if (_carFromList) ...[
            const SizedBox(height: 8),
            if (clientCars.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Сначала авто этого клиента (по телефону), ниже — остальные.',
                  style: TextStyle(fontSize: 12, color: AppColors.primary.withValues(alpha: 0.9)),
                ),
              ),
            TextField(
              controller: _carSearchController,
              decoration: const InputDecoration(
                labelText: 'Поиск',
                hintText: 'Марка, госномер, VIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: [
                  if (fClient.isNotEmpty) ...[
                    const Text('Авто клиента', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...fClient.map(carTile),
                    if (fOther.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (fOther.isNotEmpty) ...[
                    Text(
                      fClient.isNotEmpty ? 'Другие по заказам' : 'Автомобили по заказам',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    ...fOther.map(carTile),
                  ],
                  if (fCatalog.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Справочник марок и моделей',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qCat.length < 2
                          ? 'Введите минимум 2 символа в поиске.'
                          : 'Выбор создаёт новое авто в заказе.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 6),
                    ...fCatalog.map(carTile),
                  ],
                  if (fClient.isEmpty && fOther.isEmpty && fCatalog.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        allCars.isEmpty
                            ? 'Нет сохранённых авто — выберите «Новая».'
                            : 'Ничего не найдено — измените поиск.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Данные выбранного авто (можно править)',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Новая машина будет привязана к клиенту в заказе.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _carInfoController,
            decoration: const InputDecoration(
              labelText: 'Марка, модель, примечание',
              hintText: 'Toyota Camry, А123АА777',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _vinController,
            decoration: const InputDecoration(
              labelText: 'VIN (необязательно)',
              hintText: '17 символов',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _licensePlateController,
            decoration: const InputDecoration(
              labelText: 'Гос. номер (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyTypeController,
            decoration: const InputDecoration(
              labelText: 'Тип кузова (необязательно)',
              hintText: 'Седан, универсал...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _colorController,
            decoration: const InputDecoration(
              labelText: 'Цвет (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mileageController,
            decoration: const InputDecoration(
              labelText: 'Пробег, км (необязательно)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _engineTypeController,
            decoration: const InputDecoration(
              labelText: 'Двигатель (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          if (showBayPicker) ...[
            const SizedBox(height: 20),
            const Text(
              'Пост / бокс',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Режим «По постам». Не выбрано — назначится свободный пост.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: bayValue,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Пост',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Не выбрано (авто)'),
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
          const SizedBox(height: 24),
          const Text(
            'Услуги',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...allServices.map((s) {
            final selected = _selectedServices.any((e) => e.id == s.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: selected,
                onChanged: (_) => _toggleService(s),
                title: Text(s.name),
                subtitle: Text('${formatMoney(s.priceKopecks)} • ${s.durationMinutes} мин'),
                secondary: Text(
                  formatMoney(s.priceKopecks),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAddCustomItemDialog(context),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Добавить позицию от руки'),
          ),
          if (_customItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._customItems.asMap().entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.value.name, style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text(
                      '${e.value.estimatedMinutes} мин • ${formatMoney(e.value.priceKopecks ?? 0)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _removeCustomItem(e.key),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Необязательно',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Создать заказ'),
          ),
        ],
      ),
    );
  }
}
