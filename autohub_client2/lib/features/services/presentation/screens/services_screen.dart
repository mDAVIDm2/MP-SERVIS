import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Мои сервисы', style: AppTextStyles.screenTitle),
                ),
              ),
            ),
            Expanded(
              child: favoriteAsync.isLoading && stos.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : favoriteAsync.hasError && stos.isEmpty
                      ? Center(
                          child: Text(
                            'Не удалось загрузить избранное',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        )
                      : stos.isEmpty
                  ? EmptyState(
                      icon: '❤️',
                      title: 'Нет избранных сервисов',
                      subtitle: 'Добавляйте сервисы в избранное в разделе Поиск — так вы сможете быстро записываться',
                      buttonText: 'Найти сервис',
                      onButton: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Откройте вкладку «Поиск»'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: stos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _STOCard(sto: stos[i], ref: ref),
                    ),
            ),
          ],
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

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.nestedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        widget.sto.name[0],
                        style: const TextStyle(
                          fontSize: 24,
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
                        Text(
                          widget.sto.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              Formatters.rating(widget.sto.rating),
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text(
                              ' (${Formatters.reviewCount(widget.sto.reviewCount)})',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.sto.address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.sto.distanceKm != null)
                              Text(
                                Formatters.distance(widget.sto.distanceKm!),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.sto.specializations
                              .map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.nestedBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.sto.isOpen ? AppColors.success : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.sto.isOpen ? 'Открыто' : 'Закрыто',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.sto.isOpen ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 24,
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const Divider(color: AppColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'История посещений',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (visibleHistory.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Пока нет посещений',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                            child: const Text('Развернуть все', style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            )),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                onPressed: () => pushCupertino(context, STODetailScreen(sto: widget.sto)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Записаться',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D0D0D),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.phone_rounded,
                          onTap: () => _openPhone(context, widget.sto),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.directions_rounded,
                          onTap: () => _openRoute(context, widget.sto, ref.read(mapProviderSettingProvider)),
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
          const SnackBar(content: Text('Номер не указан'), backgroundColor: AppColors.warning),
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
          mode: LaunchMode.externalApplication);
    }
  }

  static String _appendRouteCacheBust(String url) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sep = url.contains('?') ? '&' : '?';
    final idx = url.indexOf('#');
    if (idx >= 0) {
      return url.substring(0, idx) + sep + '_t=$stamp' + url.substring(idx);
    }
    return url + sep + '_t=$stamp';
  }

  /// Маршрут от текущего местоположения до точки в выбранных картах
  static Future<void> _openRoute(BuildContext context, STO sto, MapProvider mapProvider) async {
    if (sto.latitude == null || sto.longitude == null) {
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
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Доступ к местоположению запрещён. Маршрут откроется до точки назначения.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
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
        url = 'https://www.openstreetmap.org/directions?from=${position?.latitude ?? ""},${position?.longitude ?? ""}&to=${sto.latitude},${sto.longitude}';
        if (position == null) {
          url = 'https://www.openstreetmap.org/?mlat=${sto.latitude}&mlon=${sto.longitude}#map=16/${sto.latitude}/${sto.longitude}';
        }
      }
      url = _appendRouteCacheBust(url);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workName,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
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
          color: AppColors.nestedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
