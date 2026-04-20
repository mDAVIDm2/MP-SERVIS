import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/pdf/order_worksheet_pdf.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/utils/client_avatar_from_chats.dart';
import '../../../../core/api/services/api_services_providers.dart';
import 'master_picker_screen.dart';
import 'order_payment_screen.dart';
import 'confirm_correct_order_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import '../../../chats/presentation/widgets/authenticated_profile_avatar.dart';
import '../../../../shared/widgets/authenticated_api_image.dart';
import '../widgets/order_detail_panel.dart';

Widget _mobileServiceCompletionLeading(bool completed) {
  if (completed) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.success.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
    );
  }
  return Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.borderLight, width: 1.5),
      color: AppColors.nestedBg,
    ),
  );
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Всегда обновляем заказ при открытии экрана (актуальные items после подтверждения согласования и т.д.).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderRepositoryProvider.notifier).refreshOrder(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));
    final chatPreviews = ref.watch(chatRepositoryProvider).chats;
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    final canAssignMaster = ref.watch(authProvider).user?.role.canAssignMaster ?? false;

    if (isDesktopPlatform) {
      if (order == null) {
        return themeDesktopLight(
          child: Scaffold(
            backgroundColor: AppColorsDesktop.background,
            appBar: AppBar(title: const Text('Заказ')),
            body: const Center(
              child: Text(
                'Заказ не найден',
                style: TextStyle(color: AppColorsDesktop.textSecondary),
              ),
            ),
          ),
        );
      }
      return themeDesktopLight(
        child: Scaffold(
          backgroundColor: AppColorsDesktop.background,
          appBar: AppBar(
            title: const Text('Заказ'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Заказ-наряд (PDF)',
                onPressed: () => printOrderWorksheet(context, order, showPrices: canSeePrices),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: kOrderDetailPanelWidth,
                  height: constraints.maxHeight,
                  child: OrderDetailPanel(
                    orderId: widget.orderId,
                    onClose: () => Navigator.maybePop(context),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Заказ')),
        body: const Center(
          child: Text('Заказ не найден', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final hasBays = ref.watch(settingsRepositoryProvider).slotsSettings.hasNamedBays;
    final mainItems = order.itemsForDisplay.where((i) => !i.isAdditional).toList();
    final addItems = order.itemsForDisplay.where((i) => i.isAdditional).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Заказ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Заказ-наряд (PDF)',
            onPressed: () => printOrderWorksheet(context, order, showPrices: canSeePrices),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          _MobileOrderHeaderCard(order: order),
          if (order.carInfo.trim().isNotEmpty ||
              (order.carPhotoUrl != null && order.carPhotoUrl!.trim().isNotEmpty)) ...[
            const SizedBox(height: 12),
            _MobileSheet(child: _MobileCarBlock(order: order)),
          ],
          if (order.clientName != null || order.clientPhone != null) ...[
            const SizedBox(height: 12),
            _MobileSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AuthenticatedProfileAvatar(
                        imageUrl: resolvedClientAvatarUrl(
                          chats: chatPreviews,
                          orderClientAvatarUrl: order.clientAvatarUrl,
                          clientPhone: order.clientPhone,
                        ),
                        fallbackLetter: (order.clientName != null && order.clientName!.isNotEmpty)
                            ? order.clientName![0]
                            : '?',
                        size: 40,
                      ),
                      if (order.clientName != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            order.clientName!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (order.clientPhone != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        final uri = Uri(
                          scheme: 'tel',
                          path: order.clientPhone!.replaceAll(RegExp(r'[^\d+]'), ''),
                        );
                        launchUrl(uri);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.phone_in_talk_rounded,
                                color: AppColors.primary.withValues(alpha: 0.95), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                order.clientPhone!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (canAssignMaster && order.status.isActive) ...[
            const SizedBox(height: 10),
            _MobileSectionCaption(icon: Icons.schedule_rounded, label: 'Плановое время'),
            const SizedBox(height: 6),
            _MobileSheet(
              child: _PlannedTimeBlock(
                orderId: widget.orderId,
                order: order,
                compact: true,
                onEditTime: (start, end) => _showEditDialog(context, ref, widget.orderId, start, end),
              ),
            ),
          ],
          if (mainItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MobileSectionCaption(
              icon: Icons.build_circle_outlined,
              label: addItems.isNotEmpty ? 'Основные работы' : 'Услуги',
            ),
            const SizedBox(height: 6),
            _MobileSheet(
              child: Column(
                children: [
                  for (var i = 0; i < mainItems.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
                    _buildOrderServiceRow(context, order, mainItems[i], canSeePrices),
                  ],
                ],
              ),
            ),
          ],
          if (addItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MobileSectionCaption(icon: Icons.add_task_rounded, label: 'Доп. работы'),
            const SizedBox(height: 6),
            _MobileSheet(
              child: Column(
                children: [
                  for (var i = 0; i < addItems.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
                    _buildOrderServiceRow(context, order, addItems[i], canSeePrices),
                  ],
                ],
              ),
            ),
          ],
          if (canSeePrices && order.totalKopecksForDisplay > 0) ...[
            const SizedBox(height: 10),
            _MobileTotalBar(order: order),
          ],
          if (order.comment != null && order.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: AppColors.primary.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.comment!,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((canAssignMaster && order.status.isActive) ||
              order.masterName != null ||
              hasBays) ...[
            const SizedBox(height: 10),
            _MobileSectionCaption(icon: Icons.engineering_outlined, label: 'Назначение'),
            const SizedBox(height: 6),
            _MobileSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canAssignMaster && order.status.isActive) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Мастер',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.masterName ?? 'Не назначен',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: order.masterName == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (order.masterId != null && order.masterId!.isNotEmpty) ...[
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            tooltip: 'Сменить мастера',
                            icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
                            onPressed: () async {
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => MasterPickerScreen(orderId: widget.orderId)),
                              );
                            },
                          ),
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            tooltip: 'Снять мастера',
                            icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 22),
                            onPressed: () async {
                              final repo = ref.read(orderRepositoryProvider.notifier);
                              final r = await repo.clearMaster(widget.orderId);
                              if (!context.mounted) return;
                              if (r.errorOrNull != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(r.errorOrNull!.message),
                                      backgroundColor: AppColors.error),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Мастер снят с заказа')),
                                );
                              }
                            },
                          ),
                        ] else
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            tooltip: 'Назначить мастера',
                            icon: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
                            onPressed: () async {
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => MasterPickerScreen(orderId: widget.orderId)),
                              );
                            },
                          ),
                      ],
                    ),
                  ] else if (order.masterName != null) ...[
                    Text(
                      'Мастер',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.masterName!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  if (hasBays &&
                      ((canAssignMaster && order.status.isActive) || order.masterName != null)) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
                    const SizedBox(height: 10),
                  ],
                  if (hasBays) ...[
                    Text(
                      'Пост',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.bayName != null && order.bayName!.trim().isNotEmpty
                          ? order.bayName!.trim()
                          : (order.bayId != null && order.bayId!.trim().isNotEmpty
                              ? order.bayId!.trim()
                              : 'Не назначен'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: (order.bayId == null || order.bayId!.isEmpty)
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _MobileSectionCaption(icon: Icons.touch_app_outlined, label: 'Действия'),
          const SizedBox(height: 6),
          _MobileSheet(
            child: _Actions(
              orderId: widget.orderId,
              order: order,
              canAssignMaster: canAssignMaster,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderServiceRow(BuildContext context, Order order, OrderItem item, bool canSeePrices) {
    final canTap = order.status.isActive && order.status != OrderStatus.pendingApproval;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap
            ? () async {
                final notifier = ref.read(orderRepositoryProvider.notifier);
                final result = item.isCompleted
                    ? await notifier.uncompleteOrderItem(order.id, item.id)
                    : await notifier.completeOrderItem(order.id, item.id);
                if (!context.mounted) return;
                if (result.errorOrNull != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.errorOrNull!.message), backgroundColor: AppColors.cardBg),
                  );
                }
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _mobileServiceCompletionLeading(item.isCompleted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textSecondary,
                        color: item.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.durationLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (canSeePrices && item.priceKopecks != null) ...[
                const SizedBox(width: 6),
                Text(
                  formatMoney(item.priceKopecks!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: item.isCompleted ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, String orderId, DateTime initialStart, DateTime initialEnd) async {
    final baseDate = DateTime(initialStart.year, initialStart.month, initialStart.day);
    var start = DateTime(baseDate.year, baseDate.month, baseDate.day, initialStart.hour, initialStart.minute);
    var end = DateTime(baseDate.year, baseDate.month, baseDate.day, initialEnd.hour, initialEnd.minute);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Плановое время'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Начало'),
                  trailing: Text(formatTime(start)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: start.hour, minute: start.minute));
                    if (t != null) setState(() => start = DateTime(baseDate.year, baseDate.month, baseDate.day, t.hour, t.minute));
                  },
                ),
                ListTile(
                  title: const Text('Окончание'),
                  trailing: Text(formatTime(end)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: end.hour, minute: end.minute));
                    if (t != null) setState(() => end = DateTime(baseDate.year, baseDate.month, baseDate.day, t.hour, t.minute));
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                onPressed: () {
                  if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Окончание должно быть позже начала')));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
    if (result != true || !context.mounted) return;
    start = DateTime(baseDate.year, baseDate.month, baseDate.day, start.hour, start.minute);
    end = DateTime(baseDate.year, baseDate.month, baseDate.day, end.hour, end.minute);
    final res = await ref.read(orderRepositoryProvider.notifier).updateOrderTime(orderId, plannedStartTime: start, plannedEndTime: end);
    if (!context.mounted) return;
    res.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Время обновлено'))),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error)),
    );
  }
}

/// Компактная шапка: номер, дата/время, статус (акцент на статусе цветом).
class _MobileOrderHeaderCard extends StatelessWidget {
  const _MobileOrderHeaderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = order.status.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.displayNumber,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateTimeOrNull(order.dateTime),
                  style: const TextStyle(fontSize: 12, height: 1.25, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.withValues(alpha: 0.45)),
            ),
            child: Text(
              order.status.label,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSheet extends StatelessWidget {
  const _MobileSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _MobileSectionCaption extends StatelessWidget {
  const _MobileSectionCaption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.85,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Фото автомобиля сверху (как аватарка), ниже — описание и реквизиты.
class _MobileCarBlock extends ConsumerWidget {
  const _MobileCarBlock({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final hasPhoto = order.carPhotoUrl != null && order.carPhotoUrl!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: hasPhoto
              ? AuthenticatedApiImage(
                  imageUrl: order.carPhotoUrl,
                  width: 112,
                  height: 112,
                  borderRadius: 56,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.nestedBg,
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 52,
                    color: AppColors.textTertiary,
                  ),
                ),
        ),
        if (order.carInfo.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            order.carInfo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
          ),
        ],
        _MobileCarMetaWrap(order: order),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_rounded, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                order.appointmentRangeLabel,
                style: const TextStyle(fontSize: 13, height: 1.3, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileCarMetaWrap extends StatelessWidget {
  const _MobileCarMetaWrap({required this.order});

  final Order order;

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label скопирован в буфер'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plate = order.licensePlate?.trim();
    final vin = order.vin?.trim();
    final secondary = <String>[];
    if (order.bodyType != null && order.bodyType!.trim().isNotEmpty) {
      secondary.add(order.bodyType!.trim());
    }
    if (order.color != null && order.color!.trim().isNotEmpty) {
      secondary.add(order.color!.trim());
    }
    if (order.mileage != null) {
      secondary.add('${order.mileage} км');
    }
    if (order.engineType != null && order.engineType!.trim().isNotEmpty) {
      secondary.add(order.engineType!.trim());
    }

    final hasPrimary =
        (plate != null && plate.isNotEmpty) || (vin != null && vin.isNotEmpty);
    if (!hasPrimary && secondary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plate != null && plate.isNotEmpty)
            _MobileVehicleCopyTile(
              label: 'Госномер',
              value: plate,
              monospaceValue: false,
              onTap: () => _copy(context, 'Госномер', plate),
            ),
          if (plate != null && plate.isNotEmpty && vin != null && vin.isNotEmpty)
            const SizedBox(height: 8),
          if (vin != null && vin.isNotEmpty)
            _MobileVehicleCopyTile(
              label: 'VIN',
              value: vin,
              monospaceValue: true,
              onTap: () => _copy(context, 'VIN', vin),
            ),
          if (secondary.isNotEmpty) ...[
            if (hasPrimary) const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: secondary
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.nestedBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 11, height: 1.2, color: AppColors.textSecondary),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileVehicleCopyTile extends StatelessWidget {
  const _MobileVehicleCopyTile({
    required this.label,
    required this.value,
    required this.monospaceValue,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool monospaceValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.nestedBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: AppColors.textPrimary,
                        fontFamily: monospaceValue ? 'monospace' : null,
                        letterSpacing: monospaceValue ? 0.4 : 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTotalBar extends StatelessWidget {
  const _MobileTotalBar({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final totalKopecks = order.totalKopecksForDisplay;
    final dm = order.effectiveDurationMinutes > 0 ? order.effectiveDurationMinutes : 60;
    final hourly = formatEquivalentHourlyRateLine(totalKopecks, dm);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Text(
              'Итого',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(totalKopecks),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'на ${formatDurationMinutes(dm)}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.95)),
              ),
              if (hourly != null)
                Text(
                  hourly,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withValues(alpha: 0.9)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Блок планового времени с кнопкой «Изменить» (вызов PATCH /orders/:id/time).
class _PlannedTimeBlock extends StatelessWidget {
  final String orderId;
  final Order order;
  final void Function(DateTime start, DateTime end)? onEditTime;
  final bool compact;

  const _PlannedTimeBlock({
    required this.orderId,
    required this.order,
    this.onEditTime,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final startRaw = order.plannedStartTime ?? order.effectiveDateTime;
    final endRaw = order.plannedEndTime ?? order.effectiveDateTime.add(Duration(minutes: order.items.fold<int>(0, (s, i) => s + i.estimatedMinutes)));
    final start = startRaw.isUtc ? startRaw.toLocal() : startRaw;
    final end = endRaw.isUtc ? endRaw.toLocal() : endRaw;
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${formatTime(start)} — ${formatTime(end)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onEditTime != null ? () => onEditTime!(start, end) : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Изменить'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 22, color: AppColors.primary.withValues(alpha: 0.9)),
                    const SizedBox(width: 10),
                    Text('С ${formatTime(start)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stop_circle_outlined, size: 22, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text('По ${formatTime(end)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onEditTime != null ? () => onEditTime!(start, end) : null,
            icon: const Icon(Icons.edit_calendar_rounded, size: 20),
            label: const Text('Изменить время'),
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  final String orderId;
  final Order order;
  final bool canAssignMaster;

  const _Actions({
    required this.orderId,
    required this.order,
    required this.canAssignMaster,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(orderRepositoryProvider.notifier);

    void showMessage(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.cardBg),
      );
    }

    Future<void> setStatus(OrderStatus status, String successMsg) async {
      final result = await repo.setOrderStatus(orderId, status);
      if (!context.mounted) return;
      if (result.errorOrNull == null) {
        showMessage(successMsg);
      } else {
        showMessage(result.errorOrNull!.message);
      }
    }

    Future<void> cancel() async {
      final result = await repo.cancelOrder(orderId);
      if (!context.mounted) return;
      if (result.errorOrNull == null) {
        showMessage('Заказ отменён');
        Navigator.pop(context);
      } else {
        showMessage(result.errorOrNull!.message);
      }
    }

    final canChangeComposition = order.status != OrderStatus.done && order.status != OrderStatus.cancelled;

    /// На мобильном — переход на полный экран (состав, правка услуг, время). Без диалога.
    Future<void> openComposeOverlay() async {
      final orderApi = ref.read(orderApiServiceProvider);
      final chatResult = await orderApi.getChatForOrder(orderId);
      if (!context.mounted) return;
      final chatId = chatResult.dataOrNull;
      if (chatId == null || chatId.isEmpty) {
        showMessage(chatResult.errorOrNull?.message ?? 'Чат по заказу не найден');
        return;
      }
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmCorrectOrderScreen(
            orderId: orderId,
            chatId: chatId,
          ),
        ),
      );
      if (context.mounted) ref.read(orderRepositoryProvider.notifier).refreshOrder(orderId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Одна кнопка «Изменить состав»: для ожидания подтверждения и «Подтверждён» ниже свои кнопки — не дублируем.
        if (canChangeComposition &&
            order.status != OrderStatus.pendingConfirmation &&
            order.status != OrderStatus.confirmed) ...[
          OutlinedButton.icon(
            onPressed: () async {
              await openComposeOverlay();
              if (context.mounted) showMessage('Перечень работ отправлен клиенту');
            },
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
        ],
        if (order.status.isActive) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final orderApi = ref.read(orderApiServiceProvider);
              final chatResult = await orderApi.getChatForOrder(orderId);
              if (!context.mounted) return;
              final chatId = chatResult.dataOrNull;
              if (chatId == null || chatId.isEmpty) {
                showMessage(chatResult.errorOrNull?.message ?? 'Чат по заказу не найден');
                return;
              }
              await ensureChatDataLoaded(ref, chatId, refValid: () => context.mounted);
              if (!context.mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(chatId: chatId, currentOrderId: orderId),
                  ),
                );
              });
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            label: const Text('Открыть чат'),
          ),
          const SizedBox(height: 8),
        ],
        if (order.status == OrderStatus.pendingConfirmation) ...[
          ElevatedButton(
            onPressed: () async {
              await openComposeOverlay();
              if (context.mounted) showMessage('Перечень работ отправлен клиенту');
            },
            child: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setStatus(OrderStatus.confirmed, 'Заказ подтверждён без изменений'),
            child: const Text('Подтвердить без изменений'),
          ),
        ],
        if (order.status == OrderStatus.confirmed) ...[
          OutlinedButton(
            onPressed: () async {
              await openComposeOverlay();
              if (context.mounted) showMessage('Перечень работ отправлен клиенту на согласование');
            },
            child: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
          if (canAssignMaster) ...[
            OutlinedButton(
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MasterPickerScreen(orderId: orderId),
                  ),
                );
                if (updated == true && context.mounted) {}
              },
              child: const Text('Назначить мастера'),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: () => setStatus(OrderStatus.inProgress, 'Статус: В работе'),
            child: const Text('В работу'),
          ),
        ],
        if (order.status == OrderStatus.inProgress) ...[
          ElevatedButton(
            onPressed: () => setStatus(OrderStatus.completed, 'Готово к выдаче'),
            child: const Text('Завершить работы'),
          ),
        ],
        if (order.status == OrderStatus.pendingApproval) ...[
          ElevatedButton(
            onPressed: () async {
              final result = await repo.confirmOrderByPhone(orderId);
              if (!context.mounted) return;
              if (result.errorOrNull == null) {
                await ref.read(orderRepositoryProvider.notifier).refreshOrder(orderId);
                if (!context.mounted) return;
                showMessage('Подтверждено по телефону');
              } else {
                showMessage(result.errorOrNull!.message);
              }
            },
            child: const Text('Подтвердить по телефону'),
          ),
        ],
        if (order.status == OrderStatus.completed) ...[
          ElevatedButton(
            onPressed: () async {
              final closed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderPaymentScreen(orderId: orderId),
                ),
              );
              if (closed == true && context.mounted) Navigator.pop(context);
            },
            child: const Text('Оплата / Выдать заказ'),
          ),
        ],
        if (order.status.isActive) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Отменить заказ?'),
                  content: const Text('Заказ будет отменён. Эту операцию нельзя отменить.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Нет'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Отменить заказ'),
                    ),
                  ],
                ),
              );
              if (confirm == true) await cancel();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            child: const Text('Отменить заказ'),
          ),
        ],
        if (order.status == OrderStatus.cancelled ||
            order.status == OrderStatus.done ||
            order.status == OrderStatus.completed) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Скрыть заказ?'),
                  content: const Text(
                    'Заказ исчезнет из списков, расписания и чатов. В БД сохранится с пометкой «удалён». Вы больше не будете его видеть.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Скрыть'),
                    ),
                  ],
                ),
              );
              if (confirm != true || !context.mounted) return;
              final result = await repo.hideOrderFromUser(orderId);
              if (!context.mounted) return;
              result.when(
                success: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заказ скрыт из списка')),
                  );
                  Navigator.pop(context);
                },
                failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.visibility_off_rounded, size: 20),
            label: const Text('Скрыть из списка'),
          ),
        ],
      ],
    );
  }
}
