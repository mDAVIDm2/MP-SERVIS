import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_aggregate.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../orders/presentation/widgets/order_detail_panel.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';

/// Правая панель с деталями автомобиля: данные, аналитика, действия (звонок, чат).
class CarDetailPanel extends ConsumerStatefulWidget {
  const CarDetailPanel({
    super.key,
    required this.car,
    required this.onClose,
    this.canSeePrices = true,
  });

  final CarView car;
  final VoidCallback onClose;
  final bool canSeePrices;

  @override
  ConsumerState<CarDetailPanel> createState() => _CarDetailPanelState();
}

class _CarDetailPanelState extends ConsumerState<CarDetailPanel> {
  bool _showChatOverlay = false;
  String? _overlayChatId;
  String? _overlayOrderId;

  Future<void> _openChat() async {
    final orderId = widget.car.lastOrder?.id;
    if (orderId == null) return;
    final orderApi = ref.read(orderApiServiceProvider);
    final res = await orderApi.getChatForOrder(orderId);
    final chatId = res.dataOrNull;
    if (chatId == null || chatId.isEmpty || !mounted) return;
    await ensureChatDataLoaded(ref, chatId, refValid: () => mounted);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showChatOverlay = true;
        _overlayChatId = chatId;
        _overlayOrderId = orderId;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    return Container(
      width: kOrderDetailPanelWidth,
      decoration: const BoxDecoration(
        color: AppColorsDesktop.background,
        border: Border(left: BorderSide(color: AppColorsDesktop.border)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCarInfo(car),
                      const SizedBox(height: DesktopDesignSystem.blockSpacing),
                      _buildAnalytics(car),
                      const SizedBox(height: DesktopDesignSystem.blockSpacing),
                      _buildActions(context, car),
                    ],
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
                    currentOrderId: _overlayOrderId,
                    embeddedInSplit: true,
                    onBack: () => setState(() {
                      _showChatOverlay = false;
                      _overlayChatId = null;
                      _overlayOrderId = null;
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopDesignSystem.cardPadding,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColorsDesktop.surface,
        border: Border(bottom: BorderSide(color: AppColorsDesktop.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car_rounded, size: 22, color: AppColorsDesktop.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Автомобиль',
              style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: widget.onClose,
            style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
            tooltip: 'Закрыть',
          ),
        ],
      ),
    );
  }

  Widget _buildCarInfo(CarView car) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColorsDesktop.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car_rounded, color: AppColorsDesktop.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.carInfo,
                      style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (car.licensePlate != null && car.licensePlate!.isNotEmpty)
                      _copyableRow(context, 'Гос. номер', car.licensePlate!),
                    if (car.vin != null && car.vin!.isNotEmpty)
                      _copyableRow(context, 'VIN', car.vin!),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _infoRow('Владелец', car.clientName ?? '—'),
          if (car.clientPhone != null && car.clientPhone!.isNotEmpty)
            _infoRow('Телефон', car.clientPhone!),
          if (car.bodyType != null && car.bodyType!.isNotEmpty)
            _infoRow('Тип кузова', car.bodyType!),
          if (car.color != null && car.color!.isNotEmpty)
            _infoRow('Цвет', car.color!),
          if (car.mileage != null && car.mileage! > 0)
            _infoRow('Пробег', '${car.mileage} км'),
          if (car.engineType != null && car.engineType!.isNotEmpty)
            _infoRow('Двигатель', car.engineType!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: DesktopDesignSystem.meta.copyWith(fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: DesktopDesignSystem.body.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  static Widget _copyableRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$label: ', style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 13)),
          Expanded(
            child: Text(value, style: DesktopDesignSystem.body.copyWith(fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label скопирован'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.fixed),
              );
            },
            tooltip: 'Копировать',
            style: IconButton.styleFrom(
              foregroundColor: AppColorsDesktop.textSecondary,
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(CarView car) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Аналитика по автомобилю',
            style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 14),
          _analyticsRow('Всего заказов', '${car.orderCount}', null),
          _analyticsRow('Выполнено', '${car.completedCount}', AppColorsDesktop.statusDone),
          _analyticsRow('В работе / ожидании', '${car.pendingCount}', AppColorsDesktop.statusInProgress),
          _analyticsRow('Отменено', '${car.cancelledCount}', AppColorsDesktop.statusCancelled),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (widget.canSeePrices && car.totalKopecks > 0) ...[
            _analyticsRow('Сумма обслуживаний', formatMoney(car.totalKopecks), AppColorsDesktop.accentMoney),
            if (car.additionalKopecks > 0)
              _analyticsRow('В т.ч. доп. работы', formatMoney(car.additionalKopecks), AppColorsDesktop.statusApproval),
          ],
          if (car.lastOrderDate != null)
            _analyticsRow('Последнее обращение', formatDate(car.lastOrderDate!), null),
          if (car.nextVisit != null) ...[
            const SizedBox(height: 6),
            _analyticsRow(
              'Ближайшая запись',
              '${formatDateShort(car.nextVisit!.plannedStartTime ?? car.nextVisit!.dateTime ?? car.nextVisit!.effectiveDateTime)} · ${car.nextVisit!.orderNumber}',
              AppColorsDesktop.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _analyticsRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColorsDesktop.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, CarView car) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Действия',
            style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (car.clientPhone != null && car.clientPhone!.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                final uri = Uri(
                  scheme: 'tel',
                  path: car.clientPhone!.replaceAll(RegExp(r'[^\d+]'), ''),
                );
                launchUrl(uri);
              },
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: const Text('Позвонить клиенту'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColorsDesktop.primary,
                side: const BorderSide(color: AppColorsDesktop.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          if (car.clientPhone != null && car.clientPhone!.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: car.lastOrder != null ? _openChat : null,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Открыть чат с клиентом'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColorsDesktop.primary,
              side: const BorderSide(color: AppColorsDesktop.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
