import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/onboarding/garage_first_car_tutorial_provider.dart';
import '../../../../core/onboarding/garage_tutorial_target.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/navigation/driving_route_launcher.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/shell_navigation_provider.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/sto_reviews_provider.dart';
import '../../../search/presentation/widgets/sto_list_leading_image.dart';
import '../../../search/presentation/widgets/sto_search_list_brands_line.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteAsync = ref.watch(favoriteSTOsListProvider);
    var stos = List<STO>.from(favoriteAsync.valueOrNull ?? []);
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedId = ref.watch(selectedCarIdProvider);
    if (filterByCar && selectedId != null) {
      final cars = ref.watch(carsProvider).valueOrNull ?? [];
      Car? car;
      try {
        car = cars.firstWhere((c) => c.id == selectedId);
      } catch (_) {}
      if (car != null) {
        stos = stos.where((s) => stoMatchesCarBrand(s.specializations, car!.brand)).toList();
      }
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: GarageTutorialTarget(
          highlightStep: GarageFirstCarTutorialStep.servicesFavorites,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Мои сервисы', style: AppTextStyles.screenTitle(context.palette)),
                  ),
                ),
              ),
              Expanded(
                child: favoriteAsync.isLoading && stos.isEmpty
                  ? Center(child: CircularProgressIndicator(color: context.palette.primary))
                  : favoriteAsync.hasError && stos.isEmpty
                      ? Center(
                          child: Text(
                            'Не удалось загрузить избранное',
                            style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
                          ),
                        )
                      : stos.isEmpty
                  ? EmptyState(
                      icon: '❤️',
                      title: 'Нет избранных сервисов',
                      subtitle: 'Добавляйте сервисы в избранное в разделе Поиск — так вы сможете быстро записываться',
                      buttonText: 'Найти сервис',
                      onButton: () {
                        ref.read(shellTargetTabProvider.notifier).state = 2;
                      },
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: stos.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) => _STOCard(sto: stos[i], ref: ref),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заказы по этой точке (из провайдера). Если [carId] задан — только по этой машине.
List<Order> _ordersForSto(WidgetRef ref, STO sto, {String? carId}) {
  var list = (ref.read(ordersProvider).valueOrNull ?? []).where((o) => o.stoId == sto.id).toList();
  if (carId != null) list = list.where((o) => o.carId == carId).toList();
  list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return list;
}

class _STOCard extends ConsumerStatefulWidget {
  final STO sto;
  final WidgetRef ref;

  const _STOCard({required this.sto, required this.ref});

  @override
  ConsumerState<_STOCard> createState() => _STOCardState();
}

class _STOCardState extends ConsumerState<_STOCard> {
  bool _isExpanded = false;
  bool _showAllHistory = false;

  @override
  Widget build(BuildContext context) {
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedCarId = ref.watch(selectedCarIdProvider);
    final carIdFilter = filterByCar ? selectedCarId : null;
    final history = _ordersForSto(ref, widget.sto, carId: carIdFilter);
    final visibleHistory = _showAllHistory ? history : history.take(3).toList();
    final hasMore = history.length > 3;
    final allReviews = ref.watch(stoReviewsProvider);
    final userReviews = allReviews.where((r) => r.stoId == widget.sto.id).toList();
    final displayRating = StoReviewsNotifier.computedRating(
      widget.sto.rating,
      widget.sto.reviewCount,
      userReviews,
    );
    final displayReviewCount =
        StoReviewsNotifier.computedReviewCount(widget.sto.reviewCount, userReviews);

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: context.palette.cardBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        StoListLeadingImage(sto: widget.sto, size: 80, borderRadius: 12),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: context.palette.primary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                '${Formatters.rating(displayRating)} ($displayReviewCount)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sto.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.sto.address,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.palette.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.sto.distanceKm != null)
                              Text(
                                Formatters.distance(widget.sto.distanceKm!),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.sto.isOpen ? context.palette.success : context.palette.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.sto.isOpen ? 'Открыто' : 'Закрыто',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.sto.isOpen ? context.palette.success : context.palette.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        StoSearchListBrandsLine(sto: widget.sto),
                        if (widget.sto.minPrice != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.sto.minPrice!,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                    color: context.palette.textTertiary,
                    size: 24,
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              Divider(color: context.palette.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'История посещений',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12),
                    if (visibleHistory.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Пока нет посещений',
                          style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                        ),
                      )
                    else ...[
                      ...visibleHistory.map((order) => _HistoryRow(
                            order: order,
                            onTap: () => pushCupertino(context, OrderDetailScreen(order: order)),
                          )),
                      if (hasMore && !_showAllHistory)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton(
                            onPressed: () => setState(() => _showAllHistory = true),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Развернуть все', style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.palette.primary,
                            )),
                          ),
                        ),
                    ],
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: context.palette.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                onPressed: () => pushStoDetailScreen(context, STODetailScreen(sto: widget.sto)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Записаться',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.phone_rounded,
                          onTap: () => _openPhone(context, widget.sto),
                        ),
                        SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.directions_rounded,
                          onTap: () => _openRoute(context, ref, widget.sto),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Звонок: один номер — сразу tel:, несколько — диалог выбора
  static Future<void> _openPhone(BuildContext context, STO sto) async {
    final phones = sto.displayPhones;
    if (phones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Номер не указан'), backgroundColor: context.palette.warning),
        );
      }
      return;
    }
    if (phones.length == 1) {
      await launchUrl(Uri.parse('tel:${phones.first.replaceAll(RegExp(r'[\s\(\)\-]'), '')}'),
          mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text('Выберите номер', style: TextStyle(color: context.palette.textPrimary)),
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
          mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _openRoute(BuildContext context, WidgetRef ref, STO sto) async {
    if (sto.latitude == null || sto.longitude == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Адрес сервиса не привязан к карте'),
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
}

class _HistoryRow extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _HistoryRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final workName = order.items.isNotEmpty ? order.items.first.name : 'Заказ ${order.orderNumber}';
    final date = Formatters.dateShortYearRu(order.dateTime);
    final price = Formatters.money(order.totalKopecks);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  date,
                  style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workName,
                    style: TextStyle(fontSize: 13, color: context.palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.palette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.palette.nestedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.palette.border),
        ),
        child: Icon(icon, size: 20, color: context.palette.textPrimary),
      ),
    );
  }
}
