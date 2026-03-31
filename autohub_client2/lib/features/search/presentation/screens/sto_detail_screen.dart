import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../core/availability/availability_helper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/repositories/sto_repository.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/settings/sto_reviews_provider.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/organization_ui_copy.dart';
import '../../../../shared/models/user_sto_review.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

class STODetailScreen extends ConsumerStatefulWidget {
  final STO sto;

  /// Предвыбранные услуги (например, с карточки рекомендации «Замена масла»).
  final List<String>? initialServiceIds;

  const STODetailScreen({super.key, required this.sto, this.initialServiceIds});

  @override
  ConsumerState<STODetailScreen> createState() => _STODetailScreenState();
}

class _STODetailScreenState extends ConsumerState<STODetailScreen> {
  final Set<String> _selectedServices = {};
  bool _showPackages = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceIds != null &&
        widget.initialServiceIds!.isNotEmpty) {
      _selectedServices.addAll(widget.initialServiceIds!);
    }
  }

  STO get _sto => widget.sto;

  Future<void> _openCall() async {
    final phones = _sto.displayPhones;
    if (phones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет номера для звонка'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    String? selected;
    if (phones.length == 1) {
      selected = phones.first;
    } else {
      selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text(
            'Выберите номер',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: phones
                .map(
                  (n) => ListTile(
                    title: Text(
                      Formatters.phone(n),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    onTap: () => Navigator.pop(ctx, n),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    if (selected != null) {
      final digits = selected.replaceAll(RegExp(r'[^\d+]'), '');
      try {
        await launchUrl(
          Uri.parse('tel:$digits'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть набор номера'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showOrdersSheet(BuildContext context) {
    final orders =
        (ref.read(ordersProvider).valueOrNull ?? [])
            .where((o) => o.stoId == widget.sto.id)
            .toList()
          ..sort((a, b) => b.timelineSortAt.compareTo(a.timelineSortAt));
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Заказы в ${widget.sto.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: orders.length,
                itemBuilder: (_, i) {
                  final order = orders[i];
                  return ListTile(
                    title: Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${order.displayStatus.label} · ${Formatters.dateShortRu(order.dateTime)} ${Formatters.time(order.dateTime)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: order.displayStatus.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.displayStatus.shortLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: order.displayStatus.color,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      pushCupertino(context, OrderDetailScreen(order: order));
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

  static String _appendRouteCacheBust(String url) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sep = url.contains('?') ? '&' : '?';
    final idx = url.indexOf('#');
    if (idx >= 0) {
      return url.substring(0, idx) + sep + '_t=$stamp' + url.substring(idx);
    }
    return url + sep + '_t=$stamp';
  }

  Future<void> _openRoute() async {
    if (_sto.latitude == null || _sto.longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет координат для маршрута'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    Position? position;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        await Geolocator.requestPermission();
      if (await Geolocator.isLocationServiceEnabled()) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
      }
    } catch (_) {}
    final mapProvider = ref.read(mapProviderSettingProvider);
    String url;
    if (mapProvider == MapProvider.google) {
      if (position != null) {
        url =
            'https://www.google.com/maps/dir/?api=1&origin=${position.latitude},${position.longitude}&destination=${_sto.latitude},${_sto.longitude}&travelmode=driving';
      } else {
        url =
            'https://www.google.com/maps/dir/?api=1&origin=current+location&destination=${_sto.latitude},${_sto.longitude}&travelmode=driving';
      }
    } else if (mapProvider == MapProvider.yandex) {
      if (position != null) {
        url =
            'https://yandex.ru/maps/?rtext=${position.latitude},${position.longitude}~${_sto.latitude},${_sto.longitude}&rtt=auto';
      } else {
        url =
            'https://yandex.ru/maps/?pt=${_sto.longitude},${_sto.latitude}&z=16';
      }
    } else {
      if (position != null) {
        url =
            'https://www.openstreetmap.org/directions?from=${position.latitude},${position.longitude}&to=${_sto.latitude},${_sto.longitude}';
      } else {
        url =
            'https://www.openstreetmap.org/?mlat=${_sto.latitude}&mlon=${_sto.longitude}#map=16/${_sto.latitude}/${_sto.longitude}';
      }
    }
    url = _appendRouteCacheBust(url);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть карты'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String? _selectedCarBodyType() {
    final selectedId = ref.read(selectedCarIdProvider);
    if (selectedId == null) return null;
    final cars = ref.read(carsProvider).valueOrNull ?? const <Car>[];
    for (final c in cars) {
      if (c.id == selectedId) return c.bodyType;
    }
    return null;
  }

  int _selectedTotal(List<STOService> services) => services
      .where((s) => _selectedServices.contains(s.id))
      .fold(
        0,
        (sum, s) => sum + s.effectivePriceKopecks(_selectedCarBodyType()),
      );

  int _selectedDuration(List<STOService> services) => services
      .where((s) => _selectedServices.contains(s.id))
      .fold(
        0,
        (sum, s) => sum + s.effectiveDurationMinutes(_selectedCarBodyType()),
      );

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(stoServicesProvider(_sto.id)).valueOrNull ?? [];
    final packages = ref.watch(stoPackagesProvider(_sto.id)).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Фото галерея + AppBar
              _buildPhotoHeader(),
              SliverToBoxAdapter(child: _buildContent(services, packages)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          // Sticky booking bar
          if (_selectedServices.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBookingBar(services),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTile(int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardElevated,
            AppColors.nestedBg,
            AppColors.cardBg,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          [
            Icons.car_repair_rounded,
            Icons.build_rounded,
            Icons.garage_rounded,
            Icons.handyman_rounded,
          ][index % 4],
          size: 72,
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildPhotoHeader() {
    final photos = _sto.photoUrls.where((u) => u.isNotEmpty).toList();
    final hasPhotos = photos.isNotEmpty;
    final itemCount = hasPhotos ? photos.length : 4;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.cardBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                itemCount: itemCount,
                itemBuilder: (_, i) {
                  if (hasPhotos) {
                    final url = photos[i];
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderTile(i),
                    );
                  }
                  return _buildPlaceholderTile(i);
                },
              ),
              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.background],
                    ),
                  ),
                ),
              ),
              // Dots
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    itemCount,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == 0 ? 8 : 6,
                      height: i == 0 ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _showOrdersSheet(context),
          icon: const Icon(Icons.list_rounded),
          tooltip: OrganizationUiCopy.ordersTooltip(
            widget.sto.businessKindLabel,
          ),
        ),
        IconButton(
          onPressed: () {
            ref
                .read(favoriteStoStateProvider.notifier)
                .toggle(
                  widget.sto.id,
                  filterByCar: ref.read(filterByCarSettingProvider),
                  selectedCarId: ref.read(selectedCarIdProvider),
                );
            HapticFeedback.lightImpact();
          },
          icon: Icon(
            ref.watch(effectiveFavoriteStoIdsProvider).contains(widget.sto.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color:
                ref
                    .watch(effectiveFavoriteStoIdsProvider)
                    .contains(widget.sto.id)
                ? AppColors.error
                : AppColors.textPrimary,
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.share_rounded)),
      ],
    );
  }

  Widget _buildContent(List<STOService> services, List<STOPackage> packages) {
    final sto = widget.sto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название + рейтинг (с учётом отзывов пользователей)
          Text(
            sto.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final userReviews = ref
                  .watch(stoReviewsProvider.notifier)
                  .forSto(sto.id);
              final rating = StoReviewsNotifier.computedRating(
                sto.rating,
                sto.reviewCount,
                userReviews,
              );
              final count = StoReviewsNotifier.computedReviewCount(
                sto.reviewCount,
                userReviews,
              );
              return Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.rating(rating),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    ' (${Formatters.reviewCount(count)})',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (sto.isOpen ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: sto.isOpen
                                ? AppColors.success
                                : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sto.isOpen ? 'Открыто' : 'Закрыто',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sto.isOpen
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                sto.schedulingMode == 'bay_based'
                    ? OrganizationUiCopy.schedulingBaySubtitle()
                    : OrganizationUiCopy.schedulingStaffSubtitle(),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info rows
          _InfoRow(
            icon: Icons.location_on_rounded,
            text: sto.address,
            trailing: sto.distanceKm != null
                ? Formatters.distance(sto.distanceKm!)
                : null,
          ),
          if (sto.workingHours != null)
            _InfoRow(icon: Icons.access_time_rounded, text: sto.workingHours!),
          if (sto.phone != null)
            _InfoRow(
              icon: Icons.phone_rounded,
              text: Formatters.phone(sto.phone!),
            ),
          const SizedBox(height: 12),

          // Specializations
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sto.specializations
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.nestedBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              _ActionChip(
                icon: Icons.phone_rounded,
                label: 'Позвонить',
                onTap: _openCall,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.directions_rounded,
                label: 'Маршрут',
                onTap: _openRoute,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.share_rounded,
                label: 'Поделиться',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Услуги
          const Text(
            'Услуги',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите список услуг или готовый комплекс',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Список'),
                selected: !_showPackages,
                onSelected: (_) => setState(() => _showPackages = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Комплексы'),
                selected: _showPackages,
                onSelected: (_) => setState(() => _showPackages = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _showPackages
              ? _buildPackagesList(services, packages)
              : _buildServicesList(services),

          const SizedBox(height: 24),

          // Отзывы
          _buildReviewsSection(),
        ],
      ),
    );
  }

  Widget _buildPackagesList(
    List<STOService> services,
    List<STOPackage> packages,
  ) {
    if (packages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'У сервиса пока нет комплексов',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final byId = {for (final s in services) s.id: s};
    final bodyType = _selectedCarBodyType();
    return Column(
      children: packages.map((p) {
        final included = p.includedServiceIds
            .map((id) => byId[id])
            .whereType<STOService>()
            .toList();
        final regular = included.fold(
          0,
          (sum, s) => sum + s.effectivePriceKopecks(bodyType),
        );
        final saving = regular - p.packagePriceKopecks;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(p.name),
            subtitle: Text(
              '${Formatters.money(p.packagePriceKopecks)} • Экономия: ${saving > 0 ? Formatters.money(saving) : '—'}',
            ),
            trailing: TextButton(
              onPressed: () {
                setState(() {
                  for (final s in included) {
                    _selectedServices.add(s.id);
                  }
                });
              },
              child: const Text('Выбрать'),
            ),
            children: [
              ...included.map(
                (s) => ListTile(
                  dense: true,
                  title: Text(s.name),
                  subtitle: Text(
                    '⏱ ${Formatters.durationMinutes(s.effectiveDurationMinutes(bodyType))}',
                  ),
                  trailing: Text(
                    Formatters.money(s.effectivePriceKopecks(bodyType)),
                  ),
                ),
              ),
              if (p.addons.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Доп. услуги',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ...p.addons.map((a) {
                final s = byId[a.serviceId];
                if (s == null) return const SizedBox.shrink();
                final selected = _selectedServices.contains(s.id);
                return CheckboxListTile(
                  dense: true,
                  value: selected,
                  title: Text(s.name),
                  subtitle: Text('+${Formatters.money(a.extraPriceKopecks)}'),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedServices.add(s.id);
                      } else {
                        _selectedServices.remove(s.id);
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 6),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicesList(List<STOService> services) {
    final grouped = <String, List<STOService>>{};
    for (final s in services) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }

    return Column(
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: entry.value.map((service) {
                  final isSelected = _selectedServices.contains(service.id);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected)
                          _selectedServices.remove(service.id);
                        else
                          _selectedServices.add(service.id);
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                                width: isSelected ? 0 : 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Color(0xFF0D0D0D),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '⏱ ${Formatters.durationMinutes(service.effectiveDurationMinutes(_selectedCarBodyType()))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppColors.textSecondary
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.money(
                              service.effectivePriceKopecks(
                                _selectedCarBodyType(),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildReviewsSection() {
    final sto = _sto;
    return Consumer(
      builder: (context, ref, _) {
        final allReviews = ref.watch(stoReviewsProvider);
        final userReviews = allReviews.where((r) => r.stoId == sto.id).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Отзывы${userReviews.isEmpty ? '' : ' (${userReviews.length})'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddReviewDialog(context, ref, sto),
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Написать отзыв',
                    style: TextStyle(fontSize: 14, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (userReviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Пока нет отзывов. Будьте первым!',
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                ),
              )
            else
              ...userReviews.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReviewCard(
                    name: r.authorName,
                    rating: r.rating,
                    date: r.date,
                    text: r.text,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddReviewDialog(BuildContext context, WidgetRef ref, STO sto) {
    final authUser = ref.read(authProvider).user;
    final authorName = authUser?.displayName ?? 'Гость';
    int rating = 5;
    final textController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Написать отзыв',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sto.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Оценка',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setModalState(() => rating = star),
                        child: Icon(
                          star <= rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Текст отзыва',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Опишите ваш опыт...',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              final text = textController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Введите текст отзыва'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              final now = DateTime.now();
                              final dateStr =
                                  '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
                              final review = UserStoReview(
                                id: 'rev_${now.millisecondsSinceEpoch}',
                                stoId: sto.id,
                                authorName: authorName,
                                rating: rating,
                                date: dateStr,
                                text: text,
                                createdAt: now,
                              );
                              ref.read(stoReviewsProvider.notifier).add(review);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Отзыв добавлен'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Отправить',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D0D0D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingBar(List<STOService> services) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedServices.length} услуг · ≈ ${Formatters.durationMinutes(_selectedDuration(services))}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.money(_selectedTotal(services)),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            width: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  pushCupertino(
                    context,
                    _BookingScreen(
                      sto: widget.sto,
                      selectedServiceIds: _selectedServices,
                      cars: ref.watch(carsProvider).valueOrNull ?? [],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Записаться',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D0D0D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Вспомогательные виджеты ──

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? trailing;
  const _InfoRow({required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String name, date, text;
  final int rating;
  const _ReviewCard({
    required this.name,
    required this.rating,
    required this.date,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Экран бронирования ──

class _BookingScreen extends ConsumerStatefulWidget {
  final STO sto;
  final Set<String> selectedServiceIds;
  final List<Car> cars;
  const _BookingScreen({
    required this.sto,
    required this.selectedServiceIds,
    required this.cars,
  });

  @override
  ConsumerState<_BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<_BookingScreen>
    with WidgetsBindingObserver {
  int _selectedCarIndex = 0;
  late DateTime _selectedDate = _todayDateOnly();
  int _selectedTimeSlotIndex = 0;

  /// Выбранный вариант слота (мастер или пост); при нескольких мастерах на одно время — после выбора в листе.
  BookingSlotChoice? _selectedChoice;
  Timer? _todayRefreshTimer;
  final _commentController = TextEditingController();
  AvailableSlotsResult? _slotsResult;
  bool _isSubmitting = false;
  bool _provideVehicleData = false;
  bool _vehicleDetailsExpanded = false;

  List<String> get _timeSlots {
    final r = _slotsResult;
    if (r == null) return buildDaySlotLabels();
    return buildDaySlotLabels(
      slotDurationMinutes: r.slotDurationMinutes,
      workStartMinutes: r.workStartMinutes,
      workEndMinutes: r.workEndMinutes,
    );
  }

  List<STOService> get _selectedServices {
    final services =
        ref.watch(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    return services
        .where((s) => widget.selectedServiceIds.contains(s.id))
        .toList();
  }

  int get _total => _selectedServices.fold(0, (sum, s) => sum + s.priceKopecks);
  int get _totalDuration =>
      _selectedServices.fold(0, (sum, s) => sum + s.durationMinutes);

  bool get _canConfirmBooking {
    final starts = _slotsResult?.startTimes ?? [];
    if (starts.isEmpty) return false;
    final selected =
        _selectedTimeSlotIndex >= 0 &&
            _selectedTimeSlotIndex < _timeSlots.length
        ? _timeSlots[_selectedTimeSlotIndex]
        : null;
    if (selected == null || !starts.contains(selected)) return false;
    if (Formatters.isBookingSlotStartInPastOrNow(_selectedDate, selected))
      return false;
    return _slotChoiceOrNull != null;
  }

  /// Актуальный выбор для текущей ячейки времени (учитывает несколько мастеров на один слот).
  BookingSlotChoice? get _slotChoiceOrNull {
    final res = _slotsResult;
    if (res == null) return null;
    final labels = _timeSlots;
    if (_selectedTimeSlotIndex < 0 || _selectedTimeSlotIndex >= labels.length)
      return null;
    final slot = labels[_selectedTimeSlotIndex];
    final opts = res.choicesForTimeLabel(slot);
    if (opts.isEmpty) return null;
    final cur = _selectedChoice;
    if (cur != null && cur.timeLocalHHmm == slot) {
      for (final o in opts) {
        if (o.startIsoUtc == cur.startIsoUtc && o.masterId == cur.masterId)
          return o;
      }
    }
    return opts.first;
  }

  void _syncChoiceForCurrentSlot() {
    final pick = _slotChoiceOrNull;
    if (_selectedChoice != pick) {
      _selectedChoice = pick;
    }
  }

  Future<void> _pickSlot(int index, String slot) async {
    final res = _slotsResult;
    if (res == null) return;
    final opts = res.choicesForTimeLabel(slot);
    if (opts.isEmpty) return;

    void apply(BookingSlotChoice c) {
      if (!mounted) return;
      setState(() {
        _selectedTimeSlotIndex = index;
        _selectedChoice = c;
      });
    }

    // Пост назначает сервер; клиент только выбирает время.
    if (res.schedulingMode == 'bay_based') {
      apply(opts.first);
      return;
    }

    if (opts.length == 1) {
      apply(opts.first);
      return;
    }

    final firstStart = opts.first.startIsoUtc;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Кто выполнит заказ?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_search_rounded),
                    title: const Text('Кто угодно из свободных'),
                    subtitle: const Text('Мастера назначит сервис'),
                    onTap: () {
                      Navigator.pop(ctx);
                      apply(
                        BookingSlotChoice(
                          startIsoUtc: firstStart,
                          timeLocalHHmm: slot,
                          masterId: null,
                          masterName: '',
                          schedulingMode: 'staff_based',
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ...opts.map(
                    (c) => ListTile(
                      leading: const Icon(Icons.person_rounded),
                      title: Text(
                        c.masterName.trim().isNotEmpty
                            ? c.masterName
                            : 'Специалист',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        apply(c);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static DateTime _todayDateOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _selectedDateIsToday {
    return Formatters.isSameCalendarDay(_selectedDate, DateTime.now());
  }

  void _startTodayRefreshTimer() {
    _todayRefreshTimer?.cancel();
    if (!_selectedDateIsToday) return;
    _todayRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        final starts = _slotsResult?.startTimes ?? [];
        if (starts.isNotEmpty) {
          _adjustSelectedTimeSlotAfterLoad(starts);
          _syncChoiceForCurrentSlot();
        }
      });
    });
  }

  bool _isSlotSelectable(String slot, List<String> starts) {
    if (!starts.contains(slot)) return false;
    return !Formatters.isBookingSlotStartInPastOrNow(_selectedDate, slot);
  }

  void _adjustSelectedTimeSlotAfterLoad(List<String> starts) {
    final current =
        _selectedTimeSlotIndex >= 0 &&
            _selectedTimeSlotIndex < _timeSlots.length
        ? _timeSlots[_selectedTimeSlotIndex]
        : null;
    if (current != null && _isSlotSelectable(current, starts)) return;
    for (var i = 0; i < _timeSlots.length; i++) {
      if (_isSlotSelectable(_timeSlots[i], starts)) {
        _selectedTimeSlotIndex = i;
        _syncChoiceForCurrentSlot();
        return;
      }
    }
    _selectedTimeSlotIndex = 0;
    _syncChoiceForCurrentSlot();
  }

  /// Сообщение, если в выбранный день нет мастера по навыкам выбранных услуг.
  String? get _noMasterWarning {
    final res = _slotsResult;
    if (res == null || res.startTimes.isNotEmpty) return null;
    if (res.requiredSkills.isEmpty) return null;
    final servicesNeedingSkill = _selectedServices
        .where(
          (s) =>
              s.requiredSkill != null &&
              res.requiredSkills.contains(s.requiredSkill),
        )
        .toList();
    if (servicesNeedingSkill.isEmpty) return null;
    final names = servicesNeedingSkill.map((s) => s.name).join(', ');
    return 'В этот день мастер по услуге${servicesNeedingSkill.length > 1 ? 'м' : ''} «$names» не работает. '
        'Выберите другую дату или продолжите запись без этой услуги.';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final selectedId = ref.read(selectedCarIdProvider);
    if (selectedId != null && widget.cars.isNotEmpty) {
      final idx = widget.cars.indexWhere((c) => c.id == selectedId);
      if (idx >= 0) _selectedCarIndex = idx;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollSelectedCarIntoView(),
    );
    _startTodayRefreshTimer();
    _loadSlots();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _scrollSelectedCarIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cars = widget.cars;
      if (_selectedCarIndex < 0 || _selectedCarIndex >= cars.length) return;
      final id = cars[_selectedCarIndex].id;
      scrollWidgetToViewportCenter(GlobalObjectKey(id).currentContext);
    });
  }

  Future<void> _loadSlots() async {
    setState(() => _slotsResult = null);
    final repo = ref.read(stoRepositoryProvider);
    final result = await repo.getAvailableSlots(
      widget.sto.id,
      _selectedDate,
      widget.selectedServiceIds.toList(),
    );
    if (!mounted) return;
    result.when(
      success: (res) {
        setState(() {
          _slotsResult = res;
          _adjustSelectedTimeSlotAfterLoad(res.startTimes);
          _syncChoiceForCurrentSlot();
        });
      },
      failure: (_) => setState(
        () => _slotsResult = const AvailableSlotsResult(
          startTimes: [],
          slotChoices: [],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _todayRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Запись на сервис',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // Сервис
                _buildSectionLabel('Сервис'),
                _buildSTOInfo(),
                const SizedBox(height: 20),

                // Выбранные услуги
                _buildSectionLabel('Выбранные услуги'),
                _buildSelectedServices(),
                const SizedBox(height: 20),

                // Автомобиль
                _buildSectionLabel('Автомобиль'),
                _buildCarSelector(),
                const SizedBox(height: 12),
                // Предоставить данные автомобиля сервису
                Material(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(
                      () => _provideVehicleData = !_provideVehicleData,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Предоставить данные автомобиля сервису',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Switch(
                            value: _provideVehicleData,
                            onChanged: (v) =>
                                setState(() => _provideVehicleData = v),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_provideVehicleData) ...[
                  const SizedBox(height: 8),
                  _buildVehicleDataCard(),
                ],
                const SizedBox(height: 20),

                // Дата
                _buildSectionLabel('Дата'),
                _buildDateSelector(),
                const SizedBox(height: 20),

                // Время (только начала, где помещается весь блок _totalDuration)
                _buildSectionLabel('Время'),
                if (_noMasterWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _noMasterWarning!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_totalDuration > 0 && _noMasterWarning == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Нужно окно ${Formatters.durationMinutes(_totalDuration)} подряд. Занятые слоты недоступны.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                _buildTimeSelector(),
                const SizedBox(height: 8),
                const Text(
                  'Позже: можно будет разбить приём на несколько визитов в течение дня.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),

                // Комментарий
                _buildSectionLabel('Комментарий (необязательно)'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Опишите проблему или пожелания...',
                      hintStyle: TextStyle(
                        color: AppColors.textPlaceholder,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom bar
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSTOInfo() {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.nestedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                widget.sto.name[0],
                style: const TextStyle(
                  fontSize: 20,
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
                ),
                Text(
                  widget.sto.address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedServices() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: _selectedServices
            .map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '⏱ ${s.durationLabel}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.money(s.priceKopecks),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildVehicleDataCard() {
    if (widget.cars.isEmpty) return const SizedBox.shrink();
    final car = widget.cars[_selectedCarIndex];
    final vinDisplay = (car.vin != null && car.vin!.isNotEmpty)
        ? car.vin!
        : '—';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'VIN:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vinDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(
              () => _vehicleDetailsExpanded = !_vehicleDetailsExpanded,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    _vehicleDetailsExpanded ? 'Свернуть' : 'Подробнее',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _vehicleDetailsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_vehicleDetailsExpanded) ...[
            const Divider(height: 1),
            _vehicleDataRow(
              'Пробег',
              car.mileage > 0 ? '${car.mileage} км' : '—',
            ),
            _vehicleDataRow('Гос. номер', car.plateNumber ?? '—'),
            _vehicleDataRow('Двигатель', car.engineType ?? '—'),
            _vehicleDataRow('Кузов', car.bodyType ?? '—'),
            _vehicleDataRow('Цвет', car.color ?? '—'),
            _vehicleDataRow(
              'Коробка / привод',
              [
                    if (car.transmission != null &&
                        car.transmission!.isNotEmpty)
                      car.transmission!,
                    if (car.drivetrain != null && car.drivetrain!.isNotEmpty)
                      car.drivetrain!,
                  ].join(', ').trim().isEmpty
                  ? '—'
                  : [
                      if (car.transmission != null &&
                          car.transmission!.isNotEmpty)
                        car.transmission!,
                      if (car.drivetrain != null && car.drivetrain!.isNotEmpty)
                        car.drivetrain!,
                    ].join(', '),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _vehicleDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarSelector() {
    final cars = widget.cars;
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final car = cars[i];
          final isSelected = i == _selectedCarIndex;
          return GestureDetector(
            key: GlobalObjectKey(car.id),
            onTap: () {
              setState(() => _selectedCarIndex = i);
              _scrollSelectedCarIntoView();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${car.brand} ${car.model}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    car.plateNumber ?? '${car.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final dates = List.generate(14, (i) => base.add(Duration(days: i)));

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final date = dates[i];
          final isSelected = Formatters.isSameCalendarDay(date, _selectedDate);
          final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _startTodayRefreshTimer();
              _loadSlots();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? const Color(0xFF0D0D0D)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF0D0D0D)
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    final available = _slotsResult?.startTimes ?? [];
    final loading = _slotsResult == null;
    final busyRanges = <BusyRange>[];
    final labels = _timeSlots;
    final slotDur = _slotsResult?.slotDurationMinutes ?? defaultSlotMinutes;
    final jobDur = _totalDuration.clamp(15, 24 * 60);
    DateTime? jobStart;
    if (labels.isNotEmpty &&
        _selectedTimeSlotIndex >= 0 &&
        _selectedTimeSlotIndex < labels.length &&
        available.contains(labels[_selectedTimeSlotIndex])) {
      jobStart = Formatters.dateAtTimeSlot(
        _selectedDate,
        labels[_selectedTimeSlotIndex],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Загрузка слотов...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(labels.length, (i) {
            final slot = labels[i];
            final isSelected = i == _selectedTimeSlotIndex;
            final isOccupied = isSlotOccupied(
              slot,
              busyRanges,
              slotDurationMinutes: slotDur,
            );
            final isAvailable = available.contains(slot);
            final isPastToday = Formatters.isBookingSlotStartInPastOrNow(
              _selectedDate,
              slot,
            );
            final isDisabled = loading || !isAvailable || isPastToday;
            final isStart = isSelected && isAvailable && !isPastToday;
            final isContinuation =
                !isPastToday &&
                !isStart &&
                jobStart != null &&
                slotIsJobContinuation(slot, jobStart, _selectedDate, jobDur) &&
                isAvailable;
            final Color slotBg = isPastToday
                ? AppColors.textMuted.withValues(alpha: 0.2)
                : isAvailable
                ? (isStart
                      ? AppColors.primary
                      : AppColors.success.withValues(alpha: 0.2))
                : isOccupied
                ? AppColors.error.withValues(alpha: 0.25)
                : AppColors.nestedBg;
            final Color slotBorder = isPastToday
                ? AppColors.border.withValues(alpha: 0.45)
                : isAvailable
                ? (isStart
                      ? AppColors.primary
                      : isContinuation
                      ? const Color(0xFFE65100)
                      : AppColors.success)
                : isOccupied
                ? AppColors.error
                : AppColors.border;
            final Color slotText = isPastToday
                ? AppColors.textMuted
                : isAvailable
                ? (isStart ? const Color(0xFF0D0D0D) : AppColors.success)
                : isOccupied
                ? AppColors.error
                : AppColors.textTertiary;

            return GestureDetector(
              onTap: isDisabled ? null : () => _pickSlot(i, slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: slotBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: slotBorder,
                    width: isContinuation ? 2 : 1,
                  ),
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: slotText,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого:',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.money(_total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Builder(
              builder: (_) {
                final labels = _timeSlots;
                if (labels.isEmpty) {
                  return Text(
                    Formatters.dateShortRu(_selectedDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  );
                }
                final idx = _selectedTimeSlotIndex.clamp(0, labels.length - 1);
                final slot = labels[idx];
                final start = Formatters.dateAtTimeSlot(_selectedDate, slot);
                final end = start?.add(Duration(minutes: _totalDuration));
                final range = (start != null && end != null)
                    ? Formatters.bookingRangeLabel(start, end)
                    : '${Formatters.dateShortRu(_selectedDate)}, $slot';
                final dur = Formatters.durationMinutes(_totalDuration);
                final mode = _slotsResult?.schedulingMode ?? 'staff_based';
                final choice = _slotChoiceOrNull;
                String? resourceLine;
                if (choice != null && mode == 'staff_based') {
                  if (choice.masterId != null && choice.masterId!.isNotEmpty) {
                    resourceLine = choice.masterName.trim().isNotEmpty
                        ? 'Мастер: ${choice.masterName}'
                        : 'К специалисту';
                  } else {
                    resourceLine = 'Мастер назначит сервис';
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$range · ≈ $dur',
                      maxLines: 4,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    if (resourceLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        resourceLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GoldButton(
            text: _isSubmitting ? 'Создание записи...' : 'Подтвердить запись',
            onPressed: (_canConfirmBooking && !_isSubmitting)
                ? () => _submitBooking(context)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submitBooking(BuildContext context) async {
    if (widget.cars.isEmpty) return;
    final car = widget.cars[_selectedCarIndex];
    final carInfo = car.confirmedCarInfo;
    setState(() => _isSubmitting = true);
    final labels = _timeSlots;
    if (labels.isEmpty) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    final orderRepo = ref.read(orderRepositoryProvider);
    final slotIdx = _selectedTimeSlotIndex.clamp(0, labels.length - 1);
    final choice = _slotChoiceOrNull;
    if (choice == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    final startUtc = DateTime.tryParse(choice.startIsoUtc)?.toUtc();
    final result = await orderRepo.createOrder(
      carId: car.id,
      organizationId: widget.sto.id,
      serviceIds: widget.selectedServiceIds.toList(),
      scheduledDate: _selectedDate,
      scheduledTime: labels[slotIdx],
      scheduledStartUtc: startUtc,
      masterId: choice.masterId,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      carInfo: carInfo,
      vin: _provideVehicleData ? car.vin : null,
      licensePlate: _provideVehicleData ? car.plateNumber : null,
      bodyType: _provideVehicleData ? car.bodyType : null,
      color: _provideVehicleData ? car.color : null,
      mileage: _provideVehicleData && car.mileage > 0 ? car.mileage : null,
      engineType: _provideVehicleData ? car.engineType : null,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.when(
      success: (_) {
        ref.read(ordersProvider.notifier).loadOrders();
        ref.read(chatsProvider.notifier).loadChats();
        _showSuccessDialog(context);
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 40,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Запись создана!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                () {
                  final slot = _timeSlots[_selectedTimeSlotIndex];
                  final start = Formatters.dateAtTimeSlot(_selectedDate, slot);
                  final end = start?.add(Duration(minutes: _totalDuration));
                  final range = (start != null && end != null)
                      ? Formatters.bookingRangeLabel(start, end)
                      : '${Formatters.dateFullRu(_selectedDate)}, $slot';
                  return '${widget.sto.name}\n$range · ≈ ${Formatters.durationMinutes(_totalDuration)}';
                }(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GoldButton(
                text: 'Отлично',
                onPressed: () {
                  Navigator.pop(context); // диалог
                  Navigator.pop(
                    context,
                  ); // экран бронирования — остаёмся на карточке точки
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
