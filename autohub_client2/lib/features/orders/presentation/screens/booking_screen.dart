import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/availability/availability_helper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/widgets/common_widgets.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final STO sto;
  final List<String> selectedServiceIds;
  const BookingScreen({super.key, required this.sto, this.selectedServiceIds = const []});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> with WidgetsBindingObserver {
  late Set<String> _selectedServices;
  String? _selectedCarId;
  late DateTime _selectedDate;
  int _selectedTimeSlot = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  Timer? _todayRefreshTimer;

  /// Сетка как у записи через карточку точки: шаг 1 ч, 08:00–18:00 (до конца дня без ячейки 19:00).
  late final List<String> _timeSlots = buildDaySlotLabels(
    slotDurationMinutes: 60,
    workStartMinutes: 8 * 60,
    workEndMinutes: 19 * 60,
  );

  bool get _selectedDateIsToday =>
      Formatters.isSameCalendarDay(_selectedDate, DateTime.now());

  void _startTodayRefreshTimer() {
    _todayRefreshTimer?.cancel();
    if (!_selectedDateIsToday) return;
    _todayRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(_ensureSelectedSlotStillValid);
    });
  }

  /// Подобрать индекс первого слота, который ещё не в прошлом (без setState).
  void _pickFirstNonPastTimeSlot() {
    for (var i = 0; i < _timeSlots.length; i++) {
      if (!Formatters.isBookingSlotStartInPastOrNow(_selectedDate, _timeSlots[i])) {
        _selectedTimeSlot = i;
        return;
      }
    }
  }

  void _ensureSelectedSlotStillValid() {
    if (_selectedTimeSlot < 0 || _selectedTimeSlot >= _timeSlots.length) return;
    final slot = _timeSlots[_selectedTimeSlot];
    if (!Formatters.isBookingSlotStartInPastOrNow(_selectedDate, slot)) return;
    _pickFirstNonPastTimeSlot();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final n = DateTime.now();
    _selectedDate = DateTime(n.year, n.month, n.day);
    _selectedServices = widget.selectedServiceIds.toSet();
    _pickFirstNonPastTimeSlot();
    _startTodayRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _centerCarChip(String carId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scrollWidgetToViewportCenter(GlobalObjectKey(carId).currentContext);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cars = ref.read(carsProvider).valueOrNull ?? [];
    if (_selectedCarId == null && cars.isNotEmpty) {
      final savedId = ref.read(selectedCarIdProvider);
      final match = savedId != null && cars.any((c) => c.id == savedId);
      _selectedCarId = match ? savedId : cars.first.id;
      _centerCarChip(_selectedCarId!);
    }
  }

  @override
  void dispose() {
    _todayRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    super.dispose();
  }

  int _totalPrice(List<STOService> services) => services
      .where((s) => _selectedServices.contains(s.id))
      .fold(0, (sum, s) => sum + s.priceKopecks);

  int _totalDuration(List<STOService> services) => services
      .where((s) => _selectedServices.contains(s.id))
      .fold(0, (sum, s) => sum + s.durationMinutes);

  bool get _canSubmit {
    if (_selectedCarId == null || _selectedServices.isEmpty || _isSubmitting) return false;
    if (_selectedTimeSlot < 0 || _selectedTimeSlot >= _timeSlots.length) return false;
    return !Formatters.isBookingSlotStartInPastOrNow(_selectedDate, _timeSlots[_selectedTimeSlot]);
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('Запись на сервис', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
        )),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          // Карточка выбранного сервиса
          _SectionLabel('Автосервис'),
          _buildSTOCard(),
          SizedBox(height: 20),

          // Выбор авто
          _SectionLabel('Автомобиль'),
          _buildCarSelector(),
          SizedBox(height: 20),

          // Услуги
          _SectionLabel('Выбранные услуги'),
          _buildServicesSelector(services),
          SizedBox(height: 20),

          // Дата
          _SectionLabel('Дата'),
          _buildDateSelector(),
          SizedBox(height: 20),

          // Время
          _SectionLabel('Время'),
          _buildTimeSelector(),
          SizedBox(height: 20),

          // Комментарий
          _SectionLabel('Комментарий (необязательно)'),
          Container(
            decoration: BoxDecoration(
              color: context.palette.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Опишите проблему или пожелания...',
                hintStyle: TextStyle(color: context.palette.textPlaceholder, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, services),
    );
  }

  Widget _buildSTOCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: context.palette.nestedBg, borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(widget.sto.name[0], style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: context.palette.primary,
              )),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.sto.name, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                )),
                Text(widget.sto.address, style: TextStyle(
                  fontSize: 14, color: context.palette.textSecondary,
                )),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 14, color: context.palette.primary),
              SizedBox(width: 2),
              Text(Formatters.rating(widget.sto.rating), style: TextStyle(
                fontSize: 14, color: context.palette.textPrimary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarSelector() {
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cars.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (_, i) {
          final car = cars[i];
          final isSelected = _selectedCarId == car.id;
          return GestureDetector(
            key: GlobalObjectKey(car.id),
            onTap: () {
              setState(() => _selectedCarId = car.id);
              _centerCarChip(car.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? context.palette.primary.withValues(alpha: 0.1) : context.palette.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? context.palette.primary : context.palette.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_car_rounded, size: 20,
                        color: isSelected ? context.palette.primary : context.palette.textTertiary),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, size: 18, color: context.palette.primary),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('${car.brand} ${car.model}', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isSelected ? context.palette.primary : context.palette.textPrimary,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(car.plateNumber ?? '${car.year}', style: TextStyle(
                    fontSize: 12, color: context.palette.textSecondary,
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesSelector(List<STOService> services) {
    return Column(
      children: services.map((service) {
        final isSelected = _selectedServices.contains(service.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) _selectedServices.remove(service.id);
              else _selectedServices.add(service.id);
            });
            HapticFeedback.selectionClick();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? context.palette.primary.withValues(alpha: 0.08) : context.palette.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? context.palette.primary.withValues(alpha: 0.5) : context.palette.border,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? context.palette.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected ? context.palette.primary : context.palette.textTertiary,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 13, color: context.palette.onAccent)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: TextStyle(
                      fontSize: 14, color: context.palette.textPrimary,
                    )),
                    SizedBox(height: 2),
                    Text('⏱ ${service.durationLabel}', style: TextStyle(
                      fontSize: 12, color: context.palette.textSecondary,
                    )),
                  ],
                )),
                Text(Formatters.money(service.priceKopecks), style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final days = List.generate(14, (i) => base.add(Duration(days: i)));

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = days[i];
          final isSelected = Formatters.isSameCalendarDay(_selectedDate, day);
          final weekday = Formatters.weekdayShort(day);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = day;
                _pickFirstNonPastTimeSlot();
              });
              _startTodayRefreshTimer();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? context.palette.primary : context.palette.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? context.palette.primary : context.palette.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(weekday, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: isSelected ? context.palette.onAccent : context.palette.textSecondary,
                  )),
                  SizedBox(height: 4),
                  Text('${day.day}', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: isSelected ? context.palette.onAccent : context.palette.textPrimary,
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: List.generate(_timeSlots.length, (i) {
        final slot = _timeSlots[i];
        final isSelected = _selectedTimeSlot == i;
        final isPastToday = Formatters.isBookingSlotStartInPastOrNow(_selectedDate, slot);
        final canTap = !isPastToday;
        return GestureDetector(
          onTap: canTap ? () => setState(() => _selectedTimeSlot = i) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isPastToday
                  ? context.palette.textMuted.withValues(alpha: 0.15)
                  : isSelected
                      ? context.palette.primary
                      : context.palette.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPastToday
                    ? context.palette.border.withValues(alpha: 0.45)
                    : isSelected
                        ? context.palette.primary
                        : context.palette.border,
              ),
            ),
            child: Text(slot, style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPastToday
                  ? context.palette.textMuted
                  : isSelected
                      ? context.palette.onAccent
                      : context.palette.textPrimary,
            )),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar(BuildContext context, List<STOService> services) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итого:', style: TextStyle(
                fontSize: 14, color: context.palette.textSecondary,
              )),
              Text(Formatters.money(_totalPrice(services)), style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: context.palette.textPrimary, fontFamily: 'monospace',
              )),
            ],
          ),
          if (_selectedServices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Builder(
                builder: (_) {
                  final durMin = _totalDuration(services);
                  final slot = _timeSlots[_selectedTimeSlot];
                  final start = Formatters.dateAtTimeSlot(_selectedDate, slot);
                  final end = start?.add(Duration(minutes: durMin));
                  final range = (start != null && end != null)
                      ? Formatters.bookingRangeLabel(start, end)
                      : '${Formatters.dateShortRu(_selectedDate)}, $slot';
                  final dur = Formatters.durationMinutes(durMin);
                  return Text(
                    '$range · ≈ $dur',
                    maxLines: 4,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                      height: 1.35,
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: 12),
          GoldButton(
            text: _isSubmitting ? '' : 'Подтвердить запись',
            isLoading: _isSubmitting,
            onPressed: _canSubmit ? () => _submit(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: context.palette.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 36, color: context.palette.success),
            ),
            SizedBox(height: 20),
            Text('Запись создана!', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
            )),
            SizedBox(height: 8),
            Text(
              () {
                final services = ref.read(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
                final dur = _totalDuration(services);
                final slot = _timeSlots[_selectedTimeSlot];
                final start = Formatters.dateAtTimeSlot(_selectedDate, slot);
                final end = start?.add(Duration(minutes: dur));
                final range = (start != null && end != null)
                    ? Formatters.bookingRangeLabel(start, end)
                    : '${Formatters.dateFullRu(_selectedDate)}, $slot';
                return '${widget.sto.name}\n$range\n≈ ${Formatters.durationMinutes(dur)}';
              }(),
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            GoldButton(
              text: 'Отлично',
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // booking
                Navigator.pop(context); // sto detail
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textSecondary,
      )),
    );
  }
}
