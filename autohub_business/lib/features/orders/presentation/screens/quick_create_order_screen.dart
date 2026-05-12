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
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/schedule/slot_grid_utils.dart';
import '../../application/order_creation_drafts_notifier.dart';
import '../../domain/order_creation_draft.dart';
import 'order_detail_screen.dart';

enum _ComposeMode { byServices, byPackages }

/// Экран быстрого создания заказа (кнопка-ключик): состав, авто, время, мастер, клиент.
class QuickCreateOrderScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  /// Восстановление из локального черновика (вкладка «Черновики»).
  final OrderCreationDraft? resumeDraft;

  const QuickCreateOrderScreen({super.key, this.initialDate, this.resumeDraft});

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

ServicePackage? _qcFindPackage(Iterable<ServicePackage> packages, String? id) {
  if (id == null) return null;
  for (final p in packages) {
    if (p.id == id) return p;
  }
  return null;
}

/// [lineEdits] — длительность/цена в этом заказе; для входящих в комплекс услуг влияет на базу,
/// иначе база считалась только по справочнику и пересекалась с сеткой неверно после правки 1ч→30мин.
///
/// Если у комплекса задан [ServicePackage.packageDurationMinutes], но сумма длительностей входящих
/// услуг из справочника (с учётом [lineEdits]) уже **другая** — берём сумму: иначе после смены
/// 120→30 в настройках сетка и «Создать заказ» расходились.
int _qcPackageBaseMinutes(
  ServicePackage p,
  Map<String, ServiceItem> byId, {
  Map<String, ({int priceKopecks, int estimatedMinutes})> lineEdits = const {},
}) {
  int sumIncluded() {
    return p.includedServiceIds.fold<int>(0, (a, id) {
      final s = byId[id];
      if (s == null) return a;
      final e = lineEdits[s.id];
      return a + (e != null ? e.estimatedMinutes : s.durationMinutes);
    });
  }

  final hasIncludedLineEdit = p.includedServiceIds.any((id) {
    final s = byId[id];
    return s != null && lineEdits.containsKey(s.id);
  });
  if (hasIncludedLineEdit) {
    return sumIncluded();
  }
  if (p.packageDurationMinutes > 0) {
    final sum = sumIncluded();
    if (sum > 0 && sum != p.packageDurationMinutes) {
      return sum;
    }
    return p.packageDurationMinutes;
  }
  return sumIncluded();
}

class _QuickCreateOrderScreenState extends ConsumerState<QuickCreateOrderScreen> {
  late DateTime _dateTime;
  final _carInfoController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _commentController = TextEditingController();
  final _selectedServices = <ServiceItem>[];
  final _customItems = <OrderItem>[];
  /// Для выбранных услуг из справочника: своя цена (коп.) и длительность (мин) в этом заказе.
  final Map<String, ({int priceKopecks, int estimatedMinutes})> _serviceLineEdits = {};
  bool _carFromList = true;
  _CarOption? _selectedCar;
  _ClientOption? _selectedClient;
  /// Список клиентов держим открытым по TapRegion, а не только по focus (иначе клик по строке снимает focus и список исчезает до onTap).
  bool _clientPickerPinned = false;
  StaffMember? _selectedMaster;
  /// Пост при режиме «по постам»; null — сервер подберёт свободный пост.
  String? _selectedBayId;
  bool _saving = false;
  /// СТО подтвердило согласие за клиента (звонок и т.п.); в push клиенту — «сервис подтвердил».
  bool _confirmForClient = false;
  String? _linkedDraftId;
  bool _saveSucceeded = false;
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
  /// Последнее время начала, согласованное с сеткой/проверкой (для отката при занятом слоте).
  late DateTime _lastValidSlotTime;
  final _serviceFilterController = TextEditingController();
  /// Раскрытые категории услуг (id категории; «__other__» — без категории).
  final Set<String> _expandedOrderCategoryIds = {};
  /// Выбранный комплекс: при ручном изменении услуг сбрасывается.
  String? _selectedPackageId;
  /// Состав заказа: по услугам (категории) или по комплексам.
  _ComposeMode _composeMode = _ComposeMode.byServices;
  /// В режиме «комплексы» — раскрытый комплекс (состав).
  String? _expandedPackageCardId;

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
    _serviceFilterController.addListener(() => setState(() {}));
    if (widget.resumeDraft != null) {
      _linkedDraftId = widget.resumeDraft!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final d = widget.resumeDraft;
        if (d != null && d.source == OrderCreationDraft.kSourceQuick) {
          _applyQuickDraftData(d.data);
        }
      });
    }
    _lastValidSlotTime = _dateTime;
  }

  void _applyQuickDraftData(Map<String, dynamic> m) {
    final v = m['v'];
    if (v is! num || (v.toInt() != 1 && v.toInt() != 2)) return;
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
          id: 'draft_ci_${i}_${map['name']}',
          name: map['name'] as String? ?? '',
          priceKopecks: (map['priceKopecks'] as num?)?.toInt(),
          estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 60,
        ));
      }
    }
    final dtStr = m['dateTime'] as String?;
    final dt = dtStr != null ? DateTime.tryParse(dtStr) : null;
    final staff = ref.read(staffListProvider);
    StaffMember? masterPick;
    final mid = m['masterId'] as String?;
    if (mid != null && mid.isNotEmpty) {
      for (final x in staff) {
        if (x.id == mid) {
          masterPick = x;
          break;
        }
      }
    }
    setState(() {
      if (dt != null) {
        _dateTime = dt;
        _manualHourController.text = _dateTime.hour.toString();
        _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
      }
      _carFromList = m['carFromList'] as bool? ?? true;
      _carInfoController.text = m['carInfoFree'] as String? ?? '';
      _clientNameController.text = m['clientName'] as String? ?? '';
      _clientPhoneController.text = m['clientPhone'] as String? ?? '';
      _commentController.text = m['comment'] as String? ?? '';
      _selectedServices.clear();
      _selectedServices.addAll(selected);
      _serviceLineEdits.clear();
      final seRaw = m['serviceLineEdits'];
      if (seRaw is Map) {
        for (final e in seRaw.entries) {
          final id = e.key.toString();
          final val = e.value;
          if (val is! Map) continue;
          final vm = Map<String, dynamic>.from(val);
          final p = (vm['p'] as num?)?.toInt() ?? (vm['priceKopecks'] as num?)?.toInt();
          final mins = (vm['m'] as num?)?.toInt() ?? (vm['estimatedMinutes'] as num?)?.toInt();
          if (p != null && mins != null && mins >= 1) {
            _serviceLineEdits[id] = (priceKopecks: p, estimatedMinutes: mins.clamp(1, 9999));
          }
        }
      }
      _customItems.clear();
      _customItems.addAll(customs);
      _manualTime = m['manualTime'] as bool? ?? false;
      _manualHourController.text = m['manualHour'] as String? ?? _manualHourController.text;
      _manualMinuteController.text = m['manualMinute'] as String? ?? _manualMinuteController.text;
      _carSearchController.text = m['carSearch'] as String? ?? '';
      _newCarExpanded = m['newCarExpanded'] as bool? ?? false;
      _newCarStructured = m['newCarStructured'] as bool? ?? false;
      _newCarVinController.text = m['newVin'] as String? ?? '';
      _newCarPlateController.text = m['newPlate'] as String? ?? '';
      _newCarColorController.text = m['newColor'] as String? ?? '';
      _newCarMileageController.text = m['newMileage'] as String? ?? '';
      _newBrandController.text = m['newBrand'] as String? ?? '';
      _newModelController.text = m['newModel'] as String? ?? '';
      _newGenerationController.text = m['newGeneration'] as String? ?? '';
      final sc = m['selectedClient'];
      if (sc is Map) {
        final sm = Map<String, dynamic>.from(sc);
        _selectedClient = _ClientOption(
          name: sm['name'] as String? ?? '',
          phone: sm['phone'] as String?,
        );
      } else {
        _selectedClient = null;
      }
      final selCar = m['selectedCar'];
      if (selCar is Map) {
        final cm = Map<String, dynamic>.from(selCar);
        _selectedCar = _CarOption(
          carId: cm['carId'] as String? ?? '',
          carInfo: cm['carInfo'] as String? ?? '',
          vin: cm['vin'] as String?,
          licensePlate: cm['licensePlate'] as String?,
        );
      } else {
        _selectedCar = null;
      }
      _selectedMaster = masterPick;
      _selectedBayId = m['bayId'] as String?;
      _selectedPackageId = m['packageId'] as String?;
      final cm = m['composeMode'] as String?;
      if (cm == 'byPackages') {
        _composeMode = _ComposeMode.byPackages;
      } else {
        _composeMode = _ComposeMode.byServices;
      }
      _serviceFilterController.text = m['serviceFilter'] as String? ?? '';
      _lastValidSlotTime = _dateTime;
    });
  }

  Map<String, dynamic> _quickDraftSnapshot() {
    return {
      'v': 2,
      'dateTime': _dateTime.toIso8601String(),
      'carFromList': _carFromList,
      'selectedCar': _selectedCar == null
          ? null
          : {
              'carId': _selectedCar!.carId,
              'carInfo': _selectedCar!.carInfo,
              'vin': _selectedCar!.vin,
              'licensePlate': _selectedCar!.licensePlate,
            },
      'carInfoFree': _carInfoController.text,
      'clientName': _clientNameController.text,
      'clientPhone': _clientPhoneController.text,
      'selectedClient': _selectedClient == null
          ? null
          : {'name': _selectedClient!.name, 'phone': _selectedClient!.phone},
      'comment': _commentController.text,
      'selectedServiceIds': _selectedServices.map((s) => s.id).toList(),
      'serviceLineEdits': {
        for (final e in _serviceLineEdits.entries)
          e.key: {'p': e.value.priceKopecks, 'm': e.value.estimatedMinutes},
      },
      'customItems': _customItems
          .map((i) => {
                'name': i.name,
                'priceKopecks': i.priceKopecks,
                'estimatedMinutes': i.estimatedMinutes,
              })
          .toList(),
      'masterId': _selectedMaster?.id,
      'bayId': _selectedBayId,
      'newCarExpanded': _newCarExpanded,
      'newCarStructured': _newCarStructured,
      'newVin': _newCarVinController.text,
      'newPlate': _newCarPlateController.text,
      'newColor': _newCarColorController.text,
      'newMileage': _newCarMileageController.text,
      'newBrand': _newBrandController.text,
      'newModel': _newModelController.text,
      'newGeneration': _newGenerationController.text,
      'manualTime': _manualTime,
      'manualHour': _manualHourController.text,
      'manualMinute': _manualMinuteController.text,
      'carSearch': _carSearchController.text,
      'packageId': _selectedPackageId,
      'composeMode': _composeMode.name,
      'serviceFilter': _serviceFilterController.text,
    };
  }

  bool _shouldSaveQuickDraft() {
    if (_saveSucceeded) return false;
    final n = _clientNameController.text.trim();
    final p = _clientPhoneController.text.trim();
    if (n.isNotEmpty || p.isNotEmpty) return true;
    if (_commentController.text.trim().isNotEmpty) return true;
    if (_selectedServices.isNotEmpty || _customItems.isNotEmpty) return true;
    if (_selectedCar != null) return true;
    if (_carInfoController.text.trim().isNotEmpty) return true;
    if (_newCarVinController.text.trim().isNotEmpty ||
        _newCarPlateController.text.trim().isNotEmpty ||
        _newBrandController.text.trim().isNotEmpty ||
        _newModelController.text.trim().isNotEmpty ||
        _newGenerationController.text.trim().isNotEmpty ||
        _newCarColorController.text.trim().isNotEmpty ||
        _newCarMileageController.text.trim().isNotEmpty) {
      return true;
    }
    if (_selectedClient != null) return true;
    if (_selectedMaster != null || (_selectedBayId != null && _selectedBayId!.trim().isNotEmpty)) {
      return true;
    }
    return false;
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
    if (!_saveSucceeded) {
      if (_shouldSaveQuickDraft()) {
        final snap = _quickDraftSnapshot();
        final existing = _linkedDraftId;
        Future(() async {
          try {
            await ref.read(orderCreationDraftsProvider.notifier).upsertFromSnapshot(
                  existingId: existing,
                  source: OrderCreationDraft.kSourceQuick,
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
    _serviceFilterController.dispose();
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
  /// Занятые слоты. Без [masterId] — все заказы; с [masterId] — заказы без назначенного мастера и заказы выбранного мастера (у других мастеров время не пересекаем).
  static Set<String> _occupiedSlotKeys(
    List<Order> orders,
    DateTime day,
    SlotsSettings slots, {
    String? masterId,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final keys = <String>{};
    for (final o in orders) {
      if (masterId != null && masterId.isNotEmpty) {
        final om = o.masterId;
        if (om != null && om.isNotEmpty && om != masterId) {
          continue;
        }
      }
      final dt = o.dateTime ?? o.plannedStartTime ?? o.effectiveDateTime;
      final dayO = DateTime(dt.year, dt.month, dt.day);
      if (dayO != dayStart) continue;
      final end = o.plannedEndTime ?? dt.add(Duration(minutes: o.items.fold<int>(0, (s, i) => s + i.estimatedMinutes)));
      var m = dt.hour * 60 + dt.minute;
      final endM = end.hour * 60 + end.minute;
      final step = slots.slotDurationMinutes.clamp(15, 240);
      while (m < endM) {
        final h = m ~/ 60;
        final min = m % 60;
        keys.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
        m += step;
      }
    }
    return keys;
  }

  /// Слоты от начала до конца рабочего дня с шагом из настроек (как у клиента).
  static List<DateTime> _timeSlotsForDay(SlotsSettings slots, DateTime day) {
    final startM = slots.startHour * 60 + slots.startMinute;
    final endM = slots.endHour * 60 + slots.endMinute;
    final step = slots.slotDurationMinutes.clamp(15, 240);
    final list = <DateTime>[];
    for (var m = startM; m < endM; m += step) {
      final h = m ~/ 60;
      final min = m % 60;
      list.add(DateTime(day.year, day.month, day.day, h, min));
    }
    return list;
  }

  /// Та же модель, что и у сетки: [start, start+duration) не пересекается с [busy] (другие заказы на день/мастера).
  bool _intervalFreeForCurrentSelection() {
    final duration = _displayTotalMinutes();
    if (duration <= 0) return true;
    final dayOnly = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
    final busy = busyMinuteRangesForOrdersDay(
      ref.read(orderRepositoryProvider),
      dayOnly,
      masterId: _selectedMaster?.id,
    );
    final startM = _dateTime.hour * 60 + _dateTime.minute;
    return isCalendarMinutesIntervalFree(
      startMinutes: startM,
      durationMinutes: duration,
      busy: busy,
    );
  }

  void _showSlotOccupiedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Данный слот занят, укажите другое время'),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyManualTime() {
    final h = int.tryParse(_manualHourController.text) ?? _dateTime.hour;
    final min = int.tryParse(_manualMinuteController.text) ?? _dateTime.minute;
    final next = DateTime(
      _dateTime.year,
      _dateTime.month,
      _dateTime.day,
      h.clamp(0, 23),
      min.clamp(0, 59),
    );
    // Полные минуты (две цифры) — тогда проверяем пересечение, как в сетке; иначе не откатываем из‑за промежуточного ввода.
    final strict = _manualMinuteController.text.length == 2;
    if (strict) {
      final duration = _displayTotalMinutes();
      if (duration > 0) {
        final dayOnly = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
        final busy = busyMinuteRangesForOrdersDay(
          ref.read(orderRepositoryProvider),
          dayOnly,
          masterId: _selectedMaster?.id,
        );
        final startM = next.hour * 60 + next.minute;
        if (!isCalendarMinutesIntervalFree(
          startMinutes: startM,
          durationMinutes: duration,
          busy: busy,
        )) {
          _showSlotOccupiedSnack();
          setState(() {
            _dateTime = _lastValidSlotTime;
            _manualHourController.text = _lastValidSlotTime.hour.toString();
            _manualMinuteController.text = _lastValidSlotTime.minute.toString().padLeft(2, '0');
          });
          return;
        }
        _lastValidSlotTime = next;
      } else {
        _lastValidSlotTime = next;
      }
    }
    setState(() {
      _manualTime = true;
      _dateTime = next;
      _manualHourController.text = _dateTime.hour.toString();
      _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
    });
  }

  void _shiftScheduleDay(int deltaDays) {
    final day = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
    final nextDay = day.add(Duration(days: deltaDays));
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    if (nextDay.isBefore(startToday)) {
      return;
    }
    setState(() {
      _dateTime = DateTime(nextDay.year, nextDay.month, nextDay.day, _dateTime.hour, _dateTime.minute);
      if (!_manualTime) {
        _manualHourController.text = _dateTime.hour.toString();
        _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
      }
      _lastValidSlotTime = _dateTime;
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

  Future<void> _pickDateOnly() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _dateTime.hour,
        _dateTime.minute,
      );
      _lastValidSlotTime = _dateTime;
    });
  }

  Future<void> _pickTimeOnly() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (time == null || !mounted) {
      return;
    }
    final candidate = DateTime(
      _dateTime.year,
      _dateTime.month,
      _dateTime.day,
      time.hour,
      time.minute,
    );
    final duration = _displayTotalMinutes();
    if (duration > 0) {
      final dayOnly = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
      final busy = busyMinuteRangesForOrdersDay(
        ref.read(orderRepositoryProvider),
        dayOnly,
        masterId: _selectedMaster?.id,
      );
      final startM = candidate.hour * 60 + candidate.minute;
      if (!isCalendarMinutesIntervalFree(
        startMinutes: startM,
        durationMinutes: duration,
        busy: busy,
      )) {
        _showSlotOccupiedSnack();
        return;
      }
    }
    setState(() {
      _dateTime = candidate;
      _manualHourController.text = _dateTime.hour.toString();
      _manualMinuteController.text = _dateTime.minute.toString().padLeft(2, '0');
      _manualTime = false;
      _lastValidSlotTime = _dateTime;
    });
  }

  void _toggleService(ServiceItem s) {
    setState(() {
      final settings = ref.read(settingsRepositoryProvider);
      final pkg = _qcFindPackage(settings.packages, _selectedPackageId);
      if (pkg != null && pkg.includedServiceIds.contains(s.id)) {
        return;
      }
      if (pkg == null) {
        _selectedPackageId = null;
      }
      if (_selectedServices.any((e) => e.id == s.id)) {
        _selectedServices.removeWhere((e) => e.id == s.id);
        _serviceLineEdits.remove(s.id);
      } else {
        _selectedServices.add(s);
      }
    });
  }

  void _selectPackage(ServicePackage p) {
    final settings = ref.read(settingsRepositoryProvider);
    final byId = {for (final x in settings.services) x.id: x};
    setState(() {
      _selectedPackageId = p.id;
      _selectedServices.clear();
      _serviceLineEdits.clear();
      for (final id in p.includedServiceIds) {
        final x = byId[id];
        if (x != null) {
          _selectedServices.add(x);
        }
      }
    });
  }

  /// При выборе авто из заказов подставляем клиента с последнего подходящего заказа.
  void _applyClientFromOrderCar(_CarOption c) {
    if (c.carId.startsWith('catalog:')) return;
    final orders = ref.read(orderRepositoryProvider);
    final matching = orders
        .where((o) => o.carId == c.carId && o.carInfo.trim() == c.carInfo.trim())
        .toList();
    matching.sort((a, b) {
      final da = a.dateTime ?? a.plannedStartTime ?? DateTime(1970);
      final db = b.dateTime ?? b.plannedStartTime ?? DateTime(1970);
      return db.compareTo(da);
    });
    for (final o in matching) {
      final name = (o.clientName ?? '').trim();
      final phone = (o.clientPhone ?? '').trim();
      if (name.isEmpty && phone.isEmpty) {
        continue;
      }
      setState(() {
        if (name.isNotEmpty) {
          _clientNameController.text = name;
        }
        if (phone.isNotEmpty) {
          _clientPhoneController.text = phone;
        }
        _selectedClient = _ClientOption(
          name: name.isEmpty ? 'Без имени' : name,
          phone: phone.isEmpty ? null : phone,
        );
      });
      return;
    }
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
    setState(() {
      _customItems.removeAt(index);
    });
  }

  /// Актуальная позиция из справочника (после правки в настройках без пересоздания заказа).
  ServiceItem _serviceFromSettings(ServiceItem s) {
    for (final x in ref.read(settingsRepositoryProvider).services) {
      if (x.id == s.id) return x;
    }
    return s;
  }

  int _effectivePriceKopecks(ServiceItem s) {
    final e = _serviceLineEdits[s.id];
    if (e != null) return e.priceKopecks;
    return _serviceFromSettings(s).priceKopecks;
  }

  int _effectiveMinutes(ServiceItem s) {
    final e = _serviceLineEdits[s.id];
    if (e != null) return e.estimatedMinutes;
    return _serviceFromSettings(s).durationMinutes;
  }

  bool _hasLineEdit(ServiceItem s) => _serviceLineEdits.containsKey(s.id);

  void _showEditServiceLineDialog(ServiceItem s) {
    final priceCtrl = TextEditingController(text: '${_effectivePriceKopecks(s) ~/ 100}');
    final minCtrl = TextEditingController(text: '${_effectiveMinutes(s)}');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    s.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Для этого заказа (в справочнике не меняется)',
                    style: TextStyle(fontSize: 12, color: _textTertiary, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Цена, ₽',
                      filled: true,
                      fillColor: _nestedBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Длительность, мин',
                      filled: true,
                      fillColor: _nestedBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'В справочнике: ${formatMoney(s.priceKopecks)} · ${s.durationMinutes} мин',
                    style: TextStyle(fontSize: 11, color: _textTertiary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _serviceLineEdits.remove(s.id));
                          Navigator.pop(ctx);
                        },
                        child: Text('Как в справочнике', style: TextStyle(color: _textSecondary)),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final rub = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
                          final k = (rub * 100).round().clamp(0, 999999999);
                          final m = int.tryParse(minCtrl.text.trim()) ?? _effectiveMinutes(s);
                          if (m < 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Укажите длительность больше 0')),
                            );
                            return;
                          }
                          setState(() {
                            _serviceLineEdits[s.id] = (priceKopecks: k, estimatedMinutes: m.clamp(1, 9999));
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      priceCtrl.dispose();
      minCtrl.dispose();
    });
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
    final settings = ref.read(settingsRepositoryProvider);
    final byId = {for (final s in settings.services) s.id: s};
    final pkg = _qcFindPackage(settings.packages, _selectedPackageId);
    final List<OrderItem> items = [];
    if (pkg != null) {
      final baseMin = _qcPackageBaseMinutes(pkg, byId, lineEdits: _serviceLineEdits);
      items.add(
        OrderItem(
          id: 'pkg_${pkg.id}',
          name: pkg.name,
          priceKopecks: pkg.packagePriceKopecks,
          estimatedMinutes: baseMin,
        ),
      );
      final inc = pkg.includedServiceIds.toSet();
      for (final s in _selectedServices) {
        if (!inc.contains(s.id)) {
          items.add(
            OrderItem(
              id: s.id,
              name: s.name,
              priceKopecks: _effectivePriceKopecks(s),
              estimatedMinutes: _effectiveMinutes(s),
              serviceId: s.id,
              catalogItemId: s.catalogItemId,
              isAdditional: true,
            ),
          );
        }
      }
    } else {
      items.addAll(
        _selectedServices
            .map(
              (s) => OrderItem(
                id: s.id,
                name: s.name,
                priceKopecks: _effectivePriceKopecks(s),
                estimatedMinutes: _effectiveMinutes(s),
                serviceId: s.id,
                catalogItemId: s.catalogItemId,
              ),
            )
            .toList(),
      );
    }
    items.addAll(_customItems);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну позицию в состав заказа')),
      );
      return;
    }
    if (_displayTotalMinutes() > 0 && !_intervalFreeForCurrentSelection()) {
      _showSlotOccupiedSnack();
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
      status: _confirmForClient ? OrderStatus.confirmed : OrderStatus.pendingConfirmation,
      dateTime: _dateTime,
      items: items,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      bayId: _selectedBayId,
      orgConfirmedOnBehalfOfClient: _confirmForClient,
    );

    final repo = ref.read(orderRepositoryProvider.notifier);
    Order addedOrder;
    try {
      addedOrder = await repo.addOrderAsync(order);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
      return;
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
    _saveSucceeded = true;
    final draftId = _linkedDraftId;
    if (draftId != null) {
      await ref.read(orderCreationDraftsProvider.notifier).remove(draftId);
    }
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
              priceKopecks: _effectivePriceKopecks(s),
              estimatedMinutes: _effectiveMinutes(s),
              serviceId: s.id,
              catalogItemId: s.catalogItemId,
            ))
        .toList();
    list.addAll(_customItems);
    return list;
  }

  int _displayTotalMinutes() {
    final settings = ref.read(settingsRepositoryProvider);
    final pkg = _qcFindPackage(settings.packages, _selectedPackageId);
    final byId = {for (final s in settings.services) s.id: s};
    if (pkg != null) {
      final base = _qcPackageBaseMinutes(pkg, byId, lineEdits: _serviceLineEdits);
      var add = 0;
      final inc = pkg.includedServiceIds.toSet();
      for (final s in _selectedServices) {
        if (!inc.contains(s.id)) {
          add += _effectiveMinutes(s);
        }
      }
      return base + add + _customItems.fold(0, (a, b) => a + b.estimatedMinutes);
    }
    return _allItems.fold(0, (s, i) => s + i.estimatedMinutes);
  }

  int _displayTotalKopecks() {
    final settings = ref.read(settingsRepositoryProvider);
    final pkg = _qcFindPackage(settings.packages, _selectedPackageId);
    if (pkg != null) {
      var add = 0;
      final inc = pkg.includedServiceIds.toSet();
      for (final s in _selectedServices) {
        if (!inc.contains(s.id)) {
          add += _effectivePriceKopecks(s);
        }
      }
      return pkg.packagePriceKopecks + add + _customItems.fold(0, (a, b) => a + (b.priceKopecks ?? 0));
    }
    return _allItems.fold(0, (s, i) => s + (i.priceKopecks ?? 0));
  }

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
    final occupiedSlots = _occupiedSlotKeys(
      orders,
      _dateTime,
      slots,
      masterId: _selectedMaster?.id,
    );
    final orderDurationMin = _displayTotalMinutes();

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
                orders,
                slots,
                timeSlots,
                occupiedSlots,
                showBayPicker,
                orderDurationMin,
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
                SizedBox(
                  width: 320,
                  child: _buildRightColumn(
                    staff,
                    orders,
                    slots,
                    timeSlots,
                    occupiedSlots,
                    orderDurationMin,
                  ),
                ),
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
    List<Order> orders,
    SlotsSettings slots,
    List<DateTime> timeSlots,
    Set<String> occupiedSlots,
    bool showBayPicker,
    int orderDurationMin,
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
          _buildRightColumn(
            staff,
            orders,
            slots,
            timeSlots,
            occupiedSlots,
            orderDurationMin,
          ),
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
            onTap: () {
              setState(() {
                _selectedCar = c;
                _carFocusNode.unfocus();
              });
              _applyClientFromOrderCar(c);
            },
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

  Widget _buildServiceCheckboxTile(ServiceItem s) {
    final selected = _selectedServices.any((e) => e.id == s.id);
    return Material(
      color: selected ? _primary.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleService(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => _toggleService(s),
                activeColor: _primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatMoney(_effectivePriceKopecks(s))} • ${_effectiveMinutes(s)} мин'
                      '${_hasLineEdit(s) ? ' · изменено' : ''}',
                      style: TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                IconButton(
                  tooltip: 'Цена и длительность',
                  padding: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(Icons.tune_rounded, size: 22, color: _primary),
                  onPressed: () => _showEditServiceLineDialog(s),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Нижний sheet: поиск и услуги по разделам (как в основном списке).
  void _showServiceCatalogBottomSheet() {
    final settings = ref.read(settingsRepositoryProvider);
    final all = settings.services;
    final categories = sortedServiceCategoriesForDisplay(settings.categories);
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final searchController = TextEditingController();
    final activePkg = _qcFindPackage(settings.packages, _selectedPackageId);
    final included = activePkg?.includedServiceIds.toSet() ?? <String>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final q = searchController.text.trim().toLowerCase();
            bool match(ServiceItem s) {
              if (q.isEmpty) {
                return true;
              }
              return s.name.toLowerCase().contains(q);
            }

            Widget line(ServiceItem s) {
              final inPack = included.contains(s.id);
              final selected = _selectedServices.any((e) => e.id == s.id);
              return ListTile(
                onTap: inPack
                    ? null
                    : () {
                        _toggleService(s);
                        setModal(() {});
                        setState(() {});
                      },
                leading: Icon(
                  inPack ? Icons.lock_outline_rounded : (selected ? Icons.check_box : Icons.check_box_outline_blank),
                  color: inPack ? _textTertiary : (selected ? _primary : _textSecondary),
                ),
                title: Text(s.name, style: TextStyle(color: _textPrimary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                subtitle: Text(
                  inPack
                      ? 'уже в составе комплекса'
                      : '${formatMoney(_effectivePriceKopecks(s))} • ${_effectiveMinutes(s)} мин${_hasLineEdit(s) ? ' · изм.' : ''}',
                  style: TextStyle(fontSize: 12, color: _textTertiary),
                ),
                trailing: !inPack && selected
                    ? IconButton(
                        icon: Icon(Icons.tune_rounded, color: _primary, size: 22),
                        tooltip: 'Цена и длительность',
                        onPressed: () {
                          _showEditServiceLineDialog(s);
                          setModal(() {});
                          setState(() {});
                        },
                      )
                    : null,
              );
            }

            final list = <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Услуги', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => setModal(() {}),
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: Icon(Icons.search_rounded, color: _textSecondary),
                    filled: true,
                    fillColor: _nestedBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ];

            for (final cat in categories) {
              final inCat = repo.servicesForCategory(cat.id).where(match).toList();
              if (inCat.isEmpty) {
                continue;
              }
              list.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(displayServiceCategoryTitle(cat.name), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
                ),
              );
              list.addAll(inCat.map(line));
            }
            final categoryIdSet = {for (final c in categories) c.id};
            final other = all.where((s) => !categoryIdSet.contains(s.categoryId)).where(match).toList();
            if (other.isNotEmpty) {
              list.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Прочее', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
                ),
              );
              list.addAll(other.map(line));
            }

            return DraggableScrollableSheet(
              maxChildSize: 0.92,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              expand: false,
              builder: (ctx, scroll) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: _textTertiary, borderRadius: BorderRadius.circular(2)),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        padding: const EdgeInsets.only(bottom: 24),
                        children: list,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }

  List<Widget> _packageComposeListBody(Map<String, ServiceItem> byId, List<ServicePackage> packages) {
    final out = <Widget>[];
    final active = _qcFindPackage(packages, _selectedPackageId);
    final inc = active?.includedServiceIds.toSet() ?? <String>{};

    for (final p in packages) {
      final sel = _selectedPackageId == p.id;
      final exp = _expandedPackageCardId == p.id;
      final dur = _qcPackageBaseMinutes(
        p,
        byId,
        lineEdits: sel ? _serviceLineEdits : const {},
      );
      out.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() {
              _selectPackage(p);
              _expandedPackageCardId = p.id;
            }),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? _primary : _cardBorder, width: sel ? 2 : 1),
                color: sel ? _primary.withValues(alpha: 0.08) : _nestedBg,
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined, color: sel ? _primary : _textTertiary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textPrimary),
                        ),
                      ),
                      Text(
                        formatMoney(p.packagePriceKopecks),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _accentMoney),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '⏱ ${formatDurationMinutes(dur)}',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          if (exp) {
                            _expandedPackageCardId = null;
                          } else {
                            _expandedPackageCardId = p.id;
                            if (!sel) {
                              _selectPackage(p);
                            }
                          }
                        });
                      },
                      child: Text(exp ? 'Свернуть' : 'Состав комплекса'),
                    ),
                  ),
                  if (exp) ...[
                    const Divider(height: 16),
                    ...p.includedServiceIds.map((id) {
                      final s = byId[id];
                      if (s == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: _textTertiary),
                            const SizedBox(width: 4),
                            Expanded(child: Text(s.name, style: TextStyle(fontSize: 13, color: _textSecondary))),
                            Text('${s.durationMinutes} мин', style: TextStyle(fontSize: 12, color: _textTertiary)),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      out.add(const SizedBox(height: 8));
    }

    if (active != null) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Доп. услуги',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary),
          ),
        ),
      );
      final addons = _selectedServices.where((s) => !inc.contains(s.id)).toList();
      if (addons.isEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Нет доп. позиций', style: TextStyle(fontSize: 12, color: _textTertiary, fontStyle: FontStyle.italic)),
          ),
        );
      } else {
        for (final s in addons) {
          out.add(
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cardBorder),
              ),
              child: ListTile(
                dense: true,
                title: Text(s.name, style: TextStyle(fontSize: 14, color: _textPrimary, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '${formatMoney(_effectivePriceKopecks(s))} · ${_effectiveMinutes(s)} мин${_hasLineEdit(s) ? ' · изм.' : ''}',
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Цена и длительность',
                      icon: Icon(Icons.tune_rounded, color: _primary, size: 22),
                      onPressed: () => setState(() => _showEditServiceLineDialog(s)),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline_rounded, color: _error),
                      onPressed: () => setState(() {
                        _selectedServices.removeWhere((e) => e.id == s.id);
                        _serviceLineEdits.remove(s.id);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    } else {
      out.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Выберите комплекс', style: TextStyle(fontSize: 12, color: _textTertiary)),
        ),
      );
    }

    out.add(const SizedBox(height: 4));
    out.add(
      FilledButton.tonalIcon(
        onPressed: _showServiceCatalogBottomSheet,
        icon: Icon(Icons.playlist_add_rounded, color: _primary),
        label: Text('Добавить услугу из списка', style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: _primary.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
    out.add(const SizedBox(height: 8));
    out.add(
      OutlinedButton.icon(
        onPressed: _showAddCustomItemDialog,
        icon: Icon(Icons.add, size: 18, color: _primary),
        label: Text('Позиция от руки', style: TextStyle(color: _primary)),
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: _primary, side: BorderSide(color: _primary)),
      ),
    );
    if (_customItems.isNotEmpty) {
      out.addAll(
        _customItems.asMap().entries.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 4, top: 8),
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
                          Text(
                            '${e.value.estimatedMinutes} мин • ${formatMoney(e.value.priceKopecks ?? 0)}',
                            style: TextStyle(fontSize: 12, color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: _textSecondary),
                      onPressed: () => _removeCustomItem(e.key),
                    ),
                  ],
                ),
              ),
            ),
      );
    }
    return out;
  }

  Widget _orderComposeModeToggle(List<ServicePackage> packages) {
    if (packages.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Как оформляем состав',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: _composeMode == _ComposeMode.byServices
                      ? _primary.withValues(alpha: 0.2)
                      : _nestedBg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => setState(() {
                      _composeMode = _ComposeMode.byServices;
                      _selectedPackageId = null;
                      _expandedPackageCardId = null;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _composeMode == _ComposeMode.byServices ? _primary : _cardBorder,
                          width: _composeMode == _ComposeMode.byServices ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 20,
                            color: _composeMode == _ComposeMode.byServices ? _primary : _textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'По услугам',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _composeMode == _ComposeMode.byServices ? FontWeight.w800 : FontWeight.w500,
                                color: _composeMode == _ComposeMode.byServices ? _primary : _textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: _composeMode == _ComposeMode.byPackages
                      ? _primary.withValues(alpha: 0.2)
                      : _nestedBg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => setState(() => _composeMode = _ComposeMode.byPackages),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _composeMode == _ComposeMode.byPackages ? _primary : _cardBorder,
                          width: _composeMode == _ComposeMode.byPackages ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: _composeMode == _ComposeMode.byPackages ? _primary : _textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'По комплексам',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _composeMode == _ComposeMode.byPackages ? FontWeight.w800 : FontWeight.w500,
                                color: _composeMode == _ComposeMode.byPackages ? _primary : _textSecondary,
                              ),
                            ),
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
    );
  }

  Widget _buildCenterColumn(List<ServiceItem> allServices) {
    final totalMin = _displayTotalMinutes();
    final totalKop = _displayTotalKopecks();
    final settings = ref.read(settingsRepositoryProvider);
    final packages = settings.packages;
    final categories = sortedServiceCategoriesForDisplay(settings.categories);
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final categoryIds = categories.map((c) => c.id).toSet();
    final q = _serviceFilterController.text.trim().toLowerCase();
    final forceExpand = q.isNotEmpty;
    bool matchQ(ServiceItem s) {
      if (q.isEmpty) {
        return true;
      }
      ServiceCategory? cat;
      for (final c in categories) {
        if (c.id == s.categoryId) {
          cat = c;
          break;
        }
      }
      final catName = cat?.name ?? '';
      return s.name.toLowerCase().contains(q) || catName.toLowerCase().contains(q);
    }
    final filtered = allServices.where(matchQ).toList();
    final servicesWithoutCategory =
        filtered.where((s) => !categoryIds.contains(s.categoryId)).toList();
    final decoSearch = InputDecoration(
      hintText: 'Поиск по названию или категории',
      prefixIcon: Icon(Icons.search_rounded, size: 20, color: _textSecondary),
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

    const kOther = '__other__';
    final listChildren = <Widget>[];
    for (final cat in categories) {
      final inCat = repo.servicesForCategory(cat.id).where(matchQ).toList();
      if (inCat.isEmpty) {
        continue;
      }
      final expanded = forceExpand || _expandedOrderCategoryIds.contains(cat.id);
      listChildren.add(
        Material(
          color: _nestedBg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: forceExpand
                ? null
                : () {
                    setState(() {
                      if (_expandedOrderCategoryIds.contains(cat.id)) {
                        _expandedOrderCategoryIds.remove(cat.id);
                      } else {
                        _expandedOrderCategoryIds.add(cat.id);
                      }
                    });
                  },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayServiceCategoryTitle(cat.name),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  if (!forceExpand) Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: _textTertiary),
                ],
              ),
            ),
          ),
        ),
      );
      if (expanded) {
        listChildren.add(const SizedBox(height: 4));
        listChildren.addAll(inCat.map(_buildServiceCheckboxTile));
      }
      listChildren.add(const SizedBox(height: 8));
    }
    if (servicesWithoutCategory.isNotEmpty) {
      final expanded = forceExpand || _expandedOrderCategoryIds.contains(kOther);
      listChildren.add(
        Material(
          color: _nestedBg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: forceExpand
                ? null
                : () {
                    setState(() {
                      if (_expandedOrderCategoryIds.contains(kOther)) {
                        _expandedOrderCategoryIds.remove(kOther);
                      } else {
                        _expandedOrderCategoryIds.add(kOther);
                      }
                    });
                  },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Прочее',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  if (!forceExpand) Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: _textTertiary),
                ],
              ),
            ),
          ),
        ),
      );
      if (expanded) {
        listChildren.add(const SizedBox(height: 4));
        listChildren.addAll(servicesWithoutCategory.map(_buildServiceCheckboxTile));
      }
      listChildren.add(const SizedBox(height: 8));
    }
    listChildren.add(
      OutlinedButton.icon(
        onPressed: _showAddCustomItemDialog,
        icon: Icon(Icons.add, size: 18, color: _primary),
        label: Text('Позиция от руки', style: TextStyle(color: _primary)),
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: _primary, side: BorderSide(color: _primary)),
      ),
    );
    if (_customItems.isNotEmpty) {
      listChildren.addAll(
        _customItems.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 4, top: 4),
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
                        Text(
                          '${e.value.estimatedMinutes} мин • ${formatMoney(e.value.priceKopecks ?? 0)}',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
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
      );
    }

    final byId = {for (final s in allServices) s.id: s};
    final usePackageMode = packages.isNotEmpty && _composeMode == _ComposeMode.byPackages;
    final packageBody = _packageComposeListBody(byId, packages);

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
          _sectionHeader(Icons.assignment_rounded, 'Состав заказа'),
          _orderComposeModeToggle(packages),
          if (usePackageMode)
            const SizedBox(height: 4)
          else ...[
            const SizedBox(height: 6),
            TextField(
              controller: _serviceFilterController,
              decoration: decoSearch,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: _isMobile ? 420 : 520,
            child: ListView(
              padding: const EdgeInsets.only(right: 4),
              children: usePackageMode ? packageBody : listChildren,
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

  Widget _buildRightColumn(
    List<StaffMember> staff,
    List<Order> orders,
    SlotsSettings slots,
    List<DateTime> timeSlots,
    Set<String> occupiedSlots,
    int orderDurationMinutes,
  ) {
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(_dateTime.year, _dateTime.month, _dateTime.day);
    final canPrevDay = dayOnly.isAfter(startToday);
    final workStartMin = slots.startHour * 60 + slots.startMinute;
    final workEndMin = slots.endHour * 60 + slots.endMinute;
    final step = slots.slotDurationMinutes.clamp(15, 240);
    final busy = busyMinuteRangesForOrdersDay(orders, dayOnly, masterId: _selectedMaster?.id);
    final scheduleStartMin = _dateTime.hour * 60 + _dateTime.minute;
    final scheduleEndMin = scheduleStartMin + orderDurationMinutes;

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
          _sectionHeader(Icons.schedule_rounded, 'Мастер и время'),
          const SizedBox(height: 12),
          Text('Мастер', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<StaffMember?>(
            value: _findMasterInList(staff),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Сначала выберите мастера или оставьте пустым'),
            items: [
              const DropdownMenuItem<StaffMember?>(value: null, child: Text('— Все мастера (свободные слоты)')),
              ...staff.map((m) => DropdownMenuItem<StaffMember?>(value: m, child: Text(m.name))),
            ],
            onChanged: (v) {
              setState(() {
                _selectedMaster = v;
              });
              final d = _displayTotalMinutes();
              if (d > 0 && mounted && !_intervalFreeForCurrentSelection()) {
                _showSlotOccupiedSnack();
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: canPrevDay ? () => _shiftScheduleDay(-1) : null,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickDateOnly,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: _nestedBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 20, color: _textSecondary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            formatDate(_dateTime),
                            style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _shiftScheduleDay(1),
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickTimeOnly,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_rounded, size: 18, color: _primary),
                  const SizedBox(width: 8),
                  Text(
                    formatTime(_dateTime),
                    style: TextStyle(fontWeight: FontWeight.w600, color: _primary, fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text('только время приёма', style: TextStyle(fontSize: 11, color: _textTertiary)),
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
              if (orderDurationMinutes > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC400),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(' заказ', style: TextStyle(fontSize: 10, color: _textTertiary)),
              ],
              const SizedBox(width: 8),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _textTertiary.withValues(alpha: 0.35), shape: BoxShape.circle)),
              Text(' нет старта', style: TextStyle(fontSize: 10, color: _textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...timeSlots.map((slot) {
                final key = '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                final slotMin = slot.hour * 60 + slot.minute;
                final cellBusy = !isCalendarMinutesIntervalFree(
                  startMinutes: slotMin,
                  durationMinutes: step,
                  busy: busy,
                );
                final cannotStartOrder = orderDurationMinutes > 0 &&
                    (slotMin < workStartMin ||
                        slotMin + orderDurationMinutes > workEndMin ||
                        !isCalendarMinutesIntervalFree(
                          startMinutes: slotMin,
                          durationMinutes: orderDurationMinutes,
                          busy: busy,
                        ));
                final gridDisabled = cellBusy || (orderDurationMinutes > 0 && cannotStartOrder);
                final isSelected = _dateTime.hour == slot.hour && _dateTime.minute == slot.minute && !_manualTime;
                final inOrderWindow =
                    orderDurationMinutes > 0 && slotMin >= scheduleStartMin && slotMin < scheduleEndMin;
                final Color bg = isSelected
                    ? _primary
                    : cellBusy
                        ? _error.withValues(alpha: 0.2)
                        : (cannotStartOrder && orderDurationMinutes > 0)
                            ? _textTertiary.withValues(alpha: 0.2)
                            : _success.withValues(alpha: 0.15);
                final Color border = isSelected
                    ? _primary
                    : cellBusy
                        ? _error
                        : (cannotStartOrder && orderDurationMinutes > 0)
                            ? _textTertiary.withValues(alpha: 0.5)
                            : _success.withValues(alpha: 0.6);
                final Color textColor = isSelected
                    ? Colors.white
                    : cellBusy
                        ? _error
                        : (cannotStartOrder && orderDurationMinutes > 0)
                            ? _textTertiary
                        : _textPrimary;
                return GestureDetector(
                  onTap: gridDisabled
                      ? null
                      : () {
                          setState(() {
                            _manualTime = false;
                            _dateTime = slot;
                            _manualHourController.text = slot.hour.toString();
                            _manualMinuteController.text = slot.minute.toString().padLeft(2, '0');
                            _lastValidSlotTime = _dateTime;
                          });
                        },
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Container(
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
                      if (inOrderWindow)
                        Positioned(
                          top: 0,
                          left: 2,
                          right: 2,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC400),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
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
              SizedBox(
                width: 100,
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _confirmForClient,
                onChanged: (v) => setState(() => _confirmForClient = v ?? false),
                activeColor: _primary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _confirmForClient = !_confirmForClient),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Запись уже согласована с клиентом (например, по телефону). Клиент получит уведомление, что сервис подтвердил запись.',
                      style: TextStyle(fontSize: 12, height: 1.35, color: _textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
