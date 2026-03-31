import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/pdf/order_worksheet_pdf.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/org_business_kind.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Адрес сервиса не привязан к карте'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    final mapProvider = ref.read(mapProviderSettingProvider);
    String url;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Включите геолокацию для построения маршрута'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Доступ к местоположению запрещён. Маршрут откроется до точки назначения.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
      Position? position;
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
      }
      if (mapProvider == MapProvider.google) {
        if (position != null) {
          url = 'https://www.google.com/maps/dir/?api=1&origin=${position.latitude},${position.longitude}&destination=${sto.latitude},${sto.longitude}&travelmode=driving';
        } else {
          url = 'https://www.google.com/maps/dir/?api=1&origin=current+location&destination=${sto.latitude},${sto.longitude}&travelmode=driving';
        }
      } else if (mapProvider == MapProvider.yandex) {
        if (position != null) {
          url = 'https://yandex.ru/maps/?rtext=${position.latitude},${position.longitude}~${sto.latitude},${sto.longitude}&rtt=auto';
        } else {
          url = 'https://yandex.ru/maps/?pt=${sto.longitude},${sto.latitude}&z=16';
        }
      } else {
        if (position != null) {
          url = 'https://www.openstreetmap.org/directions?from=${position.latitude},${position.longitude}&to=${sto.latitude},${sto.longitude}';
        } else {
          url = 'https://www.openstreetmap.org/?mlat=${sto.latitude}&mlon=${sto.longitude}#map=16/${sto.latitude}/${sto.longitude}';
        }
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final sep = url.contains('?') ? '&' : '?';
      final idx = url.indexOf('#');
      final urlWithStamp = idx >= 0
          ? url.substring(0, idx) + sep + '_t=$stamp' + url.substring(idx)
          : url + sep + '_t=$stamp';
      await launchUrl(Uri.parse(urlWithStamp), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось построить маршрут: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(chatIdResult.errorOrNull?.message ?? 'Чат по заказу не найден'),
          backgroundColor: AppColors.error,
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(oneResult.errorOrNull?.message ?? 'Не удалось открыть чат'),
            backgroundColor: AppColors.error,
          ));
        }
        return;
      }
    }
    if (context.mounted) {
      pushCupertino(context, ChatDetailScreen(chat: chat!, currentOrderId: order.id));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            title: Text('Заказ #${displayOrder.orderNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                onPressed: () => printOrderWorksheet(context, displayOrder, car: car.id == displayOrder.carId ? car : null),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
                tooltip: 'Заказ-наряд (PDF)',
              ),
              IconButton(
                onPressed: () => _openChat(context, ref, displayOrder),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                tooltip: 'Открыть чат',
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildContent(context, ref, car, displayOrder)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Car car, Order order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(order),
          const SizedBox(height: 16),

          if (order.status == OrderStatus.pendingApproval)
            _buildApprovalBanner(context, ref, order),

          _buildSection('Автомобиль', child: _buildCarInfo(car)),
          const SizedBox(height: 12),

          _buildSection('Сервис', child: _buildSTOInfo(context, ref, order)),
          const SizedBox(height: 12),

          _buildSection('Дата и время', child: _buildDateTime(order)),
          const SizedBox(height: 12),

          // Состав: при pending_approval — черновик из approval_preview (см. Order.itemsForDisplay).
          _buildSection('Работы', child: _buildWorkItems(order)),

          if (order.itemsForDisplay.any((i) => i.isAdditional)) ...[
            const SizedBox(height: 12),
            _buildSection(
              order.status == OrderStatus.pendingApproval
                  ? 'Дополнительно (на согласовании)'
                  : 'Добавлено (после согласования)',
              child: _buildAdditionalItems(order),
            ),
          ],

          const SizedBox(height: 12),

          // Общее время
          _buildTimeEstimate(order),
          const SizedBox(height: 12),

          _buildTotalSection(order),
          const SizedBox(height: 12),

          _buildPhotosSection(),
          const SizedBox(height: 12),

          if (order.comment != null && order.comment!.isNotEmpty) ...[
            _buildSection('Комментарий', child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('"${order.comment}"', style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, fontStyle: FontStyle.italic,
              )),
            )),
            const SizedBox(height: 12),
          ],

          _buildActions(context, ref, order),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(Order order) {
    final steps = ['Записан', 'Подтверждён', 'В работе', 'Готов', 'Завершён'];
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
              const SizedBox(width: 8),
              Text(order.displayStatus.label.toUpperCase(), style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: order.displayStatus.color, letterSpacing: 0.5,
              )),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.displayStatus.progress,
              minHeight: 6,
              backgroundColor: AppColors.nestedBg,
              valueColor: AlwaysStoppedAnimation(order.displayStatus.color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (i) {
              final isCompleted = i < currentStep;
              final isCurrent = i == currentStep;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppColors.success
                            : isCurrent ? order.status.color : AppColors.nestedBg,
                        border: Border.all(
                          color: isCompleted || isCurrent ? Colors.transparent : AppColors.border,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : isCurrent
                              ? Container(
                                  margin: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i], style: TextStyle(
                      fontSize: 10,
                      color: isCompleted || isCurrent ? AppColors.textPrimary : AppColors.textTertiary,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ), textAlign: TextAlign.center),
                  ],
                ),
              );
            }),
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

  Widget _buildApprovalBanner(BuildContext context, WidgetRef ref, Order order) {
    return GestureDetector(
      onTap: () => _openChat(context, ref, order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.statusApproval.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.statusApproval.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Требуется согласование доп.работ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.statusApproval)),
                  const SizedBox(height: 2),
                  const Text('Подтвердите или отклоните в чате',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Перейти в чат', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D0D0D),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
        )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildCarInfo(Car car) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.nestedBg, borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.directions_car_rounded, size: 28,
              color: AppColors.textTertiary.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${car.brand} ${car.model}, ${car.year}', style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                )),
                const SizedBox(height: 2),
                Text(
                  '${car.plateNumber ?? ''} | ${Formatters.mileage(car.mileage)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSTOInfo(BuildContext context, WidgetRef ref, Order order) {
    final phones = order.stoPhone != null ? [order.stoPhone!] : <String>[];
    final stoAsync = ref.watch(stoByIdProvider(order.stoId));
    final sto = stoAsync.valueOrNull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: sto != null
            ? () => pushCupertino(context, STODetailScreen(sto: sto))
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    order.stoName.isNotEmpty ? order.stoName[0] : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.stoName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (order.stoAddress != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.stoAddress!,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                    if (OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty ||
                        OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      if (OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty)
                        Text(
                          OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      if (OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode).isNotEmpty) ...[
                        if (OrgBusinessKind.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty)
                          const SizedBox(height: 2),
                        Text(
                          'Запись: ${OrgBusinessKind.schedulingModeShortLabel(order.organizationSchedulingMode)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SmallAction(
                          icon: Icons.phone_rounded,
                          label: 'Позвонить',
                          onTap: () => _openPhone(context, phones),
                        ),
                        const SizedBox(width: 12),
                        _SmallAction(
                          icon: Icons.directions_rounded,
                          label: 'Маршрут',
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
    if (phones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Номер не указан'), backgroundColor: AppColors.warning),
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
        backgroundColor: AppColors.cardBg,
        title: const Text('Выберите номер', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: phones
              .map((n) => ListTile(
                    title: Text(Formatters.phone(n), style: const TextStyle(color: AppColors.textPrimary)),
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

  Widget _buildDateTime(Order order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                '${Formatters.dateFullRu(order.dateTime)}, ${Formatters.time(order.dateTime)}',
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ],
          ),
          if (order.status.isActive && order.plannedEndTime != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(
                  'Ориентировочное окончание: ${Formatters.time(order.plannedEndTime!)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
  Widget _buildTimeEstimate(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.schedule_rounded, size: 22, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ожидаемое время', style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary,
                )),
                const SizedBox(height: 2),
                Text(order.displayDurationLabel, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text('работ выполнено', style: TextStyle(
                fontSize: 11, color: AppColors.textTertiary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(Order order) {
    final disp = order.itemsForDisplay;
    final workTotal = disp.where((i) => !i.isAdditional).fold(0, (sum, i) => sum + i.priceKopecks);
    final addTotal = disp.where((i) => i.isAdditional).fold(0, (sum, i) => sum + i.priceKopecks);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardBg, AppColors.primary.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _TotalRow('Работы:', Formatters.money(workTotal)),
          if (addTotal > 0)
            _TotalRow('Дополнительно:', Formatters.money(addTotal)),
          const Divider(color: AppColors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
              Text(Formatters.money(order.totalKopecksForDisplay), style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: AppColors.primary, fontFamily: 'monospace',
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Фото работ', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
        )),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.photo_camera_rounded, color: AppColors.textTertiary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, Order order) {
    return Column(
      children: [
        if (order.status == OrderStatus.pendingApproval)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GoldButton(text: 'Перейти к согласованию',
              onPressed: () => _openChat(context, ref, order)),
          ),
        if (order.status == OrderStatus.done) ...[
          GoldButton(text: 'Оставить отзыв', onPressed: () {}),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.primary),
          ),
          child: const Text('Повторить заказ'),
        ),
        if (order.status == OrderStatus.pendingConfirmation ||
            order.status == OrderStatus.confirmed) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showCancelDialog(context, ref, order),
            child: const Text('Отменить запись', style: TextStyle(
              fontSize: 14, color: AppColors.error,
            )),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Отменить запись?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Эту операцию нельзя отменить.',
          style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Нет', style: TextStyle(color: AppColors.textSecondary)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Запись отменена'),
                  backgroundColor: AppColors.primary,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Не удалось отменить запись. Проверьте сеть.'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('Отменить запись', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
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
                  ? AppColors.success
                  : isRejected ? AppColors.error : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: isRejected ? AppColors.textTertiary : AppColors.textPrimary,
                    decoration: isRejected ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                // Время выполнения
                Text(
                  '⏱ ${item.durationLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isRejected ? AppColors.textTertiary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(Formatters.money(item.priceKopecks), style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: isRejected ? AppColors.textTertiary : AppColors.textPrimary,
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
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
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
          color: AppColors.nestedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
