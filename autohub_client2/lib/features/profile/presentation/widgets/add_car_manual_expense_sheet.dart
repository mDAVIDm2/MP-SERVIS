import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/settings/car_expense_group_ids.dart';
import '../../../../core/settings/car_manual_expenses_provider.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/car_model.dart';

enum _FuelEdited { liters, total, perLiter }

Future<void> showAddCarManualExpenseSheet(
  BuildContext context,
  WidgetRef ref, {
  required Car car,
  bool startWithFuel = true,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddCarManualExpenseSheet(
      car: car,
      startWithFuel: startWithFuel,
    ),
  );
}

class _AddCarManualExpenseSheet extends ConsumerStatefulWidget {
  const _AddCarManualExpenseSheet({
    required this.car,
    required this.startWithFuel,
  });

  final Car car;
  final bool startWithFuel;

  @override
  ConsumerState<_AddCarManualExpenseSheet> createState() => _AddCarManualExpenseSheetState();
}

class _AddCarManualExpenseSheetState extends ConsumerState<_AddCarManualExpenseSheet> {
  late bool _isFuel;
  late DateTime _date;
  late TextEditingController _priceCtrl;
  late TextEditingController _odometerCtrl;
  late TextEditingController _litersCtrl;
  late TextEditingController _pricePerLiterCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _customTitleCtrl;
  late TextEditingController _materialCtrl;
  late TextEditingController _laborCtrl;
  CarManualFuelType _fuelType = CarManualFuelType.ai95;
  String _expenseGroupId = CarExpenseGroupIds.unplanned;
  String? _expenseSubId;
  bool _fuelSilent = false;
  bool _moneySilent = false;

  @override
  void initState() {
    super.initState();
    _isFuel = widget.startWithFuel;
    _date = DateTime.now();
    _priceCtrl = TextEditingController();
    _odometerCtrl = TextEditingController(text: widget.car.mileage > 0 ? '${widget.car.mileage}' : '');
    _litersCtrl = TextEditingController();
    _pricePerLiterCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _customTitleCtrl = TextEditingController();
    _materialCtrl = TextEditingController();
    _laborCtrl = TextEditingController();
    _expenseSubId = CarExpenseUnplannedSubIds.other;
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
    final raw = _pricePerLiterCtrl.text.replaceAll(' ', '').replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _applyFuelMath({required _FuelEdited source}) {
    if (_fuelSilent) return;
    final liters = _parseLiters(_litersCtrl.text);
    final totalRub =
        int.tryParse(_priceCtrl.text.replaceAll(' ', '').replaceAll(',', '.').trim().split('.').first);
    final rubPerLiter = _parseRubPerLiterField();

    final hasL = liters != null && liters > 0;
    final hasT = totalRub != null && totalRub > 0;
    final hasP = rubPerLiter != null && rubPerLiter > 0;

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
    }
  }

  void _syncTotalFromMaterialLabor() {
    if (!_showMaterialLabor || _moneySilent) return;
    final m = _parseRubIntKopecks(_materialCtrl);
    final l = _parseRubIntKopecks(_laborCtrl);
    if (m == null || l == null) return;
    if (m < 0 || l < 0) return;
    final sumRub = (m + l) ~/ 100;
    if (sumRub <= 0) return;
    _moneySilent = true;
    try {
      _priceCtrl.text = '$sumRub';
    } finally {
      _moneySilent = false;
    }
  }

  bool get _showMaterialLabor => _expenseGroupId == CarExpenseGroupIds.accessories;

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

  void _applyPreset(CarConsumablePreset p, AppL10n l10n) {
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
    });
  }

  void _save(AppL10n l10n) {
    final k = _parsePriceKopecks();
    if (k == null || k <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analyticsManualInvalidPrice), backgroundColor: context.palette.error),
      );
      return;
    }
    final id = 'mane_${DateTime.now().microsecondsSinceEpoch}';
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    if (_isFuel) {
      final l = _parseLiters(_litersCtrl.text);
      if (l == null || l <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.analyticsManualFillFuel), backgroundColor: context.palette.warning),
        );
        return;
      }
      final odo = _parseOdometer();
      final rubPl = _parseRubPerLiterField();
      int? pplK;
      if (rubPl != null && rubPl > 0) {
        pplK = (rubPl * 100).round();
      } else if (l > 0) {
        pplK = (k / l).round();
      }
      ref.read(carManualExpensesProvider.notifier).add(
            CarManualExpenseRecord(
              id: id,
              carId: widget.car.id,
              date: _date,
              priceKopecks: k,
              kind: CarManualExpenseKind.fuel,
              fuelType: _fuelType,
              liters: l,
              pricePerLiterKopecks: pplK,
              odometerKm: odo,
              note: note,
            ),
          );
    } else {
      final title = _customTitleCtrl.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.analyticsManualCustomTitle),
            backgroundColor: context.palette.error,
          ),
        );
        return;
      }
      final matK = _parseRubIntKopecks(_materialCtrl);
      final labK = _parseRubIntKopecks(_laborCtrl);
      if (_showMaterialLabor && matK != null && labK != null && matK >= 0 && labK >= 0) {
        if (matK + labK != k) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.analyticsManualTotalMismatch),
              backgroundColor: context.palette.error,
            ),
          );
          return;
        }
      }
      ref.read(carManualExpensesProvider.notifier).add(
            CarManualExpenseRecord(
              id: id,
              carId: widget.car.id,
              date: _date,
              priceKopecks: k,
              kind: CarManualExpenseKind.custom,
              customTitle: title,
              odometerKm: _parseOdometer(),
              note: note,
              expenseGroupId: _expenseGroupId,
              expenseSubId: _subIdForSave(l10n),
              materialPriceKopecks: matK,
              laborPriceKopecks: labK,
            ),
          );
    }
    if (context.mounted) Navigator.pop(context);
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
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                      l10n.analyticsManualAdd,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
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
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(value: true, label: Text(l10n.analyticsManualTabFuel), icon: const Icon(Icons.local_gas_station_rounded, size: 18)),
                  ButtonSegment<bool>(value: false, label: Text(l10n.analyticsManualTabOther), icon: const Icon(Icons.shopping_bag_outlined, size: 18)),
                ],
                selected: {_isFuel},
                onSelectionChanged: (s) => setState(() => _isFuel = s.first),
                style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(p.textPrimary)),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _isFuel ? _buildFuelForm(l10n) : _buildOtherForm(l10n),
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
                  child: Text(l10n.analyticsManualAdd),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.analyticsManualDate, style: TextStyle(color: p.textTertiary, fontSize: 12)),
          subtitle: Text(
            DateFormat('d MMM yyyy', l10n.intlLocale).format(_date),
            style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: Icon(Icons.event_rounded, color: p.primary),
          onTap: () => _pickDate(l10n),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<CarManualFuelType>(
          value: _fuelType,
          decoration: _inputDeco(l10n, l10n.analyticsManualFuelType, p),
          items: CarManualFuelType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label(l10n)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _fuelType = v ?? CarManualFuelType.ai95),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _odometerCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco(l10n, l10n.analyticsManualOdometerKm, p),
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
          controller: _noteCtrl,
          maxLines: 3,
          decoration: _inputDeco(l10n, l10n.analyticsManualNote, p),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(AppL10n l10n, String label, ClientPalette p) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: p.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
    );
  }

  Widget _buildOtherForm(AppL10n l10n) {
    final p = context.palette;
    final groups = <String>[
      CarExpenseGroupIds.accessories,
      CarExpenseGroupIds.unplanned,
      CarExpenseGroupIds.maintenance,
      CarExpenseGroupIds.ownership,
      CarExpenseGroupIds.cleanComfort,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.analyticsManualDate, style: TextStyle(color: p.textTertiary, fontSize: 12)),
          subtitle: Text(
            DateFormat('d MMM yyyy', l10n.intlLocale).format(_date),
            style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: Icon(Icons.event_rounded, color: p.primary),
          onTap: () => _pickDate(l10n),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.analyticsManualExpenseClass,
          style: TextStyle(fontSize: 12, color: p.textTertiary),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _expenseGroupId,
          isExpanded: true,
          decoration: _inputDeco(l10n, l10n.analyticsManualExpenseClass, p),
          items: groups
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(l10n.carExpenseClassGroupTitle(id), maxLines: 2),
                ),
              )
              .toList(),
          onChanged: _onGroupChanged,
        ),
        if (_expenseGroupId == CarExpenseGroupIds.accessories) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _expenseSubId ?? CarExpenseAccessorySubIds.replace,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualExpenseSub, p),
            items: [
              CarExpenseAccessorySubIds.replace,
              CarExpenseAccessorySubIds.retrofit,
              CarExpenseAccessorySubIds.purchase,
            ]
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(l10n.carExpenseClassSubTitle(id) ?? id, maxLines: 2),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _expenseSubId = v),
          ),
        ],
        if (_expenseGroupId == CarExpenseGroupIds.unplanned) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _expenseSubId ?? CarExpenseUnplannedSubIds.other,
            isExpanded: true,
            decoration: _inputDeco(l10n, l10n.analyticsManualExpenseSub, p),
            items: [
              CarExpenseUnplannedSubIds.fine,
              CarExpenseUnplannedSubIds.tireService,
              CarExpenseUnplannedSubIds.other,
            ]
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(l10n.carExpenseClassSubTitle(id) ?? id, maxLines: 2),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _expenseSubId = v),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _customTitleCtrl,
          decoration: _inputDeco(l10n, l10n.analyticsManualCustomTitle, p).copyWith(
            hintText: l10n.analyticsManualCustomHint,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _odometerCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco(l10n, l10n.analyticsManualOdometerKm, p).copyWith(
            hintText: l10n.isEn ? 'optional' : 'по желанию',
          ),
        ),
        if (_showMaterialLabor) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _materialCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(l10n, l10n.analyticsManualMaterialRub, p).copyWith(
              hintText: l10n.isEn ? 'optional' : 'необязательно',
            ),
            onChanged: (_) {
              if (!_moneySilent) _syncTotalFromMaterialLabor();
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _laborCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(l10n, l10n.analyticsManualLaborRub, p).copyWith(
              hintText: l10n.isEn ? 'optional' : 'необязательно',
            ),
            onChanged: (_) {
              if (!_moneySilent) _syncTotalFromMaterialLabor();
            },
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco(l10n, l10n.analyticsManualPriceRub, p),
        ),
        const SizedBox(height: 12),
        Text(l10n.analyticsManualPreset, style: TextStyle(fontSize: 12, color: p.textTertiary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCarConsumablePresets
              .map(
                (preset) => ActionChip(
                  label: Text(preset.title(l10n), style: const TextStyle(fontSize: 13)),
                  onPressed: () => setState(() => _applyPreset(preset, l10n)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: _inputDeco(l10n, l10n.analyticsManualNote, p),
        ),
      ],
    );
  }
}
