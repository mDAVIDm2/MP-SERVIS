import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/car_expense_group_ids.dart';
import '../../../../core/settings/car_manual_expenses_provider.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/car_model.dart';
import '../analytics/data/analytics_expense_line_classifier.dart';
import '../analytics/data/analytics_quick_expense_presets.dart';
import '../analytics/data/analytics_taxonomy_l10n.dart';

enum _FuelEdited { liters, total, perLiter }

enum _ExpenseSheetMode { fuel, expense, service }

/// Категории ТО для режима «ТО / ремонт» и для расхода с классом «Основное (ТО)».
const _kMaintServiceAnalyticsCategoryIds = <String>[
  AnalyticsTaxonomy.maintOilFilters,
  AnalyticsTaxonomy.maintEngine,
  AnalyticsTaxonomy.maintBrakes,
  AnalyticsTaxonomy.maintSuspension,
  AnalyticsTaxonomy.maintSteering,
  AnalyticsTaxonomy.maintTransmission,
  AnalyticsTaxonomy.maintElectrics,
  AnalyticsTaxonomy.maintCooling,
  AnalyticsTaxonomy.maintTires,
  AnalyticsTaxonomy.maintGlassWipers,
  AnalyticsTaxonomy.maintDiagnostics,
  AnalyticsTaxonomy.maintOther,
];

Future<void> showAddCarManualExpenseSheet(
  BuildContext context,
  WidgetRef ref, {
  required Car car,
  bool startWithFuel = true,
  CarManualExpenseRecord? existingRecord,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddCarManualExpenseSheet(
      car: car,
      startWithFuel: startWithFuel,
      existingRecord: existingRecord,
    ),
  );
}

class _AddCarManualExpenseSheet extends ConsumerStatefulWidget {
  const _AddCarManualExpenseSheet({
    required this.car,
    required this.startWithFuel,
    this.existingRecord,
  });

  final Car car;
  final bool startWithFuel;
  final CarManualExpenseRecord? existingRecord;

  @override
  ConsumerState<_AddCarManualExpenseSheet> createState() =>
      _AddCarManualExpenseSheetState();
}

class _AddCarManualExpenseSheetState
    extends ConsumerState<_AddCarManualExpenseSheet> {
  late _ExpenseSheetMode _mode;
  late DateTime _date;
  late TextEditingController _priceCtrl;
  late TextEditingController _odometerCtrl;
  late TextEditingController _litersCtrl;
  late TextEditingController _pricePerLiterCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _customTitleCtrl;
  late TextEditingController _materialCtrl;
  late TextEditingController _laborCtrl;
  late TextEditingController _stationCtrl;
  late TextEditingController _placeCtrl;

  CarManualFuelType _fuelType = CarManualFuelType.ai95;
  String _expenseGroupId = CarExpenseGroupIds.unplanned;
  String? _expenseSubId;
  bool _fuelSilent = false;
  bool _moneySilent = false;
  bool _fullTank = false;
  bool _showMoneyMismatchBanner = false;
  bool _categoryUserPicked = false;
  bool _isRecalculatingFuel = false;
  String? _suggestedCategoryId;

  String? _analyticsCategoryId;
  String? _analyticsItemTitle;
  String? _analyticsOpName;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController();
    _odometerCtrl = TextEditingController();
    _litersCtrl = TextEditingController();
    _pricePerLiterCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _customTitleCtrl = TextEditingController();
    _materialCtrl = TextEditingController();
    _laborCtrl = TextEditingController();
    _stationCtrl = TextEditingController();
    _placeCtrl = TextEditingController();

    final ex = widget.existingRecord;
    if (ex != null) {
      if (ex.isFuel) {
        _mode = _ExpenseSheetMode.fuel;
      } else {
        final g = ex.expenseGroupId?.trim();
        _mode =
            (g == CarExpenseGroupIds.maintenance ||
                ((g == null || g.isEmpty) &&
                    ex.resolvedExpenseGroupId ==
                        CarExpenseGroupIds.maintenance))
            ? _ExpenseSheetMode.service
            : _ExpenseSheetMode.expense;
      }
      _applyExistingRecord(ex);
      _categoryUserPicked = ex.expenseCategoryId?.trim().isNotEmpty ?? false;
    } else {
      _mode = widget.startWithFuel
          ? _ExpenseSheetMode.fuel
          : _ExpenseSheetMode.expense;
      _date = DateTime.now();
      _odometerCtrl.text = widget.car.mileage > 0
          ? '${widget.car.mileage}'
          : '';
      _expenseSubId = CarExpenseUnplannedSubIds.other;
      _categoryUserPicked = false;
    }
  }

  void _applyExistingRecord(CarManualExpenseRecord ex) {
    _date = ex.date;
    _priceCtrl.text = '${(ex.priceKopecks / 100).round()}';
    _odometerCtrl.text = ex.odometerKm != null ? '${ex.odometerKm}' : '';
    _noteCtrl.text = ex.note ?? '';
    if (ex.isFuel) {
      _fuelType = ex.fuelType ?? CarManualFuelType.ai95;
      if (ex.liters != null && ex.liters! > 0) {
        _litersCtrl.text = ex.liters!.toString();
      }
      if (ex.pricePerLiterKopecks != null && ex.pricePerLiterKopecks! > 0) {
        _pricePerLiterCtrl.text = (ex.pricePerLiterKopecks! / 100)
            .toStringAsFixed(2);
      }
      _stationCtrl.text = ex.fuelStationName ?? '';
      _fullTank = ex.fullTank ?? false;
      return;
    }
    _expenseGroupId = ex.expenseGroupId?.trim().isNotEmpty == true
        ? ex.expenseGroupId!.trim()
        : ex.resolvedExpenseGroupId;
    _expenseSubId = ex.expenseSubId;
    _customTitleCtrl.text = ex.customTitle?.trim() ?? '';
    if (ex.materialPriceKopecks != null && ex.materialPriceKopecks! > 0) {
      _materialCtrl.text = '${(ex.materialPriceKopecks! / 100).round()}';
    }
    if (ex.laborPriceKopecks != null && ex.laborPriceKopecks! > 0) {
      _laborCtrl.text = '${(ex.laborPriceKopecks! / 100).round()}';
    }
    _placeCtrl.text = ex.placeName ?? '';
    _analyticsCategoryId = ex.expenseCategoryId;
    _analyticsItemTitle = ex.expenseItemTitle;
    _analyticsOpName = ex.analyticsOperationName;
    final gid = _expenseGroupId;
    if (gid == CarExpenseGroupIds.maintenance) {
      final c = _analyticsCategoryId?.trim();
      if (c == null ||
          c.isEmpty ||
          !_kMaintServiceAnalyticsCategoryIds.contains(c)) {
        _analyticsCategoryId = AnalyticsTaxonomy.maintOther;
      }
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _odometerCtrl.dispose();
    _litersCtrl.dispose();
    _pricePerLiterCtrl.dispose();
    _noteCtrl.dispose();
    _customTitleCtrl.dispose();
    _materialCtrl.dispose();
    _laborCtrl.dispose();
    _stationCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  int? _parsePriceKopecks() {
    final raw = _priceCtrl.text.replaceAll(' ', '').replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final rub = int.tryParse(raw.split('.').first);
    if (rub == null || rub < 0) return null;
    return rub * 100;
  }

  int? _parseRubIntKopecks(TextEditingController c) {
    final raw = c.text.replaceAll(' ', '').replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final rub = int.tryParse(raw.split('.').first);
    if (rub == null || rub < 0) return null;
    return rub * 100;
  }

  static double? _parseLiters(String t) {
    final raw = t.replaceAll(' ', '').replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double? _parseRubPerLiterField() {
    final raw = _pricePerLiterCtrl.text
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _applyFuelMath({required _FuelEdited source}) {
    if (_fuelSilent || _isRecalculatingFuel) return;
    final liters = _parseLiters(_litersCtrl.text);
    final totalRub = int.tryParse(
      _priceCtrl.text
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .trim()
          .split('.')
          .first,
    );
    final rubPerLiter = _parseRubPerLiterField();

    final hasL = liters != null && liters > 0;
    final hasT = totalRub != null && totalRub > 0;
    final hasP = rubPerLiter != null && rubPerLiter > 0;

    _isRecalculatingFuel = true;
    _fuelSilent = true;
    try {
      switch (source) {
        case _FuelEdited.liters:
          if (hasL && hasP) {
            _priceCtrl.text = '${(liters * rubPerLiter).round()}';
          } else if (hasL && hasT) {
            _pricePerLiterCtrl.text = (totalRub / liters).toStringAsFixed(2);
          }
          break;
        case _FuelEdited.total:
          if (hasT && hasL) {
            _pricePerLiterCtrl.text = (totalRub / liters).toStringAsFixed(2);
          } else if (hasT && hasP) {
            _litersCtrl.text = (totalRub / rubPerLiter).toStringAsFixed(2);
          }
          break;
        case _FuelEdited.perLiter:
          if (hasP && hasL) {
            _priceCtrl.text = '${(liters * rubPerLiter).round()}';
          } else if (hasP && hasT) {
            _litersCtrl.text = (totalRub / rubPerLiter).toStringAsFixed(2);
          }
          break;
      }
    } finally {
      _fuelSilent = false;
      _isRecalculatingFuel = false;
    }
  }

  void _syncTotalFromMaterialLabor() {
    if (!_showMaterialLabor || _moneySilent) return;
    final rawM = _materialCtrl.text.trim();
    final rawL = _laborCtrl.text.trim();
    if (rawM.isEmpty && rawL.isEmpty) return;
    final m = _parseRubIntKopecks(_materialCtrl);
    final l = _parseRubIntKopecks(_laborCtrl);
    final mK = m ?? 0;
    final lK = l ?? 0;
    if (mK < 0 || lK < 0) return;
    final sumRub = (mK + lK) ~/ 100;
    if (sumRub <= 0) return;
    _moneySilent = true;
    try {
      _priceCtrl.text = '$sumRub';
    } finally {
      _moneySilent = false;
    }
  }

  bool get _showMaterialLabor =>
      _mode == _ExpenseSheetMode.service ||
      _expenseGroupId == CarExpenseGroupIds.accessories;

  int? _parseOdometer() {
    final raw = _odometerCtrl.text.replaceAll(' ', '').trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _pickDate(AppL10n l10n) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.palette.primary,
              surface: context.palette.cardBg,
              onSurface: context.palette.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _onGroupChanged(String? gid) {
    if (gid == null) return;
    setState(() {
      _expenseGroupId = gid;
      _analyticsItemTitle = null;
      _analyticsOpName = null;
      _categoryUserPicked = false;
      _suggestedCategoryId = null;
      if (gid == CarExpenseGroupIds.maintenance) {
        _analyticsCategoryId = AnalyticsTaxonomy.maintOther;
      } else {
        _analyticsCategoryId = null;
      }
      if (gid == CarExpenseGroupIds.accessories) {
        _expenseSubId = CarExpenseAccessorySubIds.replace;
      } else if (gid == CarExpenseGroupIds.unplanned) {
        _expenseSubId = CarExpenseUnplannedSubIds.other;
      } else {
        _expenseSubId = null;
      }
      if (!_showMaterialLabor) {
        _materialCtrl.clear();
        _laborCtrl.clear();
      }
    });
  }

  String? _subIdForSave(AppL10n l10n) {
    if (_expenseGroupId == CarExpenseGroupIds.accessories) {
      return _expenseSubId ?? CarExpenseAccessorySubIds.replace;
    }
    if (_expenseGroupId == CarExpenseGroupIds.unplanned) {
      return _expenseSubId ?? CarExpenseUnplannedSubIds.other;
    }
    return null;
  }

  void _applyConsumablePreset(CarConsumablePreset p, AppL10n l10n) {
    setState(() {
      switch (p.id) {
        case 'wiper':
        case 'washer':
        case 'cosmetic':
          _expenseGroupId = CarExpenseGroupIds.cleanComfort;
          _expenseSubId = null;
          break;
        case 'lamps':
          _expenseGroupId = CarExpenseGroupIds.accessories;
          _expenseSubId = CarExpenseAccessorySubIds.purchase;
          break;
        case 'tires_repair':
          _expenseGroupId = CarExpenseGroupIds.unplanned;
          _expenseSubId = CarExpenseUnplannedSubIds.tireService;
          break;
        default:
          _expenseGroupId = CarExpenseGroupIds.unplanned;
          _expenseSubId = CarExpenseUnplannedSubIds.other;
      }
      _customTitleCtrl.text = p.title(l10n);
      _analyticsCategoryId = null;
      _analyticsItemTitle = null;
      _analyticsOpName = null;
      _categoryUserPicked = false;
      _suggestedCategoryId = null;
    });
  }

  void _applyQuickPreset(AnalyticsQuickExpensePreset pr, AppL10n l10n) {
    setState(() {
      _expenseGroupId = pr.groupId;
      _expenseSubId = null;
      _customTitleCtrl.text = pr.title(l10n.isEn);
      _analyticsCategoryId = pr.categoryId;
      _analyticsItemTitle = pr.title(l10n.isEn);
      _analyticsOpName = pr.operation.name;
      _categoryUserPicked = false;
      _suggestedCategoryId = null;
    });
  }

  List<String> _fuelStationSuggestions() {
    final all = visibleCarManualExpenses(ref.read(carManualExpensesProvider));
    final names = <String>{};
    var userHadShell = false;
    for (final e in all) {
      if (!e.isFuel) continue;
      final n = e.fuelStationName?.trim();
      if (n == null || n.isEmpty) continue;
      names.add(n);
      if (n.toLowerCase() == 'shell') userHadShell = true;
    }
    const defaults = [
      'Лукойл',
      'Газпромнефть',
      'Роснефть',
      'Татнефть',
      'Башнефть',
    ];
    for (final d in defaults) {
      names.add(d);
    }
    if (userHadShell) names.add('Shell');
    final list = names.toList()..sort();
    return list.take(24).toList();
  }

  List<String> _collectTitleSuggestions() {
    final counts = <String, int>{};
    void add(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return;
      counts[t] = (counts[t] ?? 0) + 1;
    }

    for (final e in visibleCarManualExpenses(
      ref.read(carManualExpensesProvider),
    )) {
      if (e.carId != widget.car.id || e.isFuel) continue;
      add(e.customTitle);
      add(e.expenseItemTitle);
    }
    for (final pr in kAnalyticsQuickExpensePresets) {
      add(pr.title(false));
      add(pr.title(true));
    }
    for (final p in kCarConsumablePresets) {
      add(p.titleRu);
      add(p.titleEn);
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        if (c != 0) return c;
        return a.compareTo(b);
      });
    return keys.take(32).toList();
  }

  List<String> _collectPlaceSuggestions() {
    final names = <String>{};
    for (final e in visibleCarManualExpenses(
      ref.read(carManualExpensesProvider),
    )) {
      if (e.carId != widget.car.id) continue;
      final p = e.placeName?.trim();
      if (p != null && p.isNotEmpty) names.add(p);
      if (e.isFuel) {
        final s = e.fuelStationName?.trim();
        if (s != null && s.isNotEmpty) names.add(s);
      }
    }
    ref
        .read(ordersProvider)
        .whenOrNull(
          data: (orders) {
            for (final o in orders) {
              if (o.carId != widget.car.id) continue;
              final n = o.stoName.trim();
              if (n.isNotEmpty) names.add(n);
            }
          },
        );
    final list = names.toList()..sort();
    return list.take(40).toList();
  }

  void _onCustomTitleChanged(AppL10n l10n) {
    if (_mode != _ExpenseSheetMode.expense || _categoryUserPicked) {
      if (_suggestedCategoryId != null) {
        setState(() => _suggestedCategoryId = null);
      }
      return;
    }
    final t = _customTitleCtrl.text.trim();
    if (t.length < 3) {
      setState(() => _suggestedCategoryId = null);
      return;
    }
    final cl = AnalyticsExpenseLineClassifier.classify(t, '');
    setState(() => _suggestedCategoryId = cl.categoryId);
  }

  bool _hasMaterialLaborMismatch(int totalK, int? matK, int? labK) {
    if (!_showMaterialLabor) return false;
    final rawM = _materialCtrl.text.trim();
    final rawL = _laborCtrl.text.trim();
    if (rawM.isEmpty && rawL.isEmpty) return false;
    final m = matK ?? 0;
    final l = labK ?? 0;
    return m + l != totalK;
  }

  Future<bool> _confirmMismatchSave(AppL10n l10n) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.analyticsManualMismatchDialogTitle),
        content: Text(l10n.analyticsManualMismatchDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.analyticsManualCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.analyticsManualSaveAnyway),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _save(AppL10n l10n) async {
    final k = _parsePriceKopecks();
    if (k == null || k <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.analyticsManualInvalidPrice),
          backgroundColor: context.palette.error,
        ),
      );
      return;
    }
    final id =
        widget.existingRecord?.id ??
        'mane_${DateTime.now().microsecondsSinceEpoch}';
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final isEdit = widget.existingRecord != null;
    final notifier = ref.read(carManualExpensesProvider.notifier);
    if (_mode == _ExpenseSheetMode.fuel) {
      var lit = _parseLiters(_litersCtrl.text);
      final rubPl = _parseRubPerLiterField();
      final totalRub = int.tryParse(
        _priceCtrl.text
            .replaceAll(' ', '')
            .replaceAll(',', '.')
            .trim()
            .split('.')
            .first,
      );
      if ((lit == null || lit <= 0) &&
          totalRub != null &&
          totalRub > 0 &&
          rubPl != null &&
          rubPl > 0) {
        lit = totalRub / rubPl;
      }
      if (lit != null && lit <= 0) lit = null;
      int? pplK;
      if (lit != null && lit > 0) {
        if (rubPl != null && rubPl > 0) {
          pplK = (rubPl * 100).round();
        } else {
          pplK = (k / lit).round();
        }
      } else {
        pplK = null;
      }
      final odo = _parseOdometer();
      final station = _stationCtrl.text.trim();
      final record = CarManualExpenseRecord(
        id: id,
        carId: widget.car.id,
        date: _date,
        priceKopecks: k,
        kind: CarManualExpenseKind.fuel,
        fuelType: _fuelType,
        liters: lit,
        pricePerLiterKopecks: pplK,
        odometerKm: odo,
        note: note,
        fuelStationName: station.isEmpty ? null : station,
        fullTank: _fullTank,
      );
      if (isEdit) {
        notifier.update(record);
      } else {
        notifier.add(record);
      }
    } else {
      if (_mode == _ExpenseSheetMode.service) {
        _expenseGroupId = CarExpenseGroupIds.maintenance;
      }
      final title = _customTitleCtrl.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.analyticsManualNeedTitle),
            backgroundColor: context.palette.error,
          ),
        );
        return;
      }
      final matK = _parseRubIntKopecks(_materialCtrl);
      final labK = _parseRubIntKopecks(_laborCtrl);
      if (_hasMaterialLaborMismatch(k, matK, labK)) {
        setState(() => _showMoneyMismatchBanner = true);
        final ok = await _confirmMismatchSave(l10n);
        if (!mounted) return;
        if (!ok) return;
      } else {
        setState(() => _showMoneyMismatchBanner = false);
      }

      var categoryId = _analyticsCategoryId?.trim();
      var itemTitle = _analyticsItemTitle?.trim();
      var opName = _analyticsOpName?.trim();
      if (!_categoryUserPicked && (categoryId == null || categoryId.isEmpty)) {
        final cl = AnalyticsExpenseLineClassifier.classify(title, '');
        categoryId = cl.categoryId;
        opName ??= cl.op.name;
      }
      if (_mode == _ExpenseSheetMode.service) {
        if (categoryId == null ||
            categoryId.isEmpty ||
            !_kMaintServiceAnalyticsCategoryIds.contains(categoryId)) {
          categoryId = AnalyticsTaxonomy.maintOther;
        }
      }
      itemTitle = (itemTitle == null || itemTitle.isEmpty) ? title : itemTitle;

      final place = _placeCtrl.text.trim();

      final prev = widget.existingRecord;
      final record = CarManualExpenseRecord(
        id: id,
        carId: widget.car.id,
        date: _date,
        priceKopecks: k,
        kind: prev?.kind ?? CarManualExpenseKind.custom,
        presetId: prev?.presetId,
        customTitle: title,
        odometerKm: _parseOdometer(),
        note: note,
        expenseGroupId: _expenseGroupId,
        expenseSubId: _subIdForSave(l10n),
        materialPriceKopecks: matK,
        laborPriceKopecks: labK,
        placeName: place.isEmpty ? null : place,
        expenseCategoryId: categoryId,
        expenseItemTitle: itemTitle,
        analyticsOperationName: opName,
      );
      if (isEdit) {
        notifier.update(record);
      } else {
        notifier.add(record);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  void _onPriceOrPartsChanged() {
    final k = _parsePriceKopecks();
    final matK = _parseRubIntKopecks(_materialCtrl);
    final labK = _parseRubIntKopecks(_laborCtrl);
    final mis = k != null && _hasMaterialLaborMismatch(k, matK, labK);
    setState(() => _showMoneyMismatchBanner = mis);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: p.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existingRecord != null
                          ? l10n.analyticsManualEditTitle
                          : l10n.analyticsManualAdd,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: IgnorePointer(
                ignoring: widget.existingRecord != null,
                child: Opacity(
                  opacity: widget.existingRecord != null ? 0.55 : 1,
                  child: SegmentedButton<_ExpenseSheetMode>(
                    segments: [
                      ButtonSegment<_ExpenseSheetMode>(
                        value: _ExpenseSheetMode.fuel,
                        label: Text(l10n.analyticsManualTabFuel),
                        icon: const Icon(
                          Icons.local_gas_station_rounded,
                          size: 18,
                        ),
                      ),
                      ButtonSegment<_ExpenseSheetMode>(
                        value: _ExpenseSheetMode.expense,
                        label: Text(l10n.analyticsManualTabOther),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      ),
                      ButtonSegment<_ExpenseSheetMode>(
                        value: _ExpenseSheetMode.service,
                        label: Text(l10n.analyticsManualTabService),
                        icon: const Icon(Icons.handyman_outlined, size: 18),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      setState(() {
                        _mode = s.first;
                        if (_mode == _ExpenseSheetMode.service) {
                          _expenseGroupId = CarExpenseGroupIds.maintenance;
                          _expenseSubId = null;
                          _categoryUserPicked = false;
                          _suggestedCategoryId = null;
                        }
                      });
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(p.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.existingRecord != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  l10n.analyticsManualEditTypeLockedHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.textTertiary,
                    height: 1.35,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _mode == _ExpenseSheetMode.fuel
                    ? _buildFuelForm(l10n)
                    : _buildOtherForm(l10n),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: () => _save(l10n),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    widget.existingRecord != null
                        ? l10n.analyticsManualSave
                        : l10n.analyticsManualAdd,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelForm(AppL10n l10n) {
    final p = context.palette;
    final stations = _fuelStationSuggestions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.analyticsManualFuelSectionTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n.analyticsManualDate,
            style: TextStyle(color: p.textTertiary, fontSize: 12),
          ),
          subtitle: Text(
            DateFormat('d MMM yyyy', l10n.intlLocale).format(_date),
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(Icons.event_rounded, color: p.primary),
          onTap: () => _pickDate(l10n),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _odometerCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco(
            l10n,
            l10n.analyticsManualOdometerKm,
            p,
          ).copyWith(hintText: l10n.analyticsManualOdometerRecommended),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _litersCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDeco(l10n, l10n.analyticsManualLiters, p),
          onChanged: (_) => _applyFuelMath(source: _FuelEdited.liters),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _pricePerLiterCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: _inputDeco(l10n, l10n.analyticsManualPricePerLiter, p),
          onChanged: (_) => _applyFuelMath(source: _FuelEdited.perLiter),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco(l10n, l10n.analyticsManualPriceRub, p),
          onChanged: (_) => _applyFuelMath(source: _FuelEdited.total),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _stationCtrl,
          decoration: _inputDeco(
            l10n,
            l10n.analyticsManualFuelStation,
            p,
          ).copyWith(hintText: l10n.analyticsManualStationHint),
        ),
        if (stations.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            l10n.analyticsManualSuggestionsTitle,
            style: TextStyle(fontSize: 11, color: p.textTertiary),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: stations.take(10).map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _stationCtrl.text = s;
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n.analyticsManualFullTank,
            style: TextStyle(color: p.textPrimary, fontSize: 14),
          ),
          subtitle: Text(
            l10n.analyticsManualFullTankHint,
            style: TextStyle(fontSize: 11, color: p.textTertiary, height: 1.3),
          ),
          value: _fullTank,
          onChanged: (v) => setState(() => _fullTank = v),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            l10n.analyticsManualDetailsExpand,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          children: [
            DropdownButtonFormField<CarManualFuelType>(
              initialValue: _fuelType,
              decoration: _inputDeco(l10n, l10n.analyticsManualFuelType, p),
              items: CarManualFuelType.values
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.label(l10n))),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _fuelType = v ?? CarManualFuelType.ai95),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: _inputDeco(l10n, l10n.analyticsManualNote, p),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDeco(AppL10n l10n, String label, ClientPalette p) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: p.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.border),
      ),
    );
  }

  Widget _buildOtherForm(AppL10n l10n) {
    final p = context.palette;
    final groups = <String>[
      CarExpenseGroupIds.maintenance,
      CarExpenseGroupIds.ownership,
      CarExpenseGroupIds.accessories,
      CarExpenseGroupIds.cleanComfort,
      CarExpenseGroupIds.unplanned,
      CarExpenseGroupIds.other,
    ];
    final titleSuggestions = _collectTitleSuggestions();
    final placeSuggestions = _collectPlaceSuggestions();
    final selMaintCat =
        (_analyticsCategoryId != null &&
            _kMaintServiceAnalyticsCategoryIds.contains(_analyticsCategoryId))
        ? _analyticsCategoryId!
        : _kMaintServiceAnalyticsCategoryIds.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _mode == _ExpenseSheetMode.service
              ? l10n.analyticsManualServiceSectionTitle
              : l10n.analyticsManualExpenseSectionTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n.analyticsManualDate,
            style: TextStyle(color: p.textTertiary, fontSize: 12),
          ),
          subtitle: Text(
            DateFormat('d MMM yyyy', l10n.intlLocale).format(_date),
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(Icons.event_rounded, color: p.primary),
          onTap: () => _pickDate(l10n),
        ),
        const SizedBox(height: 8),
        if (_mode == _ExpenseSheetMode.service) ...[
          Text(
            l10n.carExpenseClassGroupTitle(CarExpenseGroupIds.maintenance),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selMaintCat,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualPreset, p),
            items: _kMaintServiceAnalyticsCategoryIds
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(
                      l10n.analyticsTaxCategoryTitle(id),
                      maxLines: 2,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _analyticsCategoryId = v;
                _categoryUserPicked = true;
                _suggestedCategoryId = null;
              });
            },
          ),
          const SizedBox(height: 10),
        ] else ...[
          Text(
            l10n.analyticsManualExpenseClass,
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _expenseGroupId,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualExpenseClass, p),
            items: groups
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(
                      l10n.carExpenseClassGroupTitle(id),
                      maxLines: 2,
                    ),
                  ),
                )
                .toList(),
            onChanged: _onGroupChanged,
          ),
        ],
        if (_mode == _ExpenseSheetMode.expense &&
            _expenseGroupId == CarExpenseGroupIds.maintenance) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selMaintCat,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualPreset, p),
            items: _kMaintServiceAnalyticsCategoryIds
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(
                      l10n.analyticsTaxCategoryTitle(id),
                      maxLines: 2,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _analyticsCategoryId = v;
                _categoryUserPicked = true;
                _suggestedCategoryId = null;
              });
            },
          ),
        ],
        if (_expenseGroupId == CarExpenseGroupIds.accessories) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _expenseSubId ?? CarExpenseAccessorySubIds.replace,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualExpenseSub, p),
            items:
                [
                      CarExpenseAccessorySubIds.replace,
                      CarExpenseAccessorySubIds.retrofit,
                      CarExpenseAccessorySubIds.purchase,
                    ]
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(
                          l10n.carExpenseClassSubTitle(id) ?? id,
                          maxLines: 2,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _expenseSubId = v),
          ),
        ],
        if (_expenseGroupId == CarExpenseGroupIds.unplanned) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _expenseSubId ?? CarExpenseUnplannedSubIds.other,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualExpenseSub, p),
            items:
                [
                      CarExpenseUnplannedSubIds.fine,
                      CarExpenseUnplannedSubIds.tireService,
                      CarExpenseUnplannedSubIds.other,
                    ]
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(
                          l10n.carExpenseClassSubTitle(id) ?? id,
                          maxLines: 2,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _expenseSubId = v),
          ),
        ],
        if (_mode == _ExpenseSheetMode.expense) ...[
          const SizedBox(height: 12),
          Text(
            l10n.analyticsManualQuickItems,
            style: TextStyle(fontSize: 11, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAnalyticsQuickExpensePresets
                .map(
                  (preset) => ActionChip(
                    label: Text(
                      preset.title(l10n.isEn),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _applyQuickPreset(preset, l10n),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.analyticsManualClassicPresets,
            style: TextStyle(fontSize: 11, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCarConsumablePresets
                .map(
                  (preset) => ActionChip(
                    label: Text(
                      preset.title(l10n),
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () =>
                        setState(() => _applyConsumablePreset(preset, l10n)),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _customTitleCtrl,
          decoration: _inputDeco(
            l10n,
            l10n.analyticsManualCustomTitle,
            p,
          ).copyWith(hintText: l10n.analyticsManualCustomHint),
          onChanged: (_) => _onCustomTitleChanged(l10n),
        ),
        if (_mode == _ExpenseSheetMode.expense &&
            titleSuggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            l10n.analyticsManualSuggestionsTitle,
            style: TextStyle(fontSize: 11, color: p.textTertiary),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: titleSuggestions.take(12).map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _customTitleCtrl.text = s;
                  _onCustomTitleChanged(l10n);
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
        if (_mode == _ExpenseSheetMode.expense &&
            !_categoryUserPicked &&
            _suggestedCategoryId != null &&
            (_analyticsCategoryId == null ||
                _analyticsCategoryId != _suggestedCategoryId)) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${l10n.analyticsManualSuggestedCategoryPrefix} ${l10n.analyticsTaxCategoryTitle(_suggestedCategoryId!)}',
                    style: TextStyle(fontSize: 12, color: p.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _analyticsCategoryId = _suggestedCategoryId;
                      final cl = AnalyticsExpenseLineClassifier.classify(
                        _customTitleCtrl.text.trim(),
                        '',
                      );
                      _analyticsOpName ??= cl.op.name;
                      _categoryUserPicked = true;
                    });
                  },
                  child: Text(l10n.analyticsManualApplySuggestion),
                ),
              ],
            ),
          ),
        ],
        if (_showMaterialLabor) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _materialCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(
              l10n,
              _mode == _ExpenseSheetMode.service
                  ? l10n.analyticsManualMaterialCost
                  : l10n.analyticsManualMaterialRub,
              p,
            ).copyWith(hintText: l10n.analyticsManualOdometerOptional),
            onChanged: (_) {
              if (!_moneySilent) _syncTotalFromMaterialLabor();
              _onPriceOrPartsChanged();
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _laborCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(
              l10n,
              _mode == _ExpenseSheetMode.service
                  ? l10n.analyticsManualLaborCost
                  : l10n.analyticsManualLaborRub,
              p,
            ).copyWith(hintText: l10n.analyticsManualOdometerOptional),
            onChanged: (_) {
              if (!_moneySilent) _syncTotalFromMaterialLabor();
              _onPriceOrPartsChanged();
            },
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco(
            l10n,
            _mode == _ExpenseSheetMode.service
                ? l10n.analyticsManualTotalCost
                : l10n.analyticsManualPriceRub,
            p,
          ),
          onChanged: (_) => _onPriceOrPartsChanged(),
        ),
        if (_showMoneyMismatchBanner) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: p.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.analyticsManualSumMismatchTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.analyticsManualSumMismatchBody,
                        style: TextStyle(
                          fontSize: 12,
                          color: p.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_mode == _ExpenseSheetMode.service) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _odometerCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(
              l10n,
              l10n.analyticsManualOdometerKm,
              p,
            ).copyWith(hintText: l10n.analyticsManualOdometerOptional),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _placeCtrl,
            decoration: _inputDeco(
              l10n,
              l10n.analyticsJournalColPlace,
              p,
            ).copyWith(hintText: l10n.analyticsManualPlaceHint),
          ),
          if (placeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.analyticsManualSuggestionsTitle,
              style: TextStyle(fontSize: 11, color: p.textTertiary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: placeSuggestions.take(12).map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _placeCtrl.text = s;
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          ],
        ],
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            l10n.analyticsManualDetailsExpand,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          children: [
            if (_mode == _ExpenseSheetMode.expense) ...[
              TextField(
                controller: _odometerCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDeco(
                  l10n,
                  l10n.analyticsManualOdometerKm,
                  p,
                ).copyWith(hintText: l10n.analyticsManualOdometerOptional),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _placeCtrl,
                decoration: _inputDeco(
                  l10n,
                  l10n.analyticsJournalColPlace,
                  p,
                ).copyWith(hintText: l10n.analyticsManualPlaceHint),
              ),
              if (placeSuggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.analyticsManualSuggestionsTitle,
                  style: TextStyle(fontSize: 11, color: p.textTertiary),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: placeSuggestions.take(12).map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _placeCtrl.text = s;
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: _inputDeco(l10n, l10n.analyticsManualNote, p),
              ),
            ],
            if (_mode == _ExpenseSheetMode.service) ...[
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: _inputDeco(l10n, l10n.analyticsManualNote, p),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
