import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/schedule/slot_grid_utils.dart';

/// Модальное окно выбора услуг из каталога (множественный выбор).
class _ServicePickerSheet extends StatefulWidget {
  final List<ServiceCategory> categories;
  final SettingsRepository repo;
  final Set<String> initialAlreadyNames;
  final void Function(ServiceItem) onAdd;
  final VoidCallback onDone;
  /// На desktop — светлая тема для читаемости.
  final bool useLightTheme;

  const _ServicePickerSheet({
    required this.categories,
    required this.repo,
    required this.initialAlreadyNames,
    required this.onAdd,
    required this.onDone,
    this.useLightTheme = false,
  });

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  late Set<String> _addedNames;

  @override
  void initState() {
    super.initState();
    _addedNames = Set.from(widget.initialAlreadyNames);
  }

  bool _isAdded(ServiceItem s) => _addedNames.contains(s.name);

  void _add(ServiceItem s) {
    widget.onAdd(s);
    setState(() => _addedNames.add(s.name));
  }

  @override
  Widget build(BuildContext context) {
    final useLight = widget.useLightTheme;
    final colorPrimary = useLight ? AppColorsDesktop.primary : AppColors.primary;
    final colorTextPrimary = useLight ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final colorTextSecondary = useLight ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Выберите услуги из каталога',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorTextPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onDone,
                  child: Text('Готово', style: TextStyle(color: colorPrimary)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: useLight ? AppColorsDesktop.border : null),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final cat in widget.categories) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorTextSecondary,
                      ),
                    ),
                  ),
                  ...widget.repo.servicesForCategory(cat.id).map((s) {
                    final added = _isAdded(s);
                    return ListTile(
                      title: Text(
                        s.name,
                        style: TextStyle(color: colorTextPrimary),
                      ),
                      subtitle: Text(
                        '${formatMoney(s.priceKopecks)} • ${s.durationMinutes} мин',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextSecondary,
                        ),
                      ),
                      trailing: added
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(Icons.check_circle, color: colorPrimary, size: 22),
                            )
                          : IconButton(
                              icon: Icon(Icons.add_circle_outline, color: colorPrimary),
                              onPressed: () => _add(s),
                            ),
                      onTap: () {
                        if (!added) _add(s);
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Одна строка в форме: позиция + редактируемые цена и время (мин).
class _ApprovalRow {
  final ApprovalItem item;
  final TextEditingController priceController;
  final TextEditingController minutesController;

  _ApprovalRow({
    required this.item,
    required this.priceController,
    required this.minutesController,
  });
}

/// Один вариант авто клиента для выбора при создании нового заказа.
class _VehicleOption {
  const _VehicleOption({required this.carId, required this.label});
  final String carId;
  final String label;
}

class ApprovalRequestScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String orderId;
  /// Встроен в оверлей диалога: без полного Scaffold, с кнопкой закрытия.
  final bool embeddedInDialog;
  /// При закрытии (успех или отмена) вызывается вместо Navigator.pop.
  final VoidCallback? onClose;
  /// Заказы чата для выбора авто при создании нового заказа: если у клиента >1 авто — показываем выбор.
  final List<Order>? chatOrdersForCarSelection;

  const ApprovalRequestScreen({
    super.key,
    required this.chatId,
    required this.orderId,
    this.embeddedInDialog = false,
    this.onClose,
    this.chatOrdersForCarSelection,
  });

  @override
  ConsumerState<ApprovalRequestScreen> createState() => _ApprovalRequestScreenState();
}

class _ApprovalRequestScreenState extends ConsumerState<ApprovalRequestScreen> {
  final List<_ApprovalRow> _rows = [];
  final _manualNameController = TextEditingController();
  final _manualPriceController = TextEditingController();
  final _manualMinutesController = TextEditingController(text: '60');
  /// Предложенное время записи (опционально).
  DateTime? _proposedDateTime;
  /// Дата, по которой загружены слоты.
  DateTime _slotsDate = DateTime.now().add(const Duration(days: 1));
  AvailableSlotsResult? _slotsResult;
  bool _slotsLoading = false;
  /// Идёт отправка запроса согласования — блокируем кнопку от двойного нажатия.
  bool _sending = false;
  /// Выбранное авто при создании нового заказа (если у клиента несколько).
  String? _selectedCarId;

  static List<_VehicleOption> _uniqueVehiclesFromOrders(List<Order> orders) {
    final seen = <String>{};
    final list = <_VehicleOption>[];
    for (final o in orders) {
      final id = o.carId.isNotEmpty ? o.carId : o.carInfo;
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      list.add(_VehicleOption(carId: o.carId.isNotEmpty ? o.carId : id, label: o.carInfo));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _selectedCarId = null;
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final orgId = ref.read(authProvider).user?.organizationId;
    if (orgId == null) {
      setState(() {
        _slotsResult = const AvailableSlotsResult();
        _slotsLoading = false;
      });
      return;
    }
    setState(() => _slotsLoading = true);
    final api = ref.read(orderApiServiceProvider);
    final result = await api.getAvailableSlots(orgId, _slotsDate, []);
    if (!mounted) return;
    setState(() {
      _slotsLoading = false;
      _slotsResult = result.dataOrNull ?? const AvailableSlotsResult();
    });
  }

  @override
  void dispose() {
    _manualNameController.dispose();
    _manualPriceController.dispose();
    _manualMinutesController.dispose();
    for (final r in _rows) {
      r.priceController.dispose();
      r.minutesController.dispose();
    }
    super.dispose();
  }

  void _addManualItem() {
    final name = _manualNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название работы'), backgroundColor: AppColors.cardBg),
      );
      return;
    }
    final rub = double.tryParse(_manualPriceController.text.replaceAll(',', '.')) ?? 0;
    final priceKopecks = (rub * 100).round().clamp(0, 99999999);
    final minutes = int.tryParse(_manualMinutesController.text.trim()) ?? 60;
    final estimatedMinutes = minutes.clamp(1, 9999);
    final priceController = TextEditingController(text: (priceKopecks / 100).toStringAsFixed(0));
    final minutesController = TextEditingController(text: estimatedMinutes.toString());
    setState(() {
      _rows.add(_ApprovalRow(
        item: ApprovalItem(
          name: name,
          priceKopecks: priceKopecks,
          estimatedMinutes: estimatedMinutes,
        ),
        priceController: priceController,
        minutesController: minutesController,
      ));
      _manualNameController.clear();
      _manualPriceController.clear();
      _manualMinutesController.text = '60';
    });
  }

  void _addFromService(ServiceItem service) {
    final priceController = TextEditingController(
      text: (service.priceKopecks / 100).toStringAsFixed(0),
    );
    final minutesController = TextEditingController(text: service.durationMinutes.toString());
    setState(() {
      _rows.add(_ApprovalRow(
        item: ApprovalItem(
          name: service.name,
          priceKopecks: service.priceKopecks,
          estimatedMinutes: service.durationMinutes,
        ),
        priceController: priceController,
        minutesController: minutesController,
      ));
    });
  }

  void _removeAt(int index) {
    _rows[index].priceController.dispose();
    _rows[index].minutesController.dispose();
    setState(() => _rows.removeAt(index));
  }

  void _updatePriceAt(int index, int newPriceKopecks) {
    final row = _rows[index];
    setState(() {
      _rows[index] = _ApprovalRow(
        item: ApprovalItem(
          name: row.item.name,
          priceKopecks: newPriceKopecks,
          estimatedMinutes: row.item.estimatedMinutes,
        ),
        priceController: row.priceController,
        minutesController: row.minutesController,
      );
    });
  }

  void _updateMinutesAt(int index, int newMinutes) {
    final row = _rows[index];
    final minutes = newMinutes.clamp(1, 9999);
    if (row.minutesController.text != minutes.toString()) {
      row.minutesController.text = minutes.toString();
    }
    setState(() {
      _rows[index] = _ApprovalRow(
        item: ApprovalItem(
          name: row.item.name,
          priceKopecks: row.item.priceKopecks,
          estimatedMinutes: minutes,
        ),
        priceController: row.priceController,
        minutesController: row.minutesController,
      );
    });
  }

  int _estimatedTotalMinutesForSlots() {
    if (_rows.isEmpty) return 60;
    return _rows.fold<int>(0, (s, r) {
      final m = int.tryParse(r.minutesController.text.trim()) ?? r.item.estimatedMinutes;
      return s + m.clamp(1, 9999);
    });
  }

  List<ApprovalItem> _buildItemsToSend() {
    return _rows.map((r) {
      final rub = double.tryParse(r.priceController.text.replaceAll(',', '.')) ?? 0;
      final kopecks = (rub * 100).round().clamp(0, 99999999);
      final minutes = int.tryParse(r.minutesController.text.trim()) ?? r.item.estimatedMinutes;
      final estimatedMinutes = minutes.clamp(1, 9999);
      return ApprovalItem(
        name: r.item.name,
        priceKopecks: kopecks,
        estimatedMinutes: estimatedMinutes,
      );
    }).toList();
  }

  Future<void> _showServicePicker() async {
    final settingsState = ref.read(settingsRepositoryProvider);
    final categories = List<ServiceCategory>.from(settingsState.categories)
      ..sort((a, b) => a.order.compareTo(b.order));
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final initialAlready = _rows.map((r) => r.item.name).toSet();

    if (!mounted) return;
    final useLight = isDesktopPlatform;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: useLight ? AppColorsDesktop.surface : AppColors.cardBg,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ServicePickerSheet(
        categories: categories,
        repo: repo,
        initialAlreadyNames: initialAlready,
        onAdd: (s) {
          _addFromService(s);
        },
        onDone: () => Navigator.pop(ctx),
        useLightTheme: useLight,
      ),
    );
  }

  Future<void> _pickProposedTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _proposedDateTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _proposedDateTime != null
          ? TimeOfDay(hour: _proposedDateTime!.hour, minute: _proposedDateTime!.minute)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() {
      _proposedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send() async {
    final items = _buildItemsToSend();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одну позицию'),
          backgroundColor: AppColors.cardBg,
        ),
      );
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    final chatRepo = ref.read(chatRepositoryProvider.notifier);
    final orderRepo = ref.read(orderRepositoryProvider.notifier);
    final effectiveOrderId = await chatRepo.sendApprovalRequest(
      widget.chatId,
      widget.orderId,
      carId: widget.orderId.isEmpty ? _selectedCarId : null,
      items: items,
      proposedDateTime: _proposedDateTime,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
      await orderRepo.refreshOrder(effectiveOrderId);
      await ref.read(orderRepositoryProvider.notifier).loadFromApi();
      await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(widget.chatId);
      if (widget.orderId.isEmpty) ref.read(chatRepositoryProvider.notifier).loadFromApi();
      if (!mounted) return;
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запрос согласования отправлен клиенту'),
          backgroundColor: AppColors.cardBg,
        ),
      );
    } else {
      if (widget.orderId.isNotEmpty) await orderRepo.refreshOrder(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить. Проверьте сеть.'),
          backgroundColor: AppColors.cardBg,
        ),
      );
    }
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform;
    final total = _rows.isEmpty
        ? 0
        : _buildItemsToSend().fold<int>(0, (s, i) => s + i.priceKopecks);

    final vehicles = widget.orderId.isEmpty && widget.chatOrdersForCarSelection != null
        ? _uniqueVehiclesFromOrders(widget.chatOrdersForCarSelection!)
        : <_VehicleOption>[];
    final showCarPicker = widget.orderId.isEmpty;

    final colorPrimary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    final colorTextPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final colorTextSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final colorTextTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final colorSurface = isDesktop ? AppColorsDesktop.surface : AppColors.surface;
    final colorNestedBg = isDesktop ? AppColorsDesktop.nestedBg : AppColors.nestedBg;
    final colorCardBg = isDesktop ? AppColorsDesktop.cardBg : AppColors.cardBg;
    final colorSuccess = isDesktop ? AppColorsDesktop.success : AppColors.success;
    final colorBorder = isDesktop ? AppColorsDesktop.border : AppColors.border;
    final colorBackground = isDesktop ? AppColorsDesktop.background : AppColors.background;

    final body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (showCarPicker) ...[
            Text(
              'Для какой машины создаётся заказ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _selectedCarId,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: colorNestedBg,
              ),
              dropdownColor: colorCardBg,
              style: TextStyle(color: colorTextPrimary, fontSize: 14),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('Для всех машин', style: TextStyle(color: colorTextPrimary))),
                ...vehicles.map((v) => DropdownMenuItem<String?>(value: v.carId, child: Text(v.label, overflow: TextOverflow.ellipsis, style: TextStyle(color: colorTextPrimary)))),
              ],
              onChanged: (v) => setState(() => _selectedCarId = v),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Добавьте работы из каталога или вручную. Цену и время можно изменить.',
            style: TextStyle(
              fontSize: 14,
              color: colorTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showServicePicker,
            icon: Icon(Icons.add_rounded, size: 20, color: colorPrimary),
            label: Text('Добавить услуги из каталога', style: TextStyle(color: colorPrimary)),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorPrimary,
              side: BorderSide(color: colorPrimary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Или добавьте работу вручную (если нет в каталоге)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorTextSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _manualNameController,
                  decoration: InputDecoration(
                    labelText: 'Название работы',
                    hintText: 'Например: Замена патрубка',
                    isDense: true,
                    labelStyle: TextStyle(color: colorTextSecondary),
                    hintStyle: TextStyle(color: colorTextTertiary),
                  ),
                  style: TextStyle(color: colorTextPrimary),
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _manualPriceController,
                  decoration: InputDecoration(labelText: '₽', isDense: true, labelStyle: TextStyle(color: colorTextSecondary)),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colorTextPrimary),
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _manualMinutesController,
                  decoration: InputDecoration(labelText: 'мин', isDense: true, labelStyle: TextStyle(color: colorTextSecondary)),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colorTextPrimary),
                  onSubmitted: (_) => _addManualItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addManualItem,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(backgroundColor: colorPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Добавьте позиции из каталога или вручную',
                  style: TextStyle(color: colorTextTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            ...List.generate(_rows.length, (i) {
              final row = _rows[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: colorSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 80, maxWidth: 160),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                row.item.name,
                                style: TextStyle(
                                  color: colorTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextFormField(
                              controller: row.priceController,
                              decoration: InputDecoration(
                                labelText: '₽',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                labelStyle: TextStyle(color: colorTextSecondary),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: colorTextPrimary),
                              onChanged: (v) {
                                final rub = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                                _updatePriceAt(i, (rub * 100).round().clamp(0, 99999999));
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 48,
                            child: TextFormField(
                              controller: row.minutesController,
                              decoration: InputDecoration(
                                labelText: 'мин',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                labelStyle: TextStyle(color: colorTextSecondary),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: colorTextPrimary),
                              onChanged: (v) {
                                final minutes = int.tryParse(v.trim()) ?? row.item.estimatedMinutes;
                                _updateMinutesAt(i, minutes.clamp(1, 9999));
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20, color: colorTextSecondary),
                            onPressed: () => _removeAt(i),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Итого: ${formatMoney(total)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Статус в карточке: Ожидает согласования',
              style: TextStyle(
                fontSize: 12,
                color: colorTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Предложить время записи',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Выберите свободный слот по сетке или укажите время вручную. Клиент увидит предложенное время в чате.',
              style: TextStyle(fontSize: 12, color: colorTextSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _slotsDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null && date != _slotsDate && mounted) {
                  setState(() => _slotsDate = date);
                  _loadSlots();
                }
              },
              icon: Icon(Icons.calendar_today_rounded, size: 18, color: colorPrimary),
              label: Text(formatDate(_slotsDate), style: TextStyle(color: colorTextPrimary)),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorTextPrimary,
                side: BorderSide(color: colorBorder),
              ),
            ),
            const SizedBox(height: 8),
            if (_slotsLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorPrimary)),
                    const SizedBox(width: 8),
                    Text('Загрузка слотов...', style: TextStyle(fontSize: 13, color: colorTextSecondary)),
                  ],
                ),
              )
            else
              Builder(
                builder: (ctx) {
                  final slotsSet = ref.watch(settingsRepositoryProvider).slotsSettings;
                  final dims = slotGridDimensionsFromApiOrLocal(_slotsResult, slotsSet);
                  final timeSlots = timeSlotLabelsForGrid(dims);
                  final available = _slotsResult?.startTimes ?? [];
                  final jobDur = _estimatedTotalMinutesForSlots().clamp(15, 24 * 60);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(timeSlots.length, (i) {
                      final slot = timeSlots[i];
                  final isAvailable = available.contains(slot);
                  final isSelectedStart = _proposedDateTime != null &&
                      slotIsJobStartLabel(slot, _proposedDateTime, _slotsDate);
                  final isContinuation = _proposedDateTime != null &&
                      isAvailable &&
                      slotIsJobContinuationLabel(slot, _proposedDateTime, _slotsDate, jobDur);
                  final Color slotBg = isAvailable
                      ? (isSelectedStart ? colorPrimary : colorSuccess.withValues(alpha: 0.2))
                      : colorNestedBg;
                  final Color slotBorder = isAvailable
                      ? (isSelectedStart
                          ? colorPrimary
                          : isContinuation
                              ? const Color(0xFFE65100)
                              : colorSuccess)
                      : colorBorder;
                  final Color slotText = isAvailable
                      ? (isSelectedStart
                          ? (isDesktop ? AppColorsDesktop.textPrimary : const Color(0xFF0D0D0D))
                          : colorSuccess)
                      : colorTextTertiary;
                  return GestureDetector(
                    onTap: isAvailable
                        ? () => setState(() {
                              final p = slot.split(':');
                              _proposedDateTime = DateTime(
                                _slotsDate.year,
                                _slotsDate.month,
                                _slotsDate.day,
                                int.parse(p[0]),
                                int.parse(p.length > 1 ? p[1] : '0'),
                              );
                            })
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: slotBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: slotBorder, width: isContinuation ? 2 : 1),
                      ),
                      child: Text(
                        slot,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: slotText),
                      ),
                    ),
                  );
                    }),
                  );
                },
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickProposedTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(
                    _proposedDateTime != null
                        ? '${formatDate(_proposedDateTime!)} в ${formatTime(_proposedDateTime!)}'
                        : 'Указать вручную',
                    style: TextStyle(color: colorTextPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorPrimary,
                    side: BorderSide(color: colorPrimary),
                  ),
                ),
                if (_proposedDateTime != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.clear_rounded, color: colorTextSecondary),
                    onPressed: () => setState(() => _proposedDateTime = null),
                    tooltip: 'Убрать время',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Отправить клиенту'),
            ),
          ],
        ],
      );

    if (widget.embeddedInDialog) {
      final isDesktop = isDesktopPlatform;
      return Container(
        color: isDesktop ? AppColorsDesktop.surface : AppColors.cardBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
              decoration: BoxDecoration(
                color: isDesktop
                    ? AppColorsDesktop.primary.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(
                    color: isDesktop ? AppColorsDesktop.border : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.request_quote_rounded,
                    size: 22,
                    color: isDesktop ? AppColorsDesktop.primary : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Запрос согласования',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _handleClose,
                    style: IconButton.styleFrom(
                      foregroundColor: isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Запрос согласования'),
      ),
      body: body,
    );
  }
}
