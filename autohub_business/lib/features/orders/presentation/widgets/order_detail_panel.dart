import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/pdf/order_worksheet_pdf.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/utils/client_avatar_from_chats.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../screens/master_picker_screen.dart';
import '../screens/order_payment_screen.dart';
import '../screens/confirm_correct_order_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import '../../../chats/presentation/widgets/authenticated_profile_avatar.dart';
import '../../../../shared/widgets/authenticated_api_image.dart';

/// Ширина правой панели деталей заказа (desktop).
const double kOrderDetailPanelWidth = 465.0; // ~7% уже 500

/// Индикатор услуги: пустой круг → выполнено: зелёный круг с галочкой (центрируется в [Row] с `CrossAxisAlignment.center`).
Widget _orderServiceCompletionLeading(bool completed, {double size = 22}) {
  if (completed) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColorsDesktop.success.withValues(alpha: 0.16),
        border: Border.all(color: AppColorsDesktop.success.withValues(alpha: 0.48)),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded, size: size * 0.64, color: AppColorsDesktop.success),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColorsDesktop.border, width: 1.5),
    ),
  );
}

/// Состав заказа из сообщения согласования (для fallback при пустом order).
List<ApprovalItem> _itemsFromApprovalMessage(ChatMessage m) {
  final list = <ApprovalItem>[];
  if (m.originalApprovalItems != null) list.addAll(m.originalApprovalItems!);
  if (m.editedApprovalItems != null) {
    for (final e in m.editedApprovalItems!) {
      list.add(ApprovalItem(name: e.name, priceKopecks: e.priceKopecks, estimatedMinutes: e.estimatedMinutes));
    }
  }
  if (m.newApprovalItems != null) list.addAll(m.newApprovalItems!);
  if (m.approvalItems != null && list.isEmpty) list.addAll(m.approvalItems!);
  return list;
}

/// Цвет бейджа статуса для light desktop UI.
Color _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pendingConfirmation:
      return AppColorsDesktop.statusPending;
    case OrderStatus.confirmed:
      return AppColorsDesktop.statusConfirmed;
    case OrderStatus.inProgress:
      return AppColorsDesktop.statusInProgress;
    case OrderStatus.pendingApproval:
      return AppColorsDesktop.statusApproval;
    case OrderStatus.completed:
      return AppColorsDesktop.statusCompleted;
    case OrderStatus.done:
      return AppColorsDesktop.statusDone;
    case OrderStatus.cancelled:
      return AppColorsDesktop.statusCancelled;
  }
}

String _masterInitials(String? name) {
  if (name == null || name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : parts[0].toUpperCase();
}

/// Пустой state правой панели: спокойно и профессионально (ТЗ п.5).
class OrderDetailPlaceholder extends StatelessWidget {
  const OrderDetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kOrderDetailPanelWidth,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.background,
        border: Border(left: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 40, color: AppColorsDesktop.textTertiary),
              const SizedBox(height: 14),
              Text(
                'Выберите заказ',
                style: DesktopDesignSystem.sectionTitle.copyWith(
                  fontSize: 15,
                  color: AppColorsDesktop.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Справа появятся подробности, клиент, состав работ, мастер и действия',
                textAlign: TextAlign.center,
                style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Контейнер карточки секции: единый радиус, мягкая тень, аккуратные отступы.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 14, color: AppColorsDesktop.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Блок 1: Header заказа — номер, статус, даты; звонок только в блоке «Клиент».
class OrderDetailHeader extends StatelessWidget {
  const OrderDetailHeader({
    super.key,
    required this.order,
  required this.onChat,
  required this.onMoreSelected,
  this.onClose,
  });

  final Order order;
  final VoidCallback? onChat;
  final void Function(String? value)? onMoreSelected;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesktopDesignSystem.blockSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '#${order.orderNumber}',
                        style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 18),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
                        ),
                        child: Text(
                          order.status.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Запись: ${order.appointmentRangeLabel}',
                  style: DesktopDesignSystem.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Мастер: ${order.masterName != null && order.masterName!.trim().isNotEmpty ? order.masterName!.trim() : '—'}',
                  style: DesktopDesignSystem.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Автомобиль: ${order.carInfo.trim().isNotEmpty ? order.carInfo.trim() : '—'}',
                  style: DesktopDesignSystem.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Гос. номер: ${order.licensePlate != null && order.licensePlate!.trim().isNotEmpty ? order.licensePlate!.trim() : '—'}',
                  style: DesktopDesignSystem.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                  style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                onPressed: onChat,
                tooltip: 'Открыть чат',
                style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.primary),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              if (onMoreSelected != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  tooltip: 'Ещё',
                  padding: EdgeInsets.zero,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 8),
                  color: AppColorsDesktop.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
                  onSelected: onMoreSelected!,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'pdf', child: Text('Заказ-наряд (PDF)')),
                    const PopupMenuItem(value: 'chat', child: Text('Открыть чат')),
                    const PopupMenuItem(value: 'compose', child: Text('Изменить состав')),
                    const PopupMenuItem(value: 'time', child: Text('Изменить время')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Блок 2: Summary — клиент, авто, мастер, длительность, итог.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.order,
    required this.canSeePrices,
    this.fallbackTotalKopecks,
    this.fallbackDurationMin,
    this.clientSectionHighlighted = false,
    this.clientAvatarUrl,
    this.onClientCall,
    this.onClientChat,
    this.onClientCopyPhone,
  });

  final Order order;
  final bool canSeePrices;
  final String? clientAvatarUrl;
  /// При пустом order.items (заказ из запроса согласования) — итог из сообщения.
  final int? fallbackTotalKopecks;
  final int? fallbackDurationMin;
  /// Подсветить блок клиента (например после открытия с акцентом на клиента).
  final bool clientSectionHighlighted;
  final VoidCallback? onClientCall;
  final VoidCallback? onClientChat;
  final VoidCallback? onClientCopyPhone;

  /// Строка «окно»: дата + интервал «10:00–12:20» (как в шапке заказа).
  static String windowSummary(Order order) => order.appointmentRangeLabel;

  @override
  Widget build(BuildContext context) {
    final useFallback = order.items.isEmpty && (fallbackTotalKopecks != null || fallbackDurationMin != null);
    final durationMin = useFallback && fallbackDurationMin != null
        ? fallbackDurationMin!
        : order.effectiveDurationMinutes;
    final totalKopecks = useFallback && fallbackTotalKopecks != null
        ? fallbackTotalKopecks!
        : order.totalKopecksForDisplay;
    final dmForTotals = durationMin > 0 ? durationMin : 60;
    final hourlyRateLabel = formatEquivalentHourlyRateLine(totalKopecks, dmForTotals);
    final disp = order.itemsForDisplay;
    final mainKopecks = disp
        .where((i) => !i.isAdditional && i.priceKopecks != null)
        .fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final addKopecks = disp
        .where((i) => i.isAdditional && i.priceKopecks != null)
        .fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final useFallbackTotal = order.items.isEmpty &&
        !order.hasApprovalPreview &&
        fallbackTotalKopecks != null &&
        fallbackTotalKopecks! > 0;

    final name = order.clientName ?? '—';
    final letter = name.isNotEmpty && name != '—' ? name[0] : '?';

    return _SectionCard(
      title: 'Сводка',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: clientSectionHighlighted
                          ? BoxDecoration(
                              color: const Color(0xFFE85C0A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8, top: 2),
                                child: AuthenticatedProfileAvatar(
                                  imageUrl: clientAvatarUrl,
                                  fallbackLetter: letter,
                                  size: 32,
                                ),
                              ),
                              Expanded(child: _summaryRow('Клиент', name)),
                            ],
                          ),
                          if (order.clientPhone != null && order.clientPhone!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 100),
                                Expanded(
                                  child: SelectableText(
                                    order.clientPhone!.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColorsDesktop.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (onClientCall != null)
                                  IconButton(
                                    icon: const Icon(Icons.phone_rounded, size: 18),
                                    onPressed: onClientCall,
                                    tooltip: 'Позвонить',
                                    style: IconButton.styleFrom(
                                      foregroundColor: AppColorsDesktop.primary,
                                      minimumSize: const Size(36, 36),
                                    ),
                                  ),
                                if (onClientChat != null)
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                    onPressed: onClientChat,
                                    tooltip: 'Написать',
                                    style: IconButton.styleFrom(
                                      foregroundColor: AppColorsDesktop.primary,
                                      minimumSize: const Size(36, 36),
                                    ),
                                  ),
                                if (onClientCopyPhone != null)
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    onPressed: onClientCopyPhone,
                                    tooltip: 'Копировать номер',
                                    style: IconButton.styleFrom(
                                      foregroundColor: AppColorsDesktop.textSecondary,
                                      minimumSize: const Size(36, 36),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (order.comment != null && order.comment!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              order.comment!,
                              style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _summaryRow('Автомобиль', order.carInfo),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Окно:',
                            style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            OrderSummaryCard.windowSummary(order),
                            style: DesktopDesignSystem.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'длительность ${formatDurationMinutes(dmForTotals)}',
                          style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if ((order.bayName != null && order.bayName!.trim().isNotEmpty) ||
                        (order.bayId != null && order.bayId!.trim().isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      _summaryRow(
                        'Пост',
                        order.bayName != null && order.bayName!.trim().isNotEmpty
                            ? order.bayName!.trim()
                            : order.bayId!.trim(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canSeePrices && totalKopecks > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColorsDesktop.border),
            const SizedBox(height: 10),
            if (!useFallbackTotal && mainKopecks > 0)
              _summaryPricingRow('Базовая стоимость', mainKopecks),
            if (!useFallbackTotal && addKopecks > 0) ...[
              const SizedBox(height: 4),
              _summaryPricingRow('Доп. работы', addKopecks, isAdditional: true),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итого',
                  style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 13),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(totalKopecks),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColorsDesktop.accentMoney,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'на ${formatDurationMinutes(dmForTotals)}',
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 11),
                    ),
                    if (hourlyRateLabel != null)
                      Text(
                        hourlyRateLabel,
                        style: DesktopDesignSystem.meta.copyWith(fontSize: 11, color: AppColorsDesktop.textTertiary),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryPricingRow(String label, int kopecks, {bool isAdditional = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: DesktopDesignSystem.bodySecondary.copyWith(
              color: isAdditional ? AppColorsDesktop.statusApproval : AppColorsDesktop.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            formatMoney(kopecks),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAdditional ? AppColorsDesktop.statusApproval : AppColorsDesktop.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: DesktopDesignSystem.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

}

/// Блок 3: Автомобиль — марка/модель и детали (VIN, гос. номер, кузов, цвет, пробег, двигатель).
class OrderVehicleCard extends ConsumerWidget {
  const OrderVehicleCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plate = order.licensePlate?.trim();
    final vin = order.vin?.trim();
    final hasPrimaryIds =
        (plate != null && plate.isNotEmpty) || (vin != null && vin.isNotEmpty);
    final hasOtherDetails = (order.bodyType != null && order.bodyType!.isNotEmpty) ||
        (order.color != null && order.color!.isNotEmpty) ||
        (order.mileage != null) ||
        (order.engineType != null && order.engineType!.isNotEmpty);
    return _SectionCard(
      title: 'Автомобиль',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.carPhotoUrl != null && order.carPhotoUrl!.trim().isNotEmpty) ...[
            AuthenticatedApiImage(
              imageUrl: order.carPhotoUrl,
              width: kOrderDetailPanelWidth - 32,
              height: 120,
              borderRadius: 12,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            order.carInfo,
            style: DesktopDesignSystem.body,
          ),
          if (hasPrimaryIds) ...[
            const SizedBox(height: 12),
            if (plate != null && plate.isNotEmpty)
              _vehiclePrimaryCopyTile(context, label: 'Госномер', value: plate),
            if (plate != null && plate.isNotEmpty && vin != null && vin.isNotEmpty)
              const SizedBox(height: 8),
            if (vin != null && vin.isNotEmpty)
              _vehiclePrimaryCopyTile(context, label: 'VIN', value: vin),
          ],
          if (hasOtherDetails) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColorsDesktop.borderLight),
            const SizedBox(height: 8),
            if (order.bodyType != null && order.bodyType!.isNotEmpty)
              _vehicleRow('Тип кузова', order.bodyType!),
            if (order.color != null && order.color!.isNotEmpty)
              _vehicleRow('Цвет', order.color!),
            if (order.mileage != null)
              _vehicleRow('Пробег', '${order.mileage} км'),
            if (order.engineType != null && order.engineType!.isNotEmpty)
              _vehicleRow('Двигатель', order.engineType!),
          ],
        ],
      ),
    );
  }

  static Widget _vehicleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesktopDesignSystem.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Госномер / VIN: крупно, нажатие копирует значение.
  static Widget _vehiclePrimaryCopyTile(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Material(
      color: AppColorsDesktop.nestedBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label скопирован в буфер'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        },
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
                      style: DesktopDesignSystem.meta.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColorsDesktop.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: DesktopDesignSystem.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: label == 'VIN' ? 'monospace' : null,
                        letterSpacing: label == 'Госномер' ? 0.8 : 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: 18, color: AppColorsDesktop.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Блок 5: Запись и время.
class OrderScheduleCard extends StatelessWidget {
  const OrderScheduleCard({
    super.key,
    required this.order,
    required this.onEditTime,
    required this.canAssignMaster,
  });

  final Order order;
  final VoidCallback? onEditTime;
  final bool canAssignMaster;

  @override
  Widget build(BuildContext context) {
    final start = order.plannedStartTime ?? order.dateTime;
    final end = order.plannedEndTime;
    final durationFromItems = order.estimatedMinutesForDisplay;
    final durationMin = (order.plannedStartTime != null && order.plannedEndTime != null)
        ? order.plannedEndTime!.difference(order.plannedStartTime!).inMinutes
        : durationFromItems;
    final endComputed = end ?? start?.add(Duration(minutes: durationMin > 0 ? durationMin : 60));

    return _SectionCard(
      title: 'Запись и время',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Дата: ${formatDateOrNull(start)}',
            style: DesktopDesignSystem.body,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Окно: ${formatTimeOrNull(start)} – ${formatTimeOrNull(endComputed)}',
                  style: DesktopDesignSystem.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'длительность ${formatDurationMinutes(durationMin > 0 ? durationMin : 60)}',
                style: DesktopDesignSystem.meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (onEditTime != null && canAssignMaster) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditTime,
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: const Text('Изменить время'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColorsDesktop.primary,
                    side: const BorderSide(color: AppColorsDesktop.border),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Блок 6: Мастер.
class OrderMasterCard extends StatelessWidget {
  const OrderMasterCard({
    super.key,
    required this.order,
    required this.onAssignMaster,
    required this.canAssignMaster,
  });

  final Order order;
  final VoidCallback? onAssignMaster;
  final bool canAssignMaster;

  @override
  Widget build(BuildContext context) {
    final hasMaster = order.masterName != null && order.masterName!.isNotEmpty;
    return _SectionCard(
      title: 'Мастер',
      child: Row(
        children: [
          if (hasMaster) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
              foregroundColor: AppColorsDesktop.primary,
              child: Text(
                _masterInitials(order.masterName),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                order.masterName!,
                style: DesktopDesignSystem.body,
              ),
            ),
          ] else
            Expanded(
              child: Text(
                'Не назначен',
                style: DesktopDesignSystem.bodySecondary,
              ),
            ),
          if (canAssignMaster && order.status.isActive)
            OutlinedButton(
              onPressed: onAssignMaster,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColorsDesktop.primary,
                side: const BorderSide(color: AppColorsDesktop.border),
              ),
              child: Text(hasMaster ? 'Изменить' : 'Назначить мастера'),
            ),
        ],
      ),
    );
  }
}

/// Блок 7: Состав заказа — по категориям услуг (как в настройках прайса), внутри категории — основные и доп. работы.
class OrderServicesCard extends ConsumerWidget {
  const OrderServicesCard({
    super.key,
    required this.order,
    required this.canSeePrices,
    required this.onToggleItemComplete,
    this.fallbackItems,
  });

  final Order order;
  final bool canSeePrices;
  final void Function(OrderItem item)? onToggleItemComplete;
  /// При пустом order.items — состав из запроса согласования (только отображение).
  final List<ApprovalItem>? fallbackItems;

  /// Сопоставить позицию заказа с категорией по каталогу услуг (по `service_id`, иначе по имени).
  static String? _categoryIdForItem(OrderItem item, List<ServiceItem> services) {
    final sid = item.serviceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      final byId = services.where((s) => s.id == sid).toList();
      if (byId.isNotEmpty) return byId.first.categoryId;
    }
    final firstLine = item.name.split('\n').first.trim();
    final list = services.where((s) => s.name == firstLine).toList();
    return list.isEmpty ? null : list.first.categoryId;
  }

  static String? _categoryIdForApprovalItem(ApprovalItem item, List<ServiceItem> services) {
    final list = services.where((s) => s.name == item.name).toList();
    return list.isEmpty ? null : list.first.categoryId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsRepositoryProvider);
    final categories = List<ServiceCategory>.from(settings.categories)..sort((a, b) => a.order.compareTo(b.order));
    final allItems = order.itemsForDisplay;
    final useFallback = order.items.isEmpty &&
        !order.hasApprovalPreview &&
        (fallbackItems != null && fallbackItems!.isNotEmpty);

    final Map<String, List<OrderItem>> byCategory = {};
    final List<OrderItem> noCategory = [];
    for (final item in allItems) {
      final cid = _categoryIdForItem(item, settings.services);
      if (cid != null && cid.isNotEmpty) {
        byCategory.putIfAbsent(cid, () => []).add(item);
      } else {
        noCategory.add(item);
      }
    }

    final Map<String, List<ApprovalItem>> fallbackByCategory = {};
    final List<ApprovalItem> fallbackNoCategory = [];
    if (useFallback && fallbackItems != null) {
      for (final item in fallbackItems!) {
        final cid = _categoryIdForApprovalItem(item, settings.services);
        if (cid != null && cid.isNotEmpty) {
          fallbackByCategory.putIfAbsent(cid, () => []).add(item);
        } else {
          fallbackNoCategory.add(item);
        }
      }
    }

    return _SectionCard(
      title: 'Состав заказа',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!useFallback) ...[
            for (final cat in categories) ...[
              if ((byCategory[cat.id] ?? []).isNotEmpty) ...[
                Text(
                  cat.name,
                  style: DesktopDesignSystem.label.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...(byCategory[cat.id]!).map((item) => _serviceRow(
                      context,
                      item,
                      canSeePrices,
                      order.status.isActive && order.status != OrderStatus.pendingApproval,
                      onToggleItemComplete,
                    )),
                const SizedBox(height: 12),
              ],
            ],
            if (noCategory.isNotEmpty) ...[
              Text(
                'Прочее',
                style: DesktopDesignSystem.label.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...noCategory.map((item) => _serviceRow(
                    context,
                    item,
                    canSeePrices,
                    order.status.isActive && order.status != OrderStatus.pendingApproval,
                    onToggleItemComplete,
                  )),
              const SizedBox(height: 12),
            ],
          ],
          if (useFallback) ...[
            for (final cat in categories) ...[
              if ((fallbackByCategory[cat.id] ?? []).isNotEmpty) ...[
                Text(
                  cat.name,
                  style: DesktopDesignSystem.label.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...(fallbackByCategory[cat.id]!).map((item) => _approvalItemRow(context, item, canSeePrices)),
                const SizedBox(height: 12),
              ],
            ],
            if (fallbackNoCategory.isNotEmpty) ...[
              Text(
                'Прочее',
                style: DesktopDesignSystem.label.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...fallbackNoCategory.map((item) => _approvalItemRow(context, item, canSeePrices)),
              const SizedBox(height: 12),
            ],
          ],
          if (allItems.isEmpty && !useFallback)
            Text(
              'Нет позиций',
              style: DesktopDesignSystem.bodySecondary,
            ),
          if (useFallback && (fallbackItems == null || fallbackItems!.isEmpty))
            Text(
              'Нет позиций',
              style: DesktopDesignSystem.bodySecondary,
            ),
          if (order.comment != null && order.comment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColorsDesktop.statusPending.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColorsDesktop.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment_outlined, size: 16, color: AppColorsDesktop.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Комментарий к заказу',
                        style: DesktopDesignSystem.label.copyWith(fontSize: 12, color: AppColorsDesktop.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.comment!,
                    style: DesktopDesignSystem.body.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _approvalItemRow(BuildContext context, ApprovalItem item, bool canSeePrices) {
    final durationLabel = item.estimatedMinutes >= 60
        ? '${item.estimatedMinutes ~/ 60} ч ${item.estimatedMinutes % 60} мин'
        : '${item.estimatedMinutes} мин';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _orderServiceCompletionLeading(false, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColorsDesktop.textPrimary,
                  ),
                ),
                Text(
                  durationLabel,
                  style: DesktopDesignSystem.meta,
                ),
              ],
            ),
          ),
          if (canSeePrices)
            Text(
              formatMoney(item.priceKopecks),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColorsDesktop.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  static Widget _serviceRow(BuildContext context, OrderItem item, bool canSeePrices, bool canTap, void Function(OrderItem)? onToggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: canTap ? () => onToggle?.call(item) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _orderServiceCompletionLeading(item.isCompleted, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColorsDesktop.textPrimary,
                        decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      item.durationLabel,
                      style: DesktopDesignSystem.meta,
                    ),
                  ],
                ),
              ),
              if (canSeePrices && item.priceKopecks != null)
                Text(
                  formatMoney(item.priceKopecks!),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColorsDesktop.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Блок 8: Финансовый итог.
class OrderPricingCard extends StatelessWidget {
  const OrderPricingCard({
    super.key,
    required this.order,
    required this.canSeePrices,
    this.fallbackTotalKopecks,
  });

  final Order order;
  final bool canSeePrices;
  final int? fallbackTotalKopecks;

  @override
  Widget build(BuildContext context) {
    final totalK = order.hasApprovalPreview || order.items.isNotEmpty
        ? order.totalKopecksForDisplay
        : (fallbackTotalKopecks ?? 0);
    if (!canSeePrices || totalK <= 0) return const SizedBox.shrink();

    final disp = order.itemsForDisplay;
    final mainKopecks = disp
        .where((i) => !i.isAdditional && i.priceKopecks != null)
        .fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final addKopecks = disp
        .where((i) => i.isAdditional && i.priceKopecks != null)
        .fold<int>(0, (s, i) => s + (i.priceKopecks ?? 0));
    final useFallbackTotal = order.items.isEmpty &&
        !order.hasApprovalPreview &&
        fallbackTotalKopecks != null &&
        fallbackTotalKopecks! > 0;
    final dmPay = order.effectiveDurationMinutes > 0 ? order.effectiveDurationMinutes : 60;
    final hourlyPay = formatEquivalentHourlyRateLine(totalK, dmPay);

    return _SectionCard(
      title: 'Итог к оплате',
      child: Column(
        children: [
          if (!useFallbackTotal && mainKopecks > 0)
            _pricingRow('Базовая стоимость', mainKopecks, false),
          if (!useFallbackTotal && addKopecks > 0) ...[
            if (mainKopecks > 0) const SizedBox(height: 6),
            _pricingRow('Доп. работы', addKopecks, true),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColorsDesktop.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Итого',
                style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 14),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(totalK),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColorsDesktop.accentMoney,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'на ${formatDurationMinutes(dmPay)}',
                    style: DesktopDesignSystem.meta.copyWith(fontSize: 11),
                  ),
                  if (hourlyPay != null)
                    Text(
                      hourlyPay,
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 11, color: AppColorsDesktop.textTertiary),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, int kopecks, bool isAdditional) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: DesktopDesignSystem.bodySecondary.copyWith(
            color: isAdditional ? AppColorsDesktop.statusApproval : AppColorsDesktop.textSecondary,
          ),
        ),
        Text(
          formatMoney(kopecks),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isAdditional ? FontWeight.w600 : FontWeight.w500,
            color: isAdditional ? AppColorsDesktop.statusApproval : AppColorsDesktop.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Блок 9: История (создан / обновлён).
class OrderTimelineCard extends StatelessWidget {
  const OrderTimelineCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final events = <Widget>[];
    if (order.createdAt != null) {
      events.add(_timelineItem(Icons.add_circle_outline_rounded, 'Заказ создан', order.createdAt!));
    }
    if (order.updatedAt != null && order.updatedAt != order.createdAt) {
      events.add(_timelineItem(Icons.edit_rounded, 'Обновлён', order.updatedAt!));
    }
    if (events.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'История заказа',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: events,
      ),
    );
  }

  Widget _timelineItem(IconData icon, String text, DateTime at) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColorsDesktop.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 13)),
                Text(
                  formatDateTime(at),
                  style: DesktopDesignSystem.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Стили кнопок блока «Действия»: primary и вторичные на всю ширину, danger — красный.
final _primaryBtnStyle = FilledButton.styleFrom(
  backgroundColor: AppColorsDesktop.textPrimary,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  minimumSize: const Size(double.infinity, 44),
  elevation: 0,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
);
final _secondaryBtnStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColorsDesktop.textSecondary,
  side: const BorderSide(color: AppColorsDesktop.border),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  minimumSize: const Size(double.infinity, 40),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
);
final _secondaryOrangeBtnStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColorsDesktop.statusApproval,
  side: const BorderSide(color: AppColorsDesktop.statusApproval),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  minimumSize: const Size(double.infinity, 40),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
);
final _dangerBtnStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColorsDesktop.statusCancelled,
  side: const BorderSide(color: AppColorsDesktop.statusCancelled),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  minimumSize: const Size(double.infinity, 40),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
);

/// Блок 10: Действия — один primary, вторичные outlined, danger отдельно (современный desktop).
class OrderActionsBar extends ConsumerWidget {
  const OrderActionsBar({
    super.key,
    required this.orderId,
    required this.order,
    required this.canAssignMaster,
    required this.onClosed,
    this.onOpenComposeOverlay,
  });

  final String orderId;
  final Order order;
  final bool canAssignMaster;
  final VoidCallback onClosed;
  /// Открыть окно «Изменить состав» (то же, что в диалоге чата). Передаётся из панели.
  final Future<void> Function()? onOpenComposeOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(orderRepositoryProvider.notifier);

    void showMessage(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColorsDesktop.surface),
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
        onClosed();
      } else {
        showMessage(result.errorOrNull!.message);
      }
    }

    Future<void> openChat() async {
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
    }

    /// Показывать «Изменить состав» на всех стадиях, кроме «Завершён» и «Отменён».
    final canChangeComposition = order.status != OrderStatus.done && order.status != OrderStatus.cancelled;

    Widget? primaryButton;
    final secondaryButtons = <Widget>[];

    if (canChangeComposition && order.status != OrderStatus.pendingConfirmation) {
      secondaryButtons.add(
        OutlinedButton.icon(
          onPressed: () async {
            await onOpenComposeOverlay!();
            if (context.mounted) showMessage('Перечень работ отправлен клиенту');
          },
          style: _secondaryBtnStyle,
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('Изменить состав заказа'),
        ),
      );
    }

    if (order.status == OrderStatus.pendingConfirmation) {
      primaryButton = FilledButton(
        onPressed: () async {
          await onOpenComposeOverlay?.call();
          if (context.mounted) showMessage('Перечень работ отправлен клиенту');
        },
        style: _primaryBtnStyle,
        child: const Text('Изменить состав заказа'),
      );
      secondaryButtons.add(
        OutlinedButton(
          onPressed: () => setStatus(OrderStatus.confirmed, 'Заказ подтверждён без изменений'),
          style: _secondaryBtnStyle,
          child: const Text('Подтвердить без изменений'),
        ),
      );
    }

    if (order.status == OrderStatus.confirmed) {
      primaryButton = FilledButton(
        onPressed: () => setStatus(OrderStatus.inProgress, 'Статус: В работе'),
        style: _primaryBtnStyle,
        child: const Text('В работу'),
      );
      if (canAssignMaster) {
        final hasMaster = order.masterName != null && order.masterName!.isNotEmpty;
        secondaryButtons.add(
          OutlinedButton(
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => MasterPickerScreen(orderId: orderId)),
              );
            },
            style: hasMaster ? _secondaryBtnStyle : _secondaryOrangeBtnStyle,
            child: Text(hasMaster ? 'Сменить мастера' : 'Назначить мастера'),
          ),
        );
      }
    }

    if (order.status == OrderStatus.inProgress) {
      primaryButton = FilledButton(
        onPressed: () => setStatus(OrderStatus.completed, 'Готово к выдаче'),
        style: _primaryBtnStyle,
        child: const Text('Завершить работы'),
      );
    }

    // Одна кнопка «Открыть чат» — переход в общий чат с клиентом
    if (order.status.isActive) {
      secondaryButtons.add(
        OutlinedButton.icon(
          onPressed: () => openChat(),
          style: _secondaryBtnStyle,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Открыть чат'),
        ),
      );
    }

    if (order.status == OrderStatus.pendingApproval) {
      primaryButton = FilledButton(
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
        style: _primaryBtnStyle,
        child: const Text('Подтвердить по телефону'),
      );
    }

    if (order.status == OrderStatus.completed) {
      primaryButton = FilledButton(
        onPressed: () async {
          final closed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => OrderPaymentScreen(orderId: orderId)),
          );
          if (closed == true && context.mounted) onClosed();
        },
        style: _primaryBtnStyle,
        child: const Text('Оплата / Выдать заказ'),
      );
    }

    Widget? dangerButton;
    if (order.status.isActive) {
      dangerButton = OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Отменить заказ?'),
              content: const Text('Заказ будет отменён. Эту операцию нельзя отменить.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColorsDesktop.textPrimary),
                  child: const Text('Отменить заказ'),
                ),
              ],
            ),
          );
          if (confirm == true) await cancel();
        },
        style: _dangerBtnStyle,
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Отменить заказ'),
      );
    }

    final dangerBtn = dangerButton;
    return _SectionCard(
      title: 'Действия',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primaryButton != null) ...[
            primaryButton,
            const SizedBox(height: 12),
          ],
          if (secondaryButtons.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: secondaryButtons,
            ),
          if (dangerBtn != null) ...[
            const SizedBox(height: 14),
            dangerBtn,
          ],
        ],
      ),
    );
  }
}

/// Главная панель деталей заказа (desktop): скроллируемый контент с секциями.
/// [fallbackItems], [fallbackTotalKopecks], [fallbackTotalMinutes] — при пустом заказе (создан через запрос согласования) показываем состав и итог из сообщения.
class OrderDetailPanel extends ConsumerStatefulWidget {
  const OrderDetailPanel({
    super.key,
    required this.orderId,
    this.onClose,
    this.fallbackItems,
    this.fallbackTotalKopecks,
    this.fallbackTotalMinutes,
    this.scrollToClientWhenOpen = false,
    this.onScrollToClientDone,
  });

  final String orderId;
  final VoidCallback? onClose;
  final List<ApprovalItem>? fallbackItems;
  final int? fallbackTotalKopecks;
  final int? fallbackTotalMinutes;
  /// При true после открытия панели прокрутить к блоку «Клиент» и подсветить строку клиента.
  final bool scrollToClientWhenOpen;
  final VoidCallback? onScrollToClientDone;

  @override
  ConsumerState<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends ConsumerState<OrderDetailPanel> {
  final GlobalKey _summaryClientKey = GlobalKey();
  List<ApprovalItem>? _loadedFallbackItems;
  int? _loadedFallbackTotalKopecks;
  int? _loadedFallbackTotalMinutes;
  bool _showChatOverlay = false;
  String? _overlayChatId;
  bool _highlightClientRow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderRepositoryProvider.notifier).refreshOrder(widget.orderId);
    });
    if (widget.fallbackItems == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFallbackFromChatIfNeeded());
    }
    if (widget.scrollToClientWhenOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToClientAndHighlight());
      });
    }
  }

  void _scrollToClientAndHighlight() {
    if (!mounted) return;
    setState(() => _highlightClientRow = true);
    final ctx = _summaryClientKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
    widget.onScrollToClientDone?.call();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightClientRow = false);
    });
  }

  @override
  void didUpdateWidget(covariant OrderDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
      if (oldWidget.orderId != widget.orderId) {
      setState(() {
        _loadedFallbackItems = null;
        _loadedFallbackTotalKopecks = null;
        _loadedFallbackTotalMinutes = null;
        _showChatOverlay = false;
        _overlayChatId = null;
        _highlightClientRow = false;
      });
      if (widget.fallbackItems == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadFallbackFromChatIfNeeded());
      }
    }
  }

  Future<void> _loadFallbackFromChatIfNeeded() async {
    if (widget.fallbackItems != null) return;
    final order = ref.read(orderByIdProvider(widget.orderId));
    if (order == null || order.items.isNotEmpty) return;
    final orderApi = ref.read(orderApiServiceProvider);
    final chatRes = await orderApi.getChatForOrder(widget.orderId);
    final chatId = chatRes.dataOrNull;
    if (chatId == null || chatId.isEmpty || !mounted) return;
    await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(chatId);
    if (!mounted) return;
    final chatState = ref.read(chatRepositoryProvider);
    final messages = (chatState.messages[chatId] ?? [])..sort((a, b) => a.at.compareTo(b.at));
    ChatMessage? latest;
    for (final m in messages) {
      if (!m.isApprovalCard || m.orderId != widget.orderId) continue;
      if (latest == null || m.at.isAfter(latest.at)) latest = m;
    }
    if (latest == null || !mounted) return;
    final msg = latest;
    final approvalItems = _itemsFromApprovalMessage(msg);
    if (approvalItems.isEmpty) return;
    final orderItems = approvalItems.asMap().entries.map((e) {
      final a = e.value;
      return OrderItem(
        id: a.id ?? 'fb_${e.key}_${a.name.hashCode.abs()}',
        name: a.name,
        priceKopecks: a.priceKopecks,
        estimatedMinutes: a.estimatedMinutes,
        isCompleted: false,
        isAdditional: false,
      );
    }).toList();
    ref.read(orderRepositoryProvider.notifier).setOrderItemsIfEmpty(widget.orderId, orderItems);
    if (!mounted) return;
    final totalKopecks = msg.totalsAfterPriceKopecks ?? msg.approvalTotalKopecks;
    final totalMinutes = msg.totalsAfterMinutes ?? msg.approvalTotalMinutes;
    setState(() {
      _loadedFallbackTotalKopecks = totalKopecks;
      _loadedFallbackTotalMinutes = totalMinutes;
    });
  }

  Future<void> _showEditTimeDialog(BuildContext context, Order order) async {
    final startRaw = order.plannedStartTime ?? order.effectiveDateTime;
    final endRaw = order.plannedEndTime ??
        order.effectiveDateTime.add(Duration(minutes: order.estimatedMinutesForDisplay > 0 ? order.estimatedMinutesForDisplay : 60));
    var start = startRaw.isUtc ? startRaw.toLocal() : startRaw;
    var end = endRaw.isUtc ? endRaw.toLocal() : endRaw;
    final baseDate = DateTime(start.year, start.month, start.day);

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
    final res = await ref.read(orderRepositoryProvider.notifier).updateOrderTime(widget.orderId, plannedStartTime: start, plannedEndTime: end);
    if (!context.mounted) return;
    res.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Время обновлено'))),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColorsDesktop.error)),
    );
  }

  /// Открыть «Изменить состав»: на desktop — диалог-оверлей, на мобильном — переход на полный экран.
  Future<void> _openComposeOverlay() async {
    final orderApi = ref.read(orderApiServiceProvider);
    final chatResult = await orderApi.getChatForOrder(widget.orderId);
    if (!context.mounted) return;
    final chatId = chatResult.dataOrNull;
    if (chatId == null || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(chatResult.errorOrNull?.message ?? 'Чат по заказу не найден'),
        backgroundColor: AppColorsDesktop.error,
      ));
      return;
    }
    if (!isDesktopPlatform) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmCorrectOrderScreen(
            orderId: widget.orderId,
            chatId: chatId,
          ),
        ),
      );
    } else {
      const radius = 20.0;
      const maxW = 420.0;
      final maxH = MediaQuery.sizeOf(context).height * 0.88;
      await showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(radius),
          color: Colors.transparent,
          child: Container(
            width: maxW,
            height: maxH,
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColorsDesktop.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ConfirmCorrectOrderScreen(
              orderId: widget.orderId,
              chatId: chatId,
              embeddedInDialog: true,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    }
    if (mounted) ref.read(orderRepositoryProvider.notifier).refreshOrder(widget.orderId);
  }

  /// Открывает чат с клиентом поверх карточки заказа (оверлей той же ширины, выезжает справа).
  void _openChat(BuildContext context) async {
    final orderApi = ref.read(orderApiServiceProvider);
    final chatResult = await orderApi.getChatForOrder(widget.orderId);
    if (!context.mounted) return;
    final chatId = chatResult.dataOrNull;
    if (chatId == null || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(chatResult.errorOrNull?.message ?? 'Чат не найден'),
        backgroundColor: AppColorsDesktop.error,
      ));
      return;
    }
    await ensureChatDataLoaded(ref, chatId, refValid: () => mounted);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _overlayChatId = chatId;
        _showChatOverlay = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    final canAssignMaster = ref.watch(authProvider).user?.role.canAssignMaster ?? false;

    if (order == null) {
      return Container(
        width: kOrderDetailPanelWidth,
        decoration: const BoxDecoration(
          color: AppColorsDesktop.surface,
          border: Border(left: BorderSide(color: AppColorsDesktop.border)),
        ),
        child: const Center(
          child: Text('Заказ не найден', style: TextStyle(color: AppColorsDesktop.textSecondary)),
        ),
      );
    }

    final canChangeComposition = order.status != OrderStatus.done && order.status != OrderStatus.cancelled;
    final clientAvatarUrl = resolvedClientAvatarUrl(
      chats: ref.watch(chatRepositoryProvider).chats,
      orderClientAvatarUrl: order.clientAvatarUrl,
      clientPhone: order.clientPhone,
    );

    return Container(
      width: kOrderDetailPanelWidth,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.background,
        border: Border(left: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                color: AppColorsDesktop.background,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: OrderDetailHeader(
                  order: order,
                  onChat: () => _openChat(context),
                  onMoreSelected: (value) {
                    if (value == null || !context.mounted) return;
                    if (value == 'pdf') {
                      printOrderWorksheet(context, order, showPrices: canSeePrices);
                    }
                    if (value == 'chat') _openChat(context);
                    if (value == 'compose' && canChangeComposition) {
                      _openComposeOverlay();
                    }
                    if (value == 'time' && canAssignMaster && order.status.isActive) _showEditTimeDialog(context, order);
                  },
                  onClose: widget.onClose,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: kOrderDetailPanelWidth - 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  RepaintBoundary(
                    key: _summaryClientKey,
                    child: OrderSummaryCard(
                      order: order,
                      canSeePrices: canSeePrices,
                      clientAvatarUrl: clientAvatarUrl,
                      fallbackTotalKopecks: widget.fallbackTotalKopecks ?? _loadedFallbackTotalKopecks,
                      fallbackDurationMin: widget.fallbackTotalMinutes ?? _loadedFallbackTotalMinutes,
                      clientSectionHighlighted: _highlightClientRow,
                      onClientCall: order.clientPhone != null && order.clientPhone!.trim().isNotEmpty
                          ? () => launchUrl(Uri(scheme: 'tel', path: order.clientPhone!.replaceAll(RegExp(r'[^\d+]'), '')))
                          : null,
                      onClientChat: () => _openChat(context),
                      onClientCopyPhone: order.clientPhone != null && order.clientPhone!.trim().isNotEmpty
                          ? () => _copyToClipboard(context, order.clientPhone!)
                          : null,
                    ),
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  OrderVehicleCard(order: order),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  OrderServicesCard(
                    order: order,
                    canSeePrices: canSeePrices,
                    fallbackItems: widget.fallbackItems ?? _loadedFallbackItems,
                    onToggleItemComplete: order.status.isActive && order.status != OrderStatus.pendingApproval
                        ? (item) async {
                            final notifier = ref.read(orderRepositoryProvider.notifier);
                            final result = item.isCompleted
                                ? await notifier.uncompleteOrderItem(widget.orderId, item.id)
                                : await notifier.completeOrderItem(widget.orderId, item.id);
                            if (!context.mounted) return;
                            if (result.errorOrNull != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.errorOrNull!.message), backgroundColor: AppColorsDesktop.error),
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  OrderScheduleCard(
                    order: order,
                    onEditTime: canAssignMaster && order.status.isActive ? () => _showEditTimeDialog(context, order) : null,
                    canAssignMaster: canAssignMaster,
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  OrderMasterCard(
                    order: order,
                    onAssignMaster: canAssignMaster && order.status.isActive
                        ? () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => MasterPickerScreen(orderId: widget.orderId)),
                            );
                          }
                        : null,
                    canAssignMaster: canAssignMaster,
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  OrderTimelineCard(order: order),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  OrderActionsBar(
                    orderId: widget.orderId,
                    order: order,
                    canAssignMaster: canAssignMaster,
                    onClosed: widget.onClose ?? () {},
                    onOpenComposeOverlay: _openComposeOverlay,
                  ),
                ],
                ),
              ),
            ),
          ),
        ],
          ),
          if (_showChatOverlay && _overlayChatId != null)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_overlayChatId),
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(value * kOrderDetailPanelWidth, 0),
                  child: child,
                ),
                child: Material(
                  color: AppColorsDesktop.background,
                  elevation: 0,
                  child: ChatDetailScreen(
                    chatId: _overlayChatId!,
                    currentOrderId: widget.orderId,
                    embeddedInSplit: true,
                    onBack: () => setState(() {
                      _showChatOverlay = false;
                      _overlayChatId = null;
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    // ignore: deprecated_member_use
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Номер скопирован'), duration: Duration(seconds: 1)),
    );
  }
}
