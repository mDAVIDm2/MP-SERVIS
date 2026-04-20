import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/pdf/order_worksheet_pdf.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/driving_route_launcher.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/catalog/client_catalog_service_ids.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/org_business_kind.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import '../widgets/order_avatars.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  /// Вызов построения маршрута до точки (используется из OrderCard и др.).
  static Future<void> openRouteToSto(BuildContext context, WidgetRef ref, STO sto) async {
    await _openRouteToStoImpl(context, ref, sto);
  }

  static Future<void> _openRouteToStoImpl(BuildContext context, WidgetRef ref, STO? sto) async {
    if (sto == null || sto.latitude == null || sto.longitude == null) {
      if (context.mounted) {
        final l10n = L10nScope.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.orderStoNotOnMap),
            backgroundColor: context.palette.warning,
          ),
        );
      }
      return;
    }
    final position = await tryCurrentUserPositionForRoute();
    if (!context.mounted) return;
    await launchDrivingRoute(
      context,
      ref,
      destLat: sto.latitude!,
      destLng: sto.longitude!,
      destinationTitle: sto.name,
      userPosition: position,
    );
  }

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _invalidated = false;

  /// Открыть чат по заказу: GET /orders/:orderId/chat → chat_id, затем открыть тот же chatId, куда Business пишет approval.
  Future<void> _openChat(BuildContext context, WidgetRef ref, Order order) async {
    final orderApi = ref.read(orderApiServiceProvider);
    final chatIdResult = await orderApi.getChatIdForOrder(order.id);
    final resolvedChatId = chatIdResult.dataOrNull;
    if (resolvedChatId == null || resolvedChatId.isEmpty) {
      if (context.mounted) {
        final l10n = L10nScope.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(() {
            final e = chatIdResult.errorOrNull;
            if (e == null) return l10n.chatByOrderNotFound;
            return e.message.toString();
          }()),
          backgroundColor: context.palette.error,
        ));
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[open_chat_from_order] orderId=${order.id}, resolvedChatId=$resolvedChatId, stoId=${order.stoId}');
    }
    await ref.read(chatsProvider.notifier).loadChats();
    if (!context.mounted) return;
    final chats = ref.read(chatsProvider).valueOrNull ?? [];
    Chat? chat;
    for (final c in chats) {
      if (c.id == resolvedChatId) {
        chat = c;
        break;
      }
    }
    // Не создаём stub: при отсутствии чата в списке запрашиваем GET /chats/:id (реальный чат с историей).
    if (chat == null) {
      final oneResult = await ref.read(chatsProvider.notifier).getChatById(resolvedChatId);
      chat = oneResult.dataOrNull;
      if (chat == null) {
        if (context.mounted) {
          final l10n = L10nScope.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(() {
              final e = oneResult.errorOrNull;
              if (e == null) return l10n.openChatFailed;
              return e.message.toString();
            }()),
            backgroundColor: context.palette.error,
          ));
        }
        return;
      }
    }
    if (context.mounted) {
      pushCupertino(context, ChatDetailScreen(chat: chat, currentOrderId: order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_invalidated) {
      _invalidated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(orderByIdProvider(widget.order.id));
      });
    }
    final orderAsync = ref.watch(orderByIdProvider(widget.order.id));
    final displayOrder = orderAsync.valueOrNull ?? widget.order;
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final car = cars.isEmpty
        ? Car(id: displayOrder.carId, brand: '—', model: '', year: 0, mileage: 0)
        : cars.firstWhere(
            (c) => c.id == displayOrder.carId,
            orElse: () => cars.first,
          );
    final l10n = L10nScope.of(context);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: context.palette.background,
            pinned: true,
            title: Text(l10n.orderDetailTitle(displayOrder.orderNumber),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                onPressed: () => printOrderWorksheet(context, displayOrder, car: car.id == displayOrder.carId ? car : null),
                icon: Icon(Icons.picture_as_pdf_outlined, size: 22),
                tooltip: l10n.orderWorksheetPdfTooltip,
              ),
              IconButton(
                onPressed: () => _openChat(context, ref, displayOrder),
                icon: Icon(Icons.chat_bubble_outline_rounded, size: 22),
                tooltip: l10n.orderOpenChatTooltip,
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildContent(context, ref, car, displayOrder)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Car car, Order order) {
    final l10n = L10nScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(context, order, l10n),
          SizedBox(height: 16),

          if (order.status == OrderStatus.pendingApproval)
            _buildApprovalBanner(context, ref, order, l10n),

          _buildSection(context, l10n.orderSectionVehicle, child: _buildCarInfo(context, car, order, l10n)),
          SizedBox(height: 12),

          _buildSection(context, l10n.orderSectionService, child: _buildSTOInfo(context, ref, order, l10n)),
          SizedBox(height: 12),

          _buildSection(context, l10n.orderSectionDateTime, child: _buildDateTime(context, order, l10n)),
          SizedBox(height: 12),

          // Состав: при pending_approval — черновик из approval_preview (см. Order.itemsForDisplay).
          _buildSection(context, l10n.orderSectionWorks, child: _buildWorkItems(order)),

          if (order.itemsForDisplay.any((i) => i.isAdditional)) ...[
            SizedBox(height: 12),
            _buildSection(
              context,
              order.status == OrderStatus.pendingApproval
                  ? l10n.orderAdditionalPending
                  : l10n.orderAdditionalAfterApproval,
              child: _buildAdditionalItems(order),
            ),
          ],

          SizedBox(height: 12),

          // Общее время
          _buildTimeEstimate(context, order, l10n),
          SizedBox(height: 12),

          _buildTotalSection(context, order, l10n),
          SizedBox(height: 12),

          _buildPhotosSection(context, l10n),
          SizedBox(height: 12),

          if (order.comment != null && order.comment!.isNotEmpty) ...[
            _buildSection(context, l10n.orderSectionComment, child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('"${order.comment}"', style: TextStyle(
                fontSize: 14, color: context.palette.textSecondary, fontStyle: FontStyle.italic,
              )),
            )),
            SizedBox(height: 12),
          ],

          _buildActions(context, ref, order, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, Order order, AppL10n l10n) {
    final steps = [
      l10n.orderStepBooked,
      l10n.orderStepConfirmed,
      l10n.orderStepInProgress,
      l10n.orderStepReady,
      l10n.orderStepDone,
    ];
    final currentStep = _statusStep(order);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: order.status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: order.status.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: order.displayStatus.color, shape: BoxShape.circle),
              ),
              SizedBox(width: 8),
              Text(order.displayStatus.label.toUpperCase(), style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: order.displayStatus.color, letterSpacing: 0.5,
              )),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.displayStatus.progress,
              minHeight: 6,
              backgroundColor: context.palette.nestedBg,
              valueColor: AlwaysStoppedAnimation(order.displayStatus.color),
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length, (i) {
                final isCompleted = i < currentStep;
                final isCurrent = i == currentStep;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 1,
                      right: i == steps.length - 1 ? 0 : 1,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? context.palette.success
                                  : isCurrent ? order.status.color : context.palette.nestedBg,
                              border: Border.all(
                                color: isCompleted || isCurrent ? Colors.transparent : context.palette.border,
                              ),
                            ),
                            child: isCompleted
                                ? Icon(Icons.check, size: 12, color: Colors.white)
                                : isCurrent
                                    ? Container(
                                        margin: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                        SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              steps[i],
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.0,
                                color: isCompleted || isCurrent ? context.palette.textPrimary : context.palette.textTertiary,
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  int _statusStep(Order order) {
    switch (order.status) {
      case OrderStatus.pendingConfirmation: return 0;
      case OrderStatus.confirmed: return 1;
      case OrderStatus.inProgress: return 2;
      case OrderStatus.pendingApproval: return 2;
      case OrderStatus.completed: return 3;
      case OrderStatus.done: return 4;
      case OrderStatus.cancelled: return 0;
    }
  }

  Widget _buildApprovalBanner(BuildContext context, WidgetRef ref, Order order, AppL10n l10n) {
    return GestureDetector(
      onTap: () => _openChat(context, ref, order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.statusApproval.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.statusApproval.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text('⚠️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.orderApprovalExtraTitle,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: context.palette.statusApproval)),
                  const SizedBox(height: 2),
                  Text(l10n.orderApprovalExtraSubtitle,
                    style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: context.palette.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l10n.orderGoToChat, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.onAccent,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textSecondary,
        )),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.palette.border),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildCarInfo(BuildContext context, Car car, Order order, AppL10n l10n) {
    final photoRaw = resolveCarPhotoRawForOrder(order, car);
    final thumbRadius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OrderCarAvatar(
            rawPhoto: photoRaw,
            size: 64,
            borderRadius: thumbRadius,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${car.brand} ${car.model}, ${car.year}', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                )),
                SizedBox(height: 2),
                Text(
                  '${car.plateNumber ?? ''} | ${Formatters.mileageLocalized(car.mileage, l10n.intlLocale)}',
                  style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSTOInfo(BuildContext context, WidgetRef ref, Order order, AppL10n l10n) {
    final phones = order.stoPhone != null ? [order.stoPhone!] : <String>[];
    final stoAsync = ref.watch(stoByIdProvider(order.stoId));
    final sto = stoAsync.valueOrNull;
    final logoUrl = resolveOrganizationLogoUrl(sto);
    final thumbRadius = BorderRadius.circular(12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: sto != null
            ? () => pushStoDetailScreen(context, STODetailScreen(sto: sto))
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              OrderOrganizationAvatar(
                imageUrl: logoUrl,
                name: order.stoName,
                size: 64,
                borderRadius: thumbRadius,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.stoName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (order.stoAddress != null) ...[
                      SizedBox(height: 2),
                      Text(
                        order.stoAddress!,
                        style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                      ),
                    ],
                    if (OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind, english: l10n.isEn).isNotEmpty ||
                        OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode, english: l10n.isEn).isNotEmpty) ...[
                      SizedBox(height: 6),
                      if (OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind, english: l10n.isEn).isNotEmpty)
                        Text(
                          OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind, english: l10n.isEn),
                          style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                        ),
                      if (OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode, english: l10n.isEn).isNotEmpty) ...[
                        if (OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind, english: l10n.isEn).isNotEmpty)
                          SizedBox(height: 2),
                        Text(
                          l10n.bookingWithMode(OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode, english: l10n.isEn)),
                          style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
                        ),
                      ],
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _SmallAction(
                          icon: Icons.phone_rounded,
                          label: l10n.callService,
                          onTap: () => _openPhone(context, phones),
                        ),
                        SizedBox(width: 12),
                        _SmallAction(
                          icon: Icons.directions_rounded,
                          label: l10n.directionsToService,
                          onTap: () => OrderDetailScreen._openRouteToStoImpl(context, ref, sto),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openPhone(BuildContext context, List<String> phones) async {
    final l10n = L10nScope.of(context);
    if (phones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.phoneNotListed), backgroundColor: context.palette.warning),
        );
      }
      return;
    }
    if (phones.length == 1) {
      await launchUrl(
        Uri.parse('tel:${phones.first.replaceAll(RegExp(r'[\s\(\)\-]'), '')}'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if (!context.mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text(l10n.pickPhoneNumber, style: TextStyle(color: context.palette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: phones
              .map((n) => ListTile(
                    title: Text(Formatters.phone(n), style: TextStyle(color: context.palette.textPrimary)),
                    onTap: () => Navigator.pop(ctx, n),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await launchUrl(
        Uri.parse('tel:${selected.replaceAll(RegExp(r'[\s\(\)\-]'), '')}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget _buildDateTime(BuildContext context, Order order, AppL10n l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 20, color: context.palette.primary),
              SizedBox(width: 12),
              Text(
                '${Formatters.dateFullLocalized(order.dateTime, l10n.intlLocale)}, ${Formatters.time(order.dateTime)}',
                style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
              ),
            ],
          ),
          if (order.status.isActive && order.plannedEndTime != null) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: context.palette.textSecondary),
                SizedBox(width: 10),
                Text(
                  l10n.orderEstimatedEnd(Formatters.time(order.plannedEndTime!)),
                  style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkItems(Order order) {
    final regular = order.itemsForDisplay.where((i) => !i.isAdditional).toList();
    return Column(
      children: regular.map((item) => _WorkItemRow(item: item)).toList(),
    );
  }

  Widget _buildAdditionalItems(Order order) {
    final additional = order.itemsForDisplay.where((i) => i.isAdditional).toList();
    return Column(
      children: additional.map((item) => _WorkItemRow(item: item, isAdditional: true)).toList(),
    );
  }

  /// Блок с оценкой общего времени
  Widget _buildTimeEstimate(BuildContext context, Order order, AppL10n l10n) {
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
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: context.palette.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.schedule_rounded, size: 22, color: context.palette.info),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.orderExpectedTimeLabel, style: TextStyle(
                  fontSize: 12, color: context.palette.textSecondary,
                )),
                SizedBox(height: 2),
                Text(order.displayDurationLabel, style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
                )),
              ],
            ),
          ),
          // Прогресс выполнения работ
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.hasApprovalPreview
                    ? '0/${order.itemsForDisplay.length}'
                    : '${order.completedCount}/${order.totalCount}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              Text(l10n.orderJobsDoneLabel, style: TextStyle(
                fontSize: 11, color: context.palette.textTertiary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context, Order order, AppL10n l10n) {
    final disp = order.itemsForDisplay;
    final workTotal = disp.where((i) => !i.isAdditional).fold(0, (sum, i) => sum + i.priceKopecks);
    final addTotal = disp.where((i) => i.isAdditional).fold(0, (sum, i) => sum + i.priceKopecks);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.palette.cardBg, context.palette.primary.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _TotalRow(l10n.orderSubtotalWorks, Formatters.money(workTotal)),
          if (addTotal > 0)
            _TotalRow(l10n.orderSubtotalAdditional, Formatters.money(addTotal)),
          Divider(color: context.palette.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.orderGrandTotal, style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
              )),
              Text(Formatters.money(order.totalKopecksForDisplay), style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: context.palette.primary, fontFamily: 'monospace',
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(BuildContext context, AppL10n l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.orderWorkPhotos, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textSecondary,
        )),
        SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(width: 8),
            itemBuilder: (_, i) => Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.palette.border),
              ),
              child: Icon(Icons.photo_camera_rounded, color: context.palette.textTertiary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, Order order, AppL10n l10n) {
    return Column(
      children: [
        if (order.status == OrderStatus.pendingApproval)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GoldButton(text: l10n.orderGoToApproval,
              onPressed: () => _openChat(context, ref, order)),
          ),
        if (order.status == OrderStatus.done) ...[
          GoldButton(text: l10n.orderLeaveReview, onPressed: () {}),
          SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: () => _repeatOrder(context, ref, order),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(color: context.palette.primary),
          ),
          child: Text(l10n.orderRepeat),
        ),
        if (_canClientCancelOrder(order)) ...[
          SizedBox(height: 8),
          TextButton(
            onPressed: () => _showCancelDialog(context, ref, order),
            child: Text(l10n.orderCancelBooking, style: TextStyle(
              fontSize: 14, color: context.palette.error,
            )),
          ),
        ],
      ],
    );
  }

  bool _canClientCancelOrder(Order order) {
    return order.status == OrderStatus.pendingConfirmation ||
        order.status == OrderStatus.confirmed;
  }

  /// Id услуг для предвыбора на карточке СТО: из заказа + сопоставление по имени с прайсом точки.
  Future<List<String>> _serviceIdsForRepeatOrder(WidgetRef ref, STO sto, Order order) async {
    final services = await ref.read(stoServicesProvider(sto.id).future);
    final raw = <String>{};
    for (final item in order.itemsForDisplay) {
      final sid = item.serviceId?.trim();
      if (sid != null && sid.isNotEmpty) {
        raw.add(sid);
        continue;
      }
      final n = item.name.split('\n').first.trim().toLowerCase();
      if (n.isEmpty) continue;
      STOService? match;
      for (final s in services) {
        if (s.name.trim().toLowerCase() == n) {
          match = s;
          break;
        }
      }
      if (match == null) {
        for (final s in services) {
          final sn = s.name.trim().toLowerCase();
          if (sn.contains(n) || n.contains(sn)) {
            match = s;
            break;
          }
        }
      }
      if (match != null) raw.add(match.id);
    }
    return normalizeClientServiceFilterIds(raw.toList());
  }

  Future<void> _repeatOrder(BuildContext context, WidgetRef ref, Order order) async {
    HapticFeedback.lightImpact();
    try {
      final sto = await ref.read(stoByIdProvider(order.stoId).future);
      if (!context.mounted) return;
      if (sto == null) {
        final l10n = L10nScope.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.orderLoadStoFailed),
            backgroundColor: context.palette.error,
          ),
        );
        return;
      }
      final cars = ref.read(carsProvider).valueOrNull ?? [];
      if (cars.any((c) => c.id == order.carId)) {
        await ref.read(selectedCarIdProvider.notifier).set(order.carId);
      }
      final initialIds = await _serviceIdsForRepeatOrder(ref, sto, order);
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => STODetailScreen(
            sto: sto,
            initialServiceIds: initialIds.isEmpty ? null : initialIds,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      final l10n = L10nScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.orderOpenStoFailed),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, Order order) {
    if (!_canClientCancelOrder(order)) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = L10nScope.of(ctx);
        return AlertDialog(
          backgroundColor: context.palette.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.orderCancelConfirmTitle, style: TextStyle(color: context.palette.textPrimary)),
          content: Text(l10n.orderCancelCannotUndo,
            style: TextStyle(color: context.palette.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.orderNo, style: TextStyle(color: context.palette.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                final ok = await ref.read(ordersProvider.notifier).cancelOrder(order.id);
                if (!context.mounted) return;
                if (ok) {
                  ref.invalidate(ordersProvider);
                  ref.invalidate(orderByIdProvider(order.id));
                  Navigator.pop(context);
                  final l = L10nScope.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l.orderCancelledToast),
                    backgroundColor: context.palette.primary,
                  ));
                } else {
                  final l = L10nScope.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l.orderCancelFailed),
                    backgroundColor: context.palette.error,
                  ));
                }
              },
              child: Text(l10n.orderCancelBooking, style: TextStyle(color: context.palette.error)),
            ),
          ],
        );
      },
    );
  }
}

// ── Строка работы с временем ──

class _WorkItemRow extends StatelessWidget {
  final OrderItem item;
  final bool isAdditional;
  const _WorkItemRow({required this.item, this.isAdditional = false});

  @override
  Widget build(BuildContext context) {
    final isRejected = item.isRejected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              item.isCompleted
                  ? Icons.check_circle_rounded
                  : isRejected
                      ? Icons.cancel_rounded
                      : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: item.isCompleted
                  ? context.palette.success
                  : isRejected ? context.palette.error : context.palette.textTertiary,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isRejected ? context.palette.textTertiary : context.palette.textPrimary,
                    decoration: isRejected ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 2),
                // Время выполнения
                Text(
                  '⏱ ${item.durationLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isRejected ? context.palette.textTertiary : context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(Formatters.money(item.priceKopecks), style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: isRejected ? context.palette.textTertiary : context.palette.textPrimary,
          )),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  const _TotalRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, color: context.palette.textPrimary)),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.nestedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.palette.primary),
            SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: context.palette.primary)),
          ],
        ),
      ),
    );
  }
}
