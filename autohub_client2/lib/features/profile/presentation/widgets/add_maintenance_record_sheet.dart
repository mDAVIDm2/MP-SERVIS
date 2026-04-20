import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../shared/models/car_model.dart';

/// Нижняя панель: добавить запись о выполненном ТО (дата, пробег, место, тип работ).
Future<void> showAddMaintenanceRecordSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Car> cars,
  Car? initialCar,
  MaintenanceType? initialType,
}) async {
  if (cars.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddMaintenanceRecordSheetBody(
      cars: cars,
      initialCar: initialCar ?? cars.first,
      initialType: initialType,
    ),
  );
}

class _AddMaintenanceRecordSheetBody extends ConsumerStatefulWidget {
  const _AddMaintenanceRecordSheetBody({
    required this.cars,
    required this.initialCar,
    this.initialType,
  });

  final List<Car> cars;
  final Car initialCar;
  final MaintenanceType? initialType;

  @override
  ConsumerState<_AddMaintenanceRecordSheetBody> createState() => _AddMaintenanceRecordSheetBodyState();
}

class _AddMaintenanceRecordSheetBodyState extends ConsumerState<_AddMaintenanceRecordSheetBody> {
  /// Высота блока «дата + пробег + место» (подогнано под отступы полей).
  static const double _kDetailsBlockHeight = 252;
  /// За столько пикселей прокрутки списка видов работ блок сворачивается от 100% до 0%.
  static const double _kHeaderCollapseScrollRange = 176;

  late Car _car;
  final Set<MaintenanceType> _selectedTypes = {};
  late DateTime _date;
  late TextEditingController _kmCtrl;
  late TextEditingController _placeCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _kmFocus = FocusNode();
  final FocusNode _placeFocus = FocusNode();
  final GlobalKey _kmFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _car = widget.initialCar;
    if (widget.initialType != null) {
      _selectedTypes.add(widget.initialType!);
    }
    _date = DateTime.now();
    _kmCtrl = TextEditingController(text: '${_car.mileage}');
    _placeCtrl = TextEditingController();
    _searchCtrl.addListener(() => setState(() {}));
    _scrollController.addListener(_onScrollList);
    _kmFocus.addListener(() {
      if (_kmFocus.hasFocus) _ensureKmVisible();
    });
    _placeFocus.addListener(() {
      if (_placeFocus.hasFocus) _ensurePlaceVisible();
    });
  }

  void _onScrollList() {
    if (mounted) setState(() {});
  }

  /// 0 — блок полностью виден, 1 — полностью скрыт (плавно от прокрутки списка).
  double get _headerCollapse01 {
    if (!_scrollController.hasClients) return 0;
    final o = _scrollController.offset;
    if (_kHeaderCollapseScrollRange <= 0) return 0;
    return (o / _kHeaderCollapseScrollRange).clamp(0.0, 1.0);
  }

  void _ensureKmVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _kmFieldKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _ensurePlaceVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollList);
    _scrollController.dispose();
    _kmCtrl.dispose();
    _placeCtrl.dispose();
    _searchCtrl.dispose();
    _kmFocus.dispose();
    _placeFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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

  void _save(AppL10n l10n) {
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectAtLeastOneJobType), backgroundColor: context.palette.error),
      );
      return;
    }
    final km = int.tryParse(_kmCtrl.text.replaceAll(' ', '').trim());
    if (km == null || km < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterValidMileage), backgroundColor: context.palette.error),
      );
      return;
    }
    final place = _placeCtrl.text.trim().isEmpty ? null : _placeCtrl.text.trim();
    final base = DateTime.now().millisecondsSinceEpoch;
    final notifier = ref.read(maintenanceRemindersProvider.notifier);
    var i = 0;
    for (final type in _selectedTypes) {
      notifier.addRecord(
        MaintenanceRecord(
          id: 'man_${base}_${i}_${type.name}',
          carId: _car.id,
          typeKey: type.name,
          odometerKm: km,
          date: _date,
          place: place,
        ),
      );
      i++;
    }
    final msg = _selectedTypes.length == 1
        ? l10n.recordAdded(_selectedTypes.first.localizedTitle(l10n))
        : l10n.recordsAddedCount(_selectedTypes.length);
    final successColor = context.palette.success;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: successColor,
      ),
    );
  }

  Set<MaintenanceType> _filteredTypes(AppL10n l10n) {
    final all = MaintenanceType.values.toSet();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (t) =>
              t.localizedTitle(l10n).toLowerCase().contains(q) ||
              t.localizedSubtitle(l10n).toLowerCase().contains(q) ||
              t.name.toLowerCase().contains(q),
        )
        .toSet();
  }

  Widget _dateRow(AppL10n l10n) {
    final df = DateFormat('dd.MM.yyyy', l10n.locale.languageCode);
    return Material(
      color: context.palette.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_rounded, color: context.palette.primary, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.workDate,
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      df.format(_date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.palette.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mileageField(AppL10n l10n, {bool assignKey = false}) {
    return TextField(
      key: assignKey ? _kmFieldKey : null,
      controller: _kmCtrl,
      focusNode: _kmFocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.mileageKmRequired,
        hintText: l10n.digitsOnlyHint,
        filled: true,
        fillColor: context.palette.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _placeField(AppL10n l10n) {
    return TextField(
      controller: _placeCtrl,
      focusNode: _placeFocus,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.placeOptional,
        hintText: l10n.serviceNameHint,
        filled: true,
        fillColor: context.palette.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _detailsBlock(AppL10n l10n, {required bool compact, bool keyOnKm = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dateRow(l10n),
        SizedBox(height: compact ? 10 : 14),
        _mileageField(l10n, assignKey: keyOnKm),
        SizedBox(height: compact ? 10 : 14),
        _placeField(l10n),
      ],
    );
  }

  List<Widget> _buildTypeSectionList(AppL10n l10n, Set<MaintenanceType> filtered) {
    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            l10n.nothingFound,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.palette.textSecondary.withValues(alpha: 0.9)),
          ),
        ),
      ];
    }
    final children = <Widget>[];
    for (final sec in maintenanceTypeSections(l10n)) {
      final items = sec.types.where(filtered.contains).toList();
      if (items.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(
            sec.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.palette.textSecondary.withValues(alpha: 0.85),
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
      for (final t in items) {
        final sel = _selectedTypes.contains(t);
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: sel ? context.palette.primary.withValues(alpha: 0.14) : context.palette.cardBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedTypes.remove(t);
                  } else {
                    _selectedTypes.add(t);
                  }
                }),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        sel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: sel ? context.palette.primary : context.palette.textTertiary,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.localizedTitle(l10n),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: sel ? context.palette.textPrimary : context.palette.textPrimary.withValues(alpha: 0.92),
                              ),
                            ),
                            Text(
                              t.localizedSubtitle(l10n),
                              style: TextStyle(fontSize: 11, color: context.palette.textSecondary, height: 1.25),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(maintenanceRemindersProvider);
    final l10n = L10nScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _filteredTypes(l10n);
    final maxH = MediaQuery.sizeOf(context).height;
    final collapse = _headerCollapse01;
    final headerH = _kDetailsBlockHeight * (1 - collapse);
    final headerInteractive = headerH >= 48;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: maxH * 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: context.palette.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.maintRecordSheetTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.palette.textPrimary.withValues(alpha: 0.96),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.maintRecordSheetHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.cars.length > 1) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          l10n.vehicle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.cars.map((c) {
                            final sel = c.id == _car.id;
                            return ChoiceChip(
                              label: Text(
                                c.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? context.palette.onAccent : context.palette.textPrimary,
                                ),
                              ),
                              selected: sel,
                              selectedColor: context.palette.primary,
                              backgroundColor: context.palette.cardBg,
                              side: BorderSide(color: sel ? context.palette.primary : context.palette.border),
                              onSelected: (_) {
                                setState(() {
                                  _car = c;
                                  _kmCtrl.text = '${c.mileage}';
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    ClipRect(
                      child: SizedBox(
                        height: headerH,
                        child: Opacity(
                          opacity: collapse >= 0.995
                              ? 0
                              : (1 - collapse * 0.45).clamp(0.5, 1.0),
                          child: IgnorePointer(
                            ignoring: !headerInteractive,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                              child: _detailsBlock(l10n, compact: false, keyOnKm: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(20, 12, 20, pad.bottom + kb + 24),
                        children: [
                          Text(
                            l10n.jobTypeRequired,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _searchCtrl,
                            style: TextStyle(fontSize: 15, color: context.palette.textPrimary),
                            decoration: InputDecoration(
                              hintText: l10n.searchByName,
                              hintStyle: TextStyle(color: context.palette.textPlaceholder, fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded, color: context.palette.textSecondary, size: 22),
                              filled: true,
                              fillColor: context.palette.cardBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.palette.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.palette.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.palette.primary, width: 1.5),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          ..._buildTypeSectionList(l10n, filtered),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: FilledButton(
                    onPressed: () => _save(l10n),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: context.palette.primary,
                      foregroundColor: context.palette.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(l10n.saveRecord, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
