import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/schedule/slot_grid_utils.dart';

/// Экран «Подтвердить или скорректировать» заказ: добавить услуги из каталога,
/// дописать позиции от руки, предложить новое время и отправить клиенту.
/// При [additionalWorksOnly] true открывается с пустым списком — только доп. работы к существующему заказу.
class ConfirmCorrectOrderScreen extends ConsumerStatefulWidget {
  final String orderId;
  /// Обязателен при [additionalWorksOnly] (открытие из чата).
  final String? chatId;
  /// True = доп. работы к заказу: список пустой, отправляется только запрос согласования с новыми позициями.
  final bool additionalWorksOnly;
  /// Встроен в оверлей диалога: без полного Scaffold, с кнопкой закрытия.
  final bool embeddedInDialog;
  /// При закрытии вызывается вместо Navigator.pop.
  final VoidCallback? onClose;

  const ConfirmCorrectOrderScreen({
    super.key,
    required this.orderId,
    this.chatId,
    this.additionalWorksOnly = false,
    this.embeddedInDialog = false,
    this.onClose,
  });

  @override
  ConsumerState<ConfirmCorrectOrderScreen> createState() => _ConfirmCorrectOrderScreenState();
}

/// Строка с редактируемыми ценой и временем.
class _ConfirmRow {
  final OrderItem item;
  final TextEditingController priceController;
  final TextEditingController minutesController;
  _ConfirmRow({required this.item, required this.priceController, required this.minutesController});
}

class _ConfirmCorrectOrderScreenState extends ConsumerState<ConfirmCorrectOrderScreen> {
  /// Текущие услуги заказа (только правка цены/времени, без удаления).
  late List<_ConfirmRow> _existingRows;
  /// Добавленные услуги (можно добавлять, редактировать, удалять).
  late List<_ConfirmRow> _newRows;
  DateTime? _proposedDateTime;
  bool _isSending = false;
  /// Дата, по которой показываем сетку слотов.
  late DateTime _slotsDate;
  AvailableSlotsResult? _slotsResult;
  bool _slotsLoading = false;

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
  void initState() {
    super.initState();
    final order = ref.read(orderByIdProvider(widget.orderId));
    final when = order?.plannedStartTime ?? order?.dateTime;
    // Сервер отдаёт UTC — без toLocal() сетка (локальные «HH:mm») подсвечивает неверную ячейку.
    final localWhen = orderStartWallClock(when);
    _proposedDateTime = localWhen;
    _slotsDate = localWhen ?? DateTime.now().add(const Duration(days: 1));
    _slotsDate = DateTime(_slotsDate.year, _slotsDate.month, _slotsDate.day);
    _loadSlots();
    if (widget.additionalWorksOnly) {
      _existingRows = [];
      _newRows = [];
      return;
    }
    if (order != null && order.items.isNotEmpty) {
      _existingRows = order.items.map((i) => _ConfirmRow(
        item: OrderItem(
          id: i.id,
          name: i.name,
          priceKopecks: i.priceKopecks,
          estimatedMinutes: i.estimatedMinutes,
          isCompleted: false,
          isAdditional: false,
          serviceId: i.serviceId,
          catalogItemId: i.catalogItemId,
        ),
        priceController: TextEditingController(text: (i.priceKopecks ?? 0) ~/ 100 == 0 ? '' : '${(i.priceKopecks! ~/ 100)}'),
        minutesController: TextEditingController(text: '${i.estimatedMinutes}'),
      )).toList();
      _newRows = [];
    } else {
      _existingRows = [];
      _newRows = [];
    }
  }

  @override
  void dispose() {
    for (final r in _existingRows) {
      r.priceController.dispose();
      r.minutesController.dispose();
    }
    for (final r in _newRows) {
      r.priceController.dispose();
      r.minutesController.dispose();
    }
    super.dispose();
  }

  void _removeNewItem(int index) {
    _newRows[index].priceController.dispose();
    _newRows[index].minutesController.dispose();
    setState(() => _newRows.removeAt(index));
  }

  void _addFromCatalog(ServiceItem s) {
    setState(() {
      _newRows.add(_ConfirmRow(
        item: OrderItem(
          id: s.id,
          name: s.name,
          priceKopecks: s.priceKopecks,
          estimatedMinutes: s.durationMinutes,
          isCompleted: false,
          isAdditional: false,
          serviceId: s.id,
          catalogItemId: s.catalogItemId,
        ),
        priceController: TextEditingController(text: '${s.priceKopecks ~/ 100}'),
        minutesController: TextEditingController(text: '${s.durationMinutes}'),
      ));
    });
  }

  void _addCustom(String name, int minutes, int priceKopecks) {
    setState(() {
      _newRows.add(_ConfirmRow(
        item: OrderItem(id: 'custom_${DateTime.now().millisecondsSinceEpoch}', name: name, priceKopecks: priceKopecks, estimatedMinutes: minutes, isCompleted: false, isAdditional: false),
        priceController: TextEditingController(text: '${priceKopecks ~/ 100}'),
        minutesController: TextEditingController(text: '$minutes'),
      ));
    });
  }

  List<OrderItem> _itemsFromRows(List<_ConfirmRow> rows) => rows.map((r) {
    final rub = double.tryParse(r.priceController.text.replaceAll(',', '.')) ?? 0;
    final kopecks = (rub * 100).round().clamp(0, 99999999);
    final mins = int.tryParse(r.minutesController.text.trim()) ?? r.item.estimatedMinutes;
    return r.item.copyWith(priceKopecks: kopecks, estimatedMinutes: mins.clamp(0, 9999));
  }).toList();

  /// Только позиции, у которых изменились цена или время относительно исходного заказа.
  List<EditedApprovalItem> get _editedItems {
    final original = _existingRows.map((r) => r.item).toList();
    final current = _itemsFromRows(_existingRows);
    return current.where((i) {
      final match = original.where((o) => o.id == i.id).toList();
      if (match.isEmpty) return true;
      final orig = match.first;
      return (orig.priceKopecks ?? 0) != (i.priceKopecks ?? 0) || orig.estimatedMinutes != i.estimatedMinutes;
    }).map((i) => EditedApprovalItem(
      id: i.id,
      name: i.name,
      priceKopecks: i.priceKopecks ?? 0,
      estimatedMinutes: i.estimatedMinutes,
    )).toList();
  }

  List<ApprovalItem> get _newApprovalItems {
    final base = DateTime.now().millisecondsSinceEpoch;
    return _newRows.asMap().entries.map((e) {
      final i = _itemsFromRows([e.value]).first;
      return ApprovalItem(
        name: i.name,
        priceKopecks: i.priceKopecks ?? 0,
        estimatedMinutes: i.estimatedMinutes,
        id: 'new_${base}_${e.key}',
      );
    }).toList();
  }

  Future<void> _pickProposedDateTime() async {
    final order = ref.read(orderByIdProvider(widget.orderId));
    final initial = _proposedDateTime ??
        orderStartWallClock(order?.plannedStartTime ?? order?.dateTime) ??
        DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() => _proposedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _sendToClient() async {
    final hasExisting = _existingRows.isNotEmpty;
    final hasNew = _newRows.isNotEmpty;
    if (!hasExisting && !hasNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет изменений для согласования. Добавьте или скорректируйте позиции.'), backgroundColor: AppColors.cardBg),
      );
      return;
    }
    final orderApi = ref.read(orderApiServiceProvider);
    final chatRes = await orderApi.getChatForOrder(widget.orderId);
    final resolvedChatId = chatRes.dataOrNull;
    if (resolvedChatId == null || resolvedChatId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatRes.errorOrNull?.message ?? 'Не удалось получить chatId для заказа'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (widget.chatId != null && widget.chatId!.isNotEmpty && widget.chatId != resolvedChatId) {
      debugPrint('ConfirmCorrectOrder: widget.chatId != resolvedChatId (legacy/duplicate chat): ${widget.chatId} vs $resolvedChatId');
    }
    final chatId = resolvedChatId;
    setState(() => _isSending = true);
    final orderRepo = ref.read(orderRepositoryProvider.notifier);
    final chatRepo = ref.read(chatRepositoryProvider.notifier);

    final order = ref.read(orderByIdProvider(widget.orderId));
    final itemsForTotal = _itemsFromRows(_existingRows) + _itemsFromRows(_newRows);
    final totalK = itemsForTotal.fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final totalMins = itemsForTotal.fold<int>(0, (s, i) => s + i.estimatedMinutes);
    final totalsBeforePrice = order?.items.fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0)) ?? 0;
    final totalsBeforeMins = order?.items.fold<int>(0, (s, i) => s + i.estimatedMinutes) ?? 0;
    final originalItems = order != null
        ? order.items.map((i) => ApprovalItem(name: i.name, priceKopecks: i.priceKopecks ?? 0, estimatedMinutes: i.estimatedMinutes, id: i.id)).toList()
        : <ApprovalItem>[];

    if (widget.additionalWorksOnly) {
      if (!hasNew) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавьте хотя бы одну позицию'), backgroundColor: AppColors.cardBg),
        );
        return;
      }
      final newOnlyPrice = _newApprovalItems.fold<int>(0, (s, i) => s + i.priceKopecks);
      final newOnlyMins = _newApprovalItems.fold<int>(0, (s, i) => s + i.estimatedMinutes);
      final orderIdResult = await chatRepo.sendApprovalRequest(
        chatId,
        widget.orderId,
        editedItems: [],
        newItems: _newApprovalItems,
        originalItems: originalItems.isNotEmpty ? originalItems : null,
        totalsBeforePriceKopecks: totalsBeforePrice > 0 ? totalsBeforePrice : null,
        totalsBeforeMinutes: totalsBeforeMins > 0 ? totalsBeforeMins : null,
        totalsAfterPriceKopecks: totalsBeforePrice + newOnlyPrice,
        totalsAfterMinutes: totalsBeforeMins + newOnlyMins,
        proposedDateTime: _proposedDateTime,
        isInitialConfirm: false,
      );
      if (!mounted) return;
      setState(() => _isSending = false);
      if (orderIdResult != null) {
        await ref.read(orderRepositoryProvider.notifier).refreshOrder(widget.orderId);
        await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(chatId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Доп. работы отправлены клиенту на согласование'), backgroundColor: AppColors.cardBg),
        );
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить. Проверьте сеть.'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    // Полная корректировка: отправка согласования с полной сводкой (original_items, totals_before/after) для карточки и перерасчёта времени.
    final orderIdResult = await chatRepo.sendApprovalRequest(
      chatId,
      widget.orderId,
      editedItems: hasExisting ? _editedItems : null,
      newItems: hasNew ? _newApprovalItems : null,
      originalItems: originalItems.isNotEmpty ? originalItems : null,
      totalsBeforePriceKopecks: totalsBeforePrice > 0 ? totalsBeforePrice : null,
      totalsBeforeMinutes: totalsBeforeMins > 0 ? totalsBeforeMins : null,
      totalsAfterPriceKopecks: totalK,
      totalsAfterMinutes: totalMins,
      proposedDateTime: _proposedDateTime,
      isInitialConfirm: false,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (orderIdResult != null) {
      await ref.read(orderRepositoryProvider.notifier).refreshOrder(widget.orderId);
      await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Перечень работ и время отправлены клиенту'), backgroundColor: AppColors.cardBg),
      );
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить. Проверьте сеть.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));
    final settings = ref.watch(settingsRepositoryProvider);
    final allServices = settings.services;
    final itemsForTotal = _itemsFromRows(_existingRows) + _itemsFromRows(_newRows);
    final totalK = itemsForTotal.fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final totalMins = itemsForTotal.fold<int>(0, (s, i) => s + i.estimatedMinutes);
    final isEmbedded = widget.embeddedInDialog;
    final useDesktopColors = isEmbedded && isDesktopPlatform;
    final tPrimary = useDesktopColors ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final tSecondary = useDesktopColors ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final accent = useDesktopColors ? AppColorsDesktop.primary : AppColors.primary;
    final nestBg = useDesktopColors ? AppColorsDesktop.nestedBg : AppColors.nestedBg;
    final borderColor = useDesktopColors ? AppColorsDesktop.border : AppColors.border;

    if (order == null) {
      if (widget.embeddedInDialog) {
        return Container(
          color: useDesktopColors ? AppColorsDesktop.surface : AppColors.cardBg,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onClose != null)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      foregroundColor: useDesktopColors ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),
              Text(
                'Заказ не найден',
                style: TextStyle(color: useDesktopColors ? AppColorsDesktop.textSecondary : AppColors.textSecondary),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Подтвердить заказ')),
        body: const Center(child: Text('Заказ не найден', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final inputDecBase = InputDecoration(
      isDense: true,
      filled: isEmbedded,
      fillColor: useDesktopColors ? AppColorsDesktop.surface : AppColors.nestedBg,
      border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: TextStyle(color: tSecondary, fontSize: 13),
      hintStyle: TextStyle(color: useDesktopColors ? AppColorsDesktop.textPlaceholder : AppColors.textTertiary),
    );

    final bodyContent = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${order.orderNumber} • ${order.carInfo}',
            style: TextStyle(fontSize: 14, color: tSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Исходное время: ${formatDateTimeOrNull(order.dateTime)}',
            style: TextStyle(fontSize: 14, color: tPrimary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          if (_existingRows.isNotEmpty) ...[
            Text(
              'Текущие услуги заказа',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tSecondary),
            ),
            const SizedBox(height: 8),
            ..._existingRows.asMap().entries.map((e) {
              final row = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: nestBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.item.name,
                        style: TextStyle(color: tPrimary, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: TextFormField(
                        controller: row.priceController,
                        decoration: inputDecBase.copyWith(labelText: '₽'),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: tPrimary, fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 48,
                      child: TextFormField(
                        controller: row.minutesController,
                        decoration: inputDecBase.copyWith(labelText: 'мин'),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: tPrimary, fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          Text(
            'Добавленные услуги',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tSecondary),
          ),
          const SizedBox(height: 8),
          ..._newRows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: nestBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.item.name,
                      style: TextStyle(color: tPrimary, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      controller: row.priceController,
                      decoration: inputDecBase.copyWith(labelText: '₽'),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: tPrimary, fontSize: 14),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 48,
                    child: TextFormField(
                      controller: row.minutesController,
                      decoration: inputDecBase.copyWith(labelText: 'мин'),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: tPrimary, fontSize: 14),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: tSecondary),
                    onPressed: () => _removeNewItem(i),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showAddFromCatalog(context, allServices),
                icon: Icon(Icons.list_rounded, size: 18, color: accent),
                label: Text('Из каталога', style: TextStyle(color: tPrimary)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: borderColor),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddCustom(context),
                icon: Icon(Icons.edit_rounded, size: 18, color: accent),
                label: Text('От руки', style: TextStyle(color: tPrimary)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: borderColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Предложенное время',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tSecondary),
          ),
          const SizedBox(height: 8),
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
            icon: Icon(Icons.calendar_today_rounded, size: 18, color: accent),
            label: Text(formatDate(_slotsDate), style: TextStyle(color: tPrimary)),
            style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: borderColor)),
          ),
          const SizedBox(height: 8),
          if (_slotsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
                  const SizedBox(width: 8),
                  Text('Загрузка слотов...', style: TextStyle(fontSize: 13, color: tSecondary)),
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
                final jobDur = totalMins.clamp(15, 24 * 60);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeSlots.map((slot) {
                    final isAvailable = available.contains(slot);
                    final parts = slot.split(':');
                    final hour = int.tryParse(parts[0]) ?? 0;
                    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                    final isSelectedStart = _proposedDateTime != null &&
                        slotIsJobStartLabel(slot, _proposedDateTime, _slotsDate);
                    final isContinuation = _proposedDateTime != null &&
                        isAvailable &&
                        slotIsJobContinuationLabel(slot, _proposedDateTime, _slotsDate, jobDur);
                    final baseAvailBg =
                        (useDesktopColors ? AppColorsDesktop.success : AppColors.success).withValues(alpha: 0.2);
                    final baseAvailBorder = useDesktopColors ? AppColorsDesktop.success : AppColors.success;
                    final baseAvailText = useDesktopColors ? AppColorsDesktop.success : AppColors.success;
                    // «Продолжение» записи: только рамка (оранж.), заливка как у свободного — видно, что слот доступен.
                    final Color slotBg = isAvailable
                        ? (isSelectedStart ? accent : baseAvailBg)
                        : (useDesktopColors ? AppColorsDesktop.nestedBg : AppColors.nestedBg);
                    final Color slotBorder = isAvailable
                        ? (isSelectedStart
                            ? accent
                            : isContinuation
                                ? const Color(0xFFE65100)
                                : baseAvailBorder)
                        : borderColor;
                    final Color slotText = isAvailable
                        ? (isSelectedStart ? Colors.white : baseAvailText)
                        : tSecondary;
                    return GestureDetector(
                      onTap: isAvailable
                          ? () => setState(() {
                                _proposedDateTime = DateTime(_slotsDate.year, _slotsDate.month, _slotsDate.day, hour, minute);
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
                        child: Text(slot, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: slotText)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickProposedDateTime,
                icon: Icon(Icons.schedule_rounded, size: 18, color: accent),
                label: Text(
                  _proposedDateTime != null ? '${formatDate(_proposedDateTime!)} в ${formatTime(_proposedDateTime!)}' : 'Указать время вручную',
                  style: TextStyle(color: tPrimary),
                ),
                style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: accent)),
              ),
              if (_proposedDateTime != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.clear_rounded, color: tSecondary),
                  onPressed: () => setState(() => _proposedDateTime = null),
                  tooltip: 'Убрать время',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nestBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tSecondary)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(totalK),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: accent),
                    ),
                    Text(
                      '≈ ${formatDurationMinutes(totalMins)}',
                      style: TextStyle(fontSize: 13, color: tSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isSending || (_existingRows.isEmpty && _newRows.isEmpty)) ? null : _sendToClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_isSending ? 'Отправка...' : 'Отправить клиенту'),
          ),
        ],
      );

    if (widget.embeddedInDialog && widget.onClose != null) {
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
                  bottom: BorderSide(color: isDesktop ? AppColorsDesktop.border : AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 22,
                    color: isDesktop ? AppColorsDesktop.primary : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Изменить состав заказа',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      foregroundColor: isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Изменить состав заказа'),
      ),
      body: bodyContent,
    );
  }

  void _showAddFromCatalog(BuildContext context, List<ServiceItem> allServices) {
    final addedIds = [..._existingRows, ..._newRows].map((r) => r.item.id).toSet();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Добавить из каталога', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allServices.length,
                itemBuilder: (_, i) {
                  final s = allServices[i];
                  final alreadyAdded = addedIds.contains(s.id);
                  return ListTile(
                    title: Text(s.name, style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text('${formatMoney(s.priceKopecks)} • ${s.durationMinutes} мин', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    enabled: !alreadyAdded,
                    onTap: alreadyAdded ? null : () {
                      _addFromCatalog(s);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustom(BuildContext context) {
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
                decoration: const InputDecoration(labelText: 'Время'),
                items: [15, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m мин'))).toList(),
                onChanged: (v) => setDialogState(() => minutes = v ?? 30),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Цена, ₽',
                  hintText: '1000',
                ),
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
                _addCustom(name, minutes, priceKopecks);
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}
