import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/navigation/app_navigator_key.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/driving_route_launcher.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../core/availability/availability_helper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/repositories/sto_repository.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/sto_reviews_provider.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/organization_ui_copy.dart';
import '../../../../shared/models/user_sto_review.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/services_packages_toggle.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/catalog/client_catalog_service_ids.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import '../widgets/location_preview_card.dart';

int _packageDurationMinutes(STOPackage p, List<STOService> services, String? bodyType) {
  if (p.packageDurationMinutes > 0) return p.packageDurationMinutes;
  final byId = {for (final s in services) s.id: s};
  return p.includedServiceIds.fold(
    0,
    (a, id) => a + (byId[id]?.effectiveDurationMinutes(bodyType) ?? 0),
  );
}

int _packageAddonsExtraDuration(
  STOPackage p,
  Set<String> addonIds,
  List<STOService> services,
  String? bodyType,
) {
  final byId = {for (final s in services) s.id: s};
  var d = 0;
  for (final a in p.addons) {
    if (!addonIds.contains(a.serviceId)) continue;
    final s = byId[a.serviceId];
    if (s == null) continue;
    d += a.extraDurationMinutes > 0
        ? a.extraDurationMinutes
        : s.effectiveDurationMinutes(bodyType);
  }
  return d;
}

int _packageBookingTotalKopecks(STOPackage p, Set<String> addonIds) {
  var t = p.packagePriceKopecks;
  for (final ad in p.addons) {
    if (addonIds.contains(ad.serviceId)) t += ad.extraPriceKopecks;
  }
  return t;
}

/// После [Navigator.pop] с экрана брони overlay ещё перестраивается — SnackBar в том же кадре даёт assert
/// (`_elements.contains(element)` / `_owner != null`).
void _showBookingCreatedSnackBar(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rootCtx = appRootNavigatorKey.currentContext;
      if (rootCtx == null || !rootCtx.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(rootCtx);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    });
  });
}

/// Только http(s) — локальный путь серверу не отправляем.
String? _carPhotoUrlForApi(String? raw) {
  final p = raw?.trim() ?? '';
  if (p.isEmpty) return null;
  final l = p.toLowerCase();
  if (l.startsWith('http://') || l.startsWith('https://')) return p;
  return null;
}

List<ClientOrderLineDraft> _packageOrderLines(
  STOPackage p,
  Set<String> addonIds,
  List<STOService> services,
  String? bodyType,
) {
  final byId = {for (final s in services) s.id: s};
  final includedNames = <String>[];
  for (final sid in p.includedServiceIds) {
    final s = byId[sid];
    if (s != null) includedNames.add(s.name);
  }
  var packageDisplayName = p.name;
  if (includedNames.isNotEmpty) {
    packageDisplayName =
        '$packageDisplayName\n${includedNames.map((n) => '• $n').join('\n')}';
  }
  final lines = <ClientOrderLineDraft>[
    ClientOrderLineDraft(
      name: packageDisplayName,
      priceKopecks: p.packagePriceKopecks,
      estimatedMinutes: _packageDurationMinutes(p, services, bodyType),
    ),
  ];
  for (final ad in p.addons) {
    if (!addonIds.contains(ad.serviceId)) continue;
    final s = byId[ad.serviceId];
    if (s == null) continue;
    lines.add(
      ClientOrderLineDraft(
        name: s.name,
        priceKopecks: ad.extraPriceKopecks,
        estimatedMinutes: ad.extraDurationMinutes > 0
            ? ad.extraDurationMinutes
            : s.effectiveDurationMinutes(bodyType),
      ),
    );
  }
  return lines;
}

List<String> _packageBookingServiceIds(STOPackage p, Iterable<String> addonIds) {
  return {...p.includedServiceIds, ...addonIds}.toList();
}

class STODetailScreen extends ConsumerStatefulWidget {
  final STO sto;

  /// Предвыбранные услуги (например, с карточки рекомендации «Замена масла»).
  final List<String>? initialServiceIds;

  /// Если `false`, в предвыборе остаются и «моторное масло», и «масляный фильтр» (запись из напоминаний).
  final bool mergeOilEngineWithFilter;

  const STODetailScreen({
    super.key,
    required this.sto,
    this.initialServiceIds,
    this.mergeOilEngineWithFilter = true,
  });

  @override
  ConsumerState<STODetailScreen> createState() => _STODetailScreenState();
}

class _STODetailScreenState extends ConsumerState<STODetailScreen> {
  final Set<String> _selectedServices = {};
  final TextEditingController _serviceSearchController = TextEditingController();
  bool _showPackages = false;
  /// Нормализованные id каталога из поиска; сопоставляются со строками прайса после загрузки [stoServicesProvider].
  List<String> _pendingCatalogIds = const [];
  bool _didApplyInitialCatalog = false;
  final Map<String, GlobalKey> _serviceRowKeys = {};

  List<String> _normalizedInitialCatalogIds() {
    final raw = widget.initialServiceIds;
    if (raw == null || raw.isEmpty) return const [];
    return normalizeClientServiceFilterIds(
      raw,
      mergeOilEngineWithFilter: widget.mergeOilEngineWithFilter,
    );
  }

  GlobalKey _keyForServiceRow(String serviceId) =>
      _serviceRowKeys.putIfAbsent(serviceId, GlobalKey.new);

  /// Первая строка прайса в порядке списка [services], подходящая под фильтр каталога.
  String? _firstRowIdForCatalogFilter(List<STOService> services, String catalogFilterId) {
    final matchIds = <String>{
      ...stoServiceRowIdsForCatalogFilter(services, catalogFilterId),
      ...stoServiceRowIdsForCatalogFilter(widget.sto.services, catalogFilterId),
    };
    for (final s in services) {
      if (matchIds.contains(s.id)) return s.id;
    }
    return matchIds.isEmpty ? null : matchIds.first;
  }

  bool _sameInitialServiceIds(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    final sa = {...?a};
    final sb = {...?b};
    return sa.length == sb.length && sa.containsAll(sb);
  }

  void _onServiceSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _serviceSearchController.addListener(_onServiceSearchChanged);
    _pendingCatalogIds = _normalizedInitialCatalogIds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryApplyInitialCatalogSelection();
    });
  }

  @override
  void dispose() {
    _serviceSearchController.removeListener(_onServiceSearchChanged);
    _serviceSearchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant STODetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sto.id != widget.sto.id) {
      _selectedServices.clear();
      _serviceSearchController.clear();
      _didApplyInitialCatalog = false;
      _serviceRowKeys.clear();
      _pendingCatalogIds = _normalizedInitialCatalogIds();
    } else if (!_sameInitialServiceIds(oldWidget.initialServiceIds, widget.initialServiceIds) ||
        oldWidget.mergeOilEngineWithFilter != widget.mergeOilEngineWithFilter) {
      _didApplyInitialCatalog = false;
      _pendingCatalogIds = _normalizedInitialCatalogIds();
    } else {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryApplyInitialCatalogSelection();
    });
  }

  void _tryApplyInitialCatalogSelection() {
    if (_didApplyInitialCatalog) return;
    final pending = _pendingCatalogIds;
    if (pending.isEmpty) {
      _didApplyInitialCatalog = true;
      return;
    }
    final asyncState = ref.read(stoServicesProvider(widget.sto.id));
    if (asyncState.isLoading) return;
    if (asyncState.hasError) {
      _didApplyInitialCatalog = true;
      return;
    }
    final services = asyncState.valueOrNull ?? [];
    final toAdd = <String>{};
    for (final fid in pending) {
      toAdd.addAll(stoServiceRowIdsForCatalogFilter(services, fid));
      // Ответ GET /catalog/search уже содержит services; GET organizations/:id/services — тот же прайс.
      // Объединяем id строк, чтобы предвыбор совпадал с фильтром, даже если один из списков без catalog_item_id.
      if (widget.sto.services.isNotEmpty) {
        toAdd.addAll(stoServiceRowIdsForCatalogFilter(widget.sto.services, fid));
      }
    }
    if (toAdd.isNotEmpty) {
      String? scrollToId = _firstRowIdForCatalogFilter(services, pending.first);
      if (scrollToId == null) {
        for (final s in services) {
          if (toAdd.contains(s.id)) {
            scrollToId = s.id;
            break;
          }
        }
      }
      setState(() {
        _selectedServices.addAll(toAdd);
        _showPackages = false;
      });
      if (scrollToId != null) {
        final id = scrollToId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            scrollWidgetToViewportCenter(_keyForServiceRow(id).currentContext);
          });
        });
      }
    }
    _didApplyInitialCatalog = true;
  }

  List<STOService> _filterServicesForSearch(List<STOService> all) {
    final q = _serviceSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) => s.name.toLowerCase().contains(q) || s.category.toLowerCase().contains(q))
        .toList();
  }

  List<STOPackage> _filterPackagesForSearch(List<STOPackage> all, List<STOService> services) {
    final q = _serviceSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    final byId = {for (final s in services) s.id: s};
    return all.where((p) {
      if (p.name.toLowerCase().contains(q)) return true;
      for (final id in p.includedServiceIds) {
        final s = byId[id];
        if (s != null &&
            (s.name.toLowerCase().contains(q) || s.category.toLowerCase().contains(q))) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  STO get _sto => widget.sto;

  Future<void> _openCall() async {
    final phones = _sto.displayPhones;
    if (phones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Нет номера для звонка'),
            backgroundColor: context.palette.error,
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
          backgroundColor: context.palette.cardBg,
          title: Text(
            'Выберите номер',
            style: TextStyle(color: context.palette.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: phones
                .map(
                  (n) => ListTile(
                    title: Text(
                      Formatters.phone(n),
                      style: TextStyle(color: context.palette.textPrimary),
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
            SnackBar(
              content: const Text('Не удалось открыть набор номера'),
              backgroundColor: context.palette.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openChatWithOrganization() async {
    final phoneNorm =
        (ref.read(authProvider).user?.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phoneNorm.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Укажите телефон в профиле, чтобы написать сервису'),
          ),
        );
      }
      return;
    }
    final result =
        await ref.read(chatRepositoryProvider).openOrganizationChat(widget.sto.id);
    if (!mounted) return;
    result.when(
      success: (chat) {
        ref.read(chatsProvider.notifier).loadChats();
        pushCupertino(context, ChatDetailScreen(chat: chat));
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: context.palette.error,
          ),
        );
      },
    );
  }

  void _showOrdersSheet(BuildContext context) {
    final orders =
        (ref.read(ordersProvider).valueOrNull ?? [])
            .where((o) => o.stoId == widget.sto.id)
            .toList()
          ..sort((a, b) => b.timelineSortAt.compareTo(a.timelineSortAt));
    showModalBottomSheet(
      context: context,
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${order.displayStatus.label} · ${Formatters.dateShortRu(order.dateTime)} ${Formatters.time(order.dateTime)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textSecondary,
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

  Future<void> _openRoute() async {
    if (_sto.latitude == null || _sto.longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Нет координат для маршрута'),
            backgroundColor: context.palette.error,
          ),
        );
      }
      return;
    }
    final position = await tryCurrentUserPositionForRoute();
    if (!mounted) return;
    await launchDrivingRoute(
      context,
      ref,
      destLat: _sto.latitude!,
      destLng: _sto.longitude!,
      destinationTitle: _sto.name,
      userPosition: position,
    );
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
    ref.listen<AsyncValue<List<STOService>>>(stoServicesProvider(_sto.id), (prev, next) {
      if (next.isLoading || _didApplyInitialCatalog) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryApplyInitialCatalogSelection();
      });
    });
    final services = ref.watch(stoServicesProvider(_sto.id)).valueOrNull ?? [];
    final packages = ref.watch(stoPackagesProvider(_sto.id)).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: context.palette.background,
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
            context.palette.cardElevated,
            context.palette.nestedBg,
            context.palette.cardBg,
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
          color: context.palette.primary.withValues(alpha: 0.35),
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
      backgroundColor: context.palette.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: context.palette.cardBg,
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
                      colors: [Colors.transparent, context.palette.background],
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
                            ? context.palette.primary
                            : context.palette.textTertiary,
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
          icon: Icon(Icons.list_rounded),
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
                ? context.palette.error
                : context.palette.textPrimary,
          ),
        ),
        IconButton(
          onPressed: _openChatWithOrganization,
          icon: Icon(Icons.chat_bubble_outline_rounded),
          tooltip: 'Написать',
        ),
      ],
    );
  }

  Widget _buildContent(List<STOService> services, List<STOPackage> packages) {
    final sto = widget.sto;
    final filteredServices = _filterServicesForSearch(services);
    final filteredPackages = _filterPackagesForSearch(packages, services);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название + рейтинг (с учётом отзывов пользователей)
          Text(
            sto.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          SizedBox(height: 8),
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
                  Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: context.palette.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    Formatters.rating(rating),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  Text(
                    ' (${Formatters.reviewCount(count)})',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (sto.isOpen ? context.palette.success : context.palette.error)
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
                                ? context.palette.success
                                : context.palette.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          sto.isOpen ? 'Открыто' : 'Закрыто',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sto.isOpen
                                ? context.palette.success
                                : context.palette.error,
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
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: context.palette.textTertiary,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Info rows
          LocationPreviewCard(
            latitude: sto.latitude,
            longitude: sto.longitude,
            staticAddress: sto.address,
            distanceTrailing:
                sto.distanceKm != null ? Formatters.distance(sto.distanceKm!) : null,
          ),
          if (sto.workingHours != null)
            _InfoRow(icon: Icons.access_time_rounded, text: sto.workingHours!),
          if (sto.phone != null)
            _InfoRow(
              icon: Icons.phone_rounded,
              text: Formatters.phone(sto.phone!),
            ),
          SizedBox(height: 12),

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
                      color: context.palette.nestedBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              _ActionChip(
                icon: Icons.phone_rounded,
                label: 'Позвонить',
                onTap: _openCall,
              ),
              SizedBox(width: 8),
              _ActionChip(
                icon: Icons.directions_rounded,
                label: 'Маршрут',
                onTap: _openRoute,
              ),
              SizedBox(width: 8),
              _ActionChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Написать',
                onTap: _openChatWithOrganization,
              ),
            ],
          ),

          SizedBox(height: 24),

          // Услуги
          Text(
            'Услуги',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.palette.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Выберите список услуг или готовый комплекс',
            style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
          ),
          SizedBox(height: 10),
          ServicesPackagesToggle(
            showPackages: _showPackages,
            onToggle: () => setState(() {
              _showPackages = !_showPackages;
              if (_showPackages) {
                _selectedServices.clear();
              }
            }),
          ),
          if (services.isNotEmpty) ...[
            SizedBox(height: 10),
            TextField(
              controller: _serviceSearchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15, color: context.palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск услуги',
                hintStyle: TextStyle(color: context.palette.textTertiary),
                prefixIcon: Icon(Icons.search_rounded, size: 22, color: context.palette.textTertiary),
                suffixIcon: _serviceSearchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Очистить',
                        onPressed: () {
                          _serviceSearchController.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.clear_rounded, size: 20, color: context.palette.textTertiary),
                      )
                    : null,
                filled: true,
                fillColor: context.palette.nestedBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.primary, width: 1.2),
                ),
                isDense: true,
              ),
            ),
          ],
          SizedBox(height: 12),
          _showPackages
              ? _buildPackagesList(services, filteredPackages)
              : _buildServicesList(filteredServices),

          SizedBox(height: 24),

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
      final hasQuery = _serviceSearchController.text.trim().isNotEmpty;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          hasQuery ? 'Ничего не найдено' : 'У сервиса пока нет комплексов',
          style: TextStyle(color: context.palette.textSecondary),
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
        final dur = _packageDurationMinutes(p, services, bodyType);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                final ids = _packageBookingServiceIds(p, const []);
                pushCupertino<String?>(
                  context,
                  _BookingScreen(
                    sto: widget.sto,
                    selectedServiceIds: ids,
                    cars: ref.read(carsProvider).valueOrNull ?? [],
                    packageContext: p,
                    initialAddonServiceIds: const [],
                  ),
                ).then((msg) {
                  if (msg == null || msg.isEmpty) return;
                  _showBookingCreatedSnackBar(msg);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.money(p.packagePriceKopecks),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.palette.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '≈ ${Formatters.durationMinutes(dur)}'
                      '${saving > 0 ? ' · −${Formatters.money(saving)} к раздельной цене' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    if (included.isNotEmpty) ...[
                      SizedBox(height: 8),
                      ...included.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.2,
                                    color: context.palette.textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                Formatters.money(
                                  s.effectivePriceKopecks(bodyType),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                Formatters.durationMinutes(
                                  s.effectiveDurationMinutes(bodyType),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: context.palette.textTertiary,
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
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicesList(List<STOService> services) {
    if (services.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          'Ничего не найдено',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
      );
    }
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.palette.border),
              ),
              child: Column(
                children: entry.value.map((service) {
                  final isSelected = _selectedServices.contains(service.id);
                  return KeyedSubtree(
                    key: _keyForServiceRow(service.id),
                    child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          _selectedServices.remove(service.id);
                        } else {
                          _selectedServices.add(service.id);
                        }
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
                            color: context.palette.border,
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
                                  ? context.palette.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? context.palette.primary
                                    : context.palette.textTertiary,
                                width: isSelected ? 0 : 1.5,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 14,
                                    color: context.palette.onAccent,
                                  )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? context.palette.textPrimary
                                        : context.palette.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '⏱ ${Formatters.durationMinutes(service.effectiveDurationMinutes(_selectedCarBodyType()))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? context.palette.textSecondary
                                        : context.palette.textTertiary,
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
                                  ? context.palette.primary
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddReviewDialog(context, ref, sto),
                  icon: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: context.palette.primary,
                  ),
                  label: Text(
                    'Написать отзыв',
                    style: TextStyle(fontSize: 14, color: context.palette.primary),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (userReviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Пока нет отзывов. Будьте первым!',
                  style: TextStyle(fontSize: 14, color: context.palette.textTertiary),
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
            decoration: BoxDecoration(
              color: context.palette.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Написать отзыв',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  sto.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.textSecondary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Оценка',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
                  ),
                ),
                SizedBox(height: 6),
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
                          color: context.palette.primary,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 16),
                Text(
                  'Текст отзыва',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Опишите ваш опыт...',
                    filled: true,
                    fillColor: context.palette.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.palette.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.textPrimary,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Отмена'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: context.palette.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              final text = textController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Введите текст отзыва'),
                                    backgroundColor: context.palette.error,
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
                                SnackBar(
                                  content: const Text('Отзыв добавлен'),
                                  backgroundColor: context.palette.success,
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
                            child: Text(
                              'Отправить',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.palette.onAccent,
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
        color: context.palette.cardBg,
        border: Border(top: BorderSide(color: context.palette.border)),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textSecondary,
                  ),
                ),
                Text(
                  Formatters.money(_selectedTotal(services)),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.palette.primary,
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
                gradient: context.palette.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: context.palette.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  pushCupertino<String?>(
                    context,
                    _BookingScreen(
                      sto: widget.sto,
                      selectedServiceIds: _selectedServices.toList(),
                      cars: ref.watch(carsProvider).valueOrNull ?? [],
                    ),
                  ).then((msg) {
                    if (msg == null || msg.isEmpty) return;
                    _showBookingCreatedSnackBar(msg);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Записаться',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.palette.onAccent,
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
          Icon(icon, size: 18, color: context.palette.textTertiary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textSecondary,
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
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: context.palette.primary),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.textPrimary,
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
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
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
                  color: context.palette.nestedBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textTertiary,
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
                    color: context.palette.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.palette.textSecondary,
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
  final List<String> selectedServiceIds;
  final List<Car> cars;
  final STOPackage? packageContext;
  final List<String> initialAddonServiceIds;

  const _BookingScreen({
    required this.sto,
    required this.selectedServiceIds,
    required this.cars,
    this.packageContext,
    this.initialAddonServiceIds = const [],
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
  late Set<String> _packageAddonIds;

  List<String> get _timeSlots {
    final r = _slotsResult;
    if (r == null) return buildDaySlotLabels();
    return buildDaySlotLabels(
      slotDurationMinutes: r.slotDurationMinutes,
      workStartMinutes: r.workStartMinutes,
      workEndMinutes: r.workEndMinutes,
    );
  }

  String? _bodyTypeForCar() {
    final cars = widget.cars;
    if (_selectedCarIndex < 0 || _selectedCarIndex >= cars.length) return null;
    return cars[_selectedCarIndex].bodyType;
  }

  List<String> get _allServiceIdsForSlots {
    final pkg = widget.packageContext;
    if (pkg != null) return _packageBookingServiceIds(pkg, _packageAddonIds);
    return widget.selectedServiceIds;
  }

  List<STOService> get _selectedServicesList {
    final services =
        ref.watch(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    final ids = _allServiceIdsForSlots.toSet();
    return services.where((s) => ids.contains(s.id)).toList();
  }

  int get _total {
    final pkg = widget.packageContext;
    final body = _bodyTypeForCar();
    if (pkg != null) {
      return _packageBookingTotalKopecks(pkg, _packageAddonIds);
    }
    return _selectedServicesList.fold(
      0,
      (sum, s) => sum + s.effectivePriceKopecks(body),
    );
  }

  int get _totalDuration {
    final pkg = widget.packageContext;
    final services =
        ref.watch(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    final body = _bodyTypeForCar();
    if (pkg != null) {
      return _packageDurationMinutes(pkg, services, body) +
          _packageAddonsExtraDuration(pkg, _packageAddonIds, services, body);
    }
    return _selectedServicesList.fold(
      0,
      (sum, s) => sum + s.effectiveDurationMinutes(body),
    );
  }

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
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
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
                    leading: Icon(Icons.person_search_rounded),
                    title: Text('Кто угодно из свободных'),
                    subtitle: Text('Мастера назначит сервис'),
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
                      leading: Icon(Icons.person_rounded),
                      title: Text(
                        c.masterName.trim().isNotEmpty
                            ? c.masterName
                            : 'Специалист',
                      ),
                      trailing: Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        apply(c);
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
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
    final servicesNeedingSkill = _selectedServicesList
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
    _packageAddonIds = widget.packageContext != null
        ? Set<String>.from(widget.initialAddonServiceIds)
        : <String>{};
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
      _allServiceIdsForSlots,
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
    // Прайс мог прийти после первого кадра — перезапрашиваем слоты с верной длительностью и раскраской «окон».
    ref.listen<AsyncValue<List<STOService>>>(stoServicesProvider(widget.sto.id), (prev, next) {
      final nextList = next.valueOrNull;
      if (nextList == null || nextList.isEmpty) return;
      final prevList = prev?.valueOrNull;
      if (prevList != null && prevList.isNotEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSlots();
      });
    });

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(
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
                SizedBox(height: 20),

                _buildSectionLabel(
                  widget.packageContext != null ? 'Комплекс' : 'Выбранные услуги',
                ),
                _buildSelectedServices(),
                if (widget.packageContext != null &&
                    widget.packageContext!.addons.isNotEmpty) ...[
                  SizedBox(height: 14),
                  _buildPackageAddonSection(),
                ],
                SizedBox(height: 20),

                // Автомобиль
                _buildSectionLabel('Автомобиль'),
                _buildCarSelector(),
                SizedBox(height: 12),
                _buildVehicleDataConsentTile(),
                if (_provideVehicleData) ...[
                  SizedBox(height: 8),
                  _buildVehicleDataCard(),
                ],
                SizedBox(height: 20),

                // Дата
                _buildSectionLabel('Дата'),
                _buildDateSelector(),
                SizedBox(height: 20),

                // Время (только начала, где помещается весь блок _totalDuration)
                _buildSectionLabel('Время'),
                if (_noMasterWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.palette.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.palette.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: context.palette.error,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _noMasterWarning!,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.palette.textPrimary,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                _buildTimeSelector(),
                SizedBox(height: 20),

                // Комментарий
                _buildSectionLabel('Комментарий (необязательно)'),
                Container(
                  decoration: BoxDecoration(
                    color: context.palette.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Опишите проблему или пожелания...',
                      hintStyle: TextStyle(
                        color: context.palette.textPlaceholder,
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.palette.textSecondary,
        ),
      ),
    );
  }

  Widget _buildVehicleDataConsentTile() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.nestedBg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border.withValues(alpha: 0.75)),
      ),
      child: SwitchTheme(
        data: SwitchThemeData(
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return context.palette.primary.withValues(alpha: 0.35);
            }
            return context.palette.textMuted.withValues(alpha: 0.25);
          }),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return context.palette.primary;
            }
            return context.palette.textMuted;
          }),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 10),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          title: Text(
            'Передать данные авто сервису',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.palette.textPrimary,
            ),
          ),
          subtitle: Text(
            'VIN, пробег и параметры выбранной машины',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: context.palette.textSecondary.withValues(alpha: 0.92),
            ),
          ),
          secondary: Icon(
            Icons.directions_car_filled_outlined,
            size: 22,
            color: context.palette.primary.withValues(alpha: 0.75),
          ),
          value: _provideVehicleData,
          onChanged: (v) => setState(() => _provideVehicleData = v),
        ),
      ),
    );
  }

  Widget _buildSTOInfo() {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.palette.nestedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                widget.sto.name[0],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.palette.primary,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
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
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LocationPreviewCard(
                    compact: true,
                    latitude: widget.sto.latitude,
                    longitude: widget.sto.longitude,
                    staticAddress: widget.sto.address,
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
    final pkg = widget.packageContext;
    final services =
        ref.watch(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    final body = _bodyTypeForCar();

    if (pkg != null) {
      final dur = _packageDurationMinutes(pkg, services, body);
      final byId = {for (final s in services) s.id: s};
      final includedRows = <Widget>[];
      for (final id in pkg.includedServiceIds) {
        final s = byId[id];
        if (s == null) continue;
        includedRows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: context.palette.success.withValues(alpha: 0.85),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        Formatters.durationMinutes(s.effectiveDurationMinutes(body)),
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: context.palette.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '≈ ${Formatters.durationMinutes(dur)} · состав ниже',
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.money(pkg.packagePriceKopecks),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.palette.primary,
                  ),
                ),
              ],
            ),
            if (includedRows.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Divider(height: 1, color: context.palette.border.withValues(alpha: 0.75)),
              ),
              Text(
                'Входит в комплекс',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: context.palette.textTertiary,
                ),
              ),
              ...includedRows,
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: _selectedServicesList
            .map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: context.palette.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          Text(
                            '⏱ ${Formatters.durationMinutes(s.effectiveDurationMinutes(body))}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.money(s.effectivePriceKopecks(body)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
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

  Widget _buildPackageAddonSection() {
    final pkg = widget.packageContext!;
    final services =
        ref.watch(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    final byId = {for (final s in services) s.id: s};
    final body = _bodyTypeForCar();

    final selected = <STOPackageAddon>[];
    final rest = <STOPackageAddon>[];
    for (final a in pkg.addons) {
      if (_packageAddonIds.contains(a.serviceId)) {
        selected.add(a);
      } else {
        rest.add(a);
      }
    }

    void toggleAddon(String serviceId, bool wasOn) {
      setState(() {
        if (wasOn) {
          _packageAddonIds.remove(serviceId);
        } else {
          _packageAddonIds.add(serviceId);
        }
      });
      _loadSlots();
    }

    Widget addonTile(STOPackageAddon a, {required bool isOn}) {
      final s = byId[a.serviceId];
      if (s == null) return const SizedBox.shrink();
      final dm = a.extraDurationMinutes > 0
          ? a.extraDurationMinutes
          : s.effectiveDurationMinutes(body);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => toggleAddon(a.serviceId, isOn),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '+${Formatters.money(a.extraPriceKopecks)} · +${Formatters.durationMinutes(dm)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: (_) => toggleAddon(a.serviceId, isOn),
                  activeTrackColor: context.palette.primary.withValues(alpha: 0.35),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return context.palette.onAccent;
                    }
                    return context.palette.textMuted;
                  }),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget block(String title, List<STOPackageAddon> items, {required bool asSelected, String? empty}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.palette.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (items.isEmpty && empty != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                empty,
                style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.palette.border.withValues(alpha: 0.65)),
                  addonTile(items[i], isOn: asSelected),
                ],
              ],
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border.withValues(alpha: 0.9)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Дополнения',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              Text(
                '${selected.length}/${pkg.addons.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Включаются в запись; время и слоты пересчитаются',
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: context.palette.textTertiary.withValues(alpha: 0.95),
            ),
          ),
          SizedBox(height: 12),
          block(
            'Выбрано',
            selected,
            asSelected: true,
            empty: 'Нет — ниже можно добавить',
          ),
          SizedBox(height: 14),
          block(
            'По желанию',
            rest,
            asSelected: false,
            empty: 'Все опции уже в записи',
          ),
        ],
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
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'VIN:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textSecondary,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vinDisplay,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textPrimary,
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _vehicleDetailsExpanded ? 'Свернуть' : 'Подробнее',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.palette.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    _vehicleDetailsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: context.palette.primary,
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
            SizedBox(height: 8),
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
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textPrimary,
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
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (_, i) {
          final car = cars[i];
          final isSelected = i == _selectedCarIndex;
          return GestureDetector(
            key: GlobalObjectKey(car.id),
            onTap: () {
              setState(() => _selectedCarIndex = i);
              _scrollSelectedCarIntoView();
              _loadSlots();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? context.palette.primary : context.palette.border,
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
                          ? context.palette.primary
                          : context.palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    car.plateNumber ?? '${car.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textSecondary,
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
        separatorBuilder: (_, __) => SizedBox(width: 8),
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
                color: isSelected ? context.palette.primary : context.palette.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? context.palette.primary : context.palette.border,
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
                          ? context.palette.onAccent
                          : context.palette.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? context.palette.onAccent
                          : context.palette.textPrimary,
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
        _selectedTimeSlotIndex < labels.length) {
      final sel = labels[_selectedTimeSlotIndex];
      if (!Formatters.isBookingSlotStartInPastOrNow(_selectedDate, sel)) {
        jobStart = Formatters.dateAtTimeSlot(_selectedDate, sel);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.palette.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Загрузка слотов...',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
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
            final isContinuation = !isPastToday &&
                jobStart != null &&
                slotIsJobContinuation(slot, jobStart, _selectedDate, jobDur);
            final visitStripColor = context.palette.gold2;

            late final Color slotBg;
            late final Color slotBorder;
            late final Color slotText;

            if (isPastToday) {
              slotBg = context.palette.textMuted.withValues(alpha: 0.2);
              slotBorder = context.palette.border.withValues(alpha: 0.45);
              slotText = context.palette.textMuted;
            } else if (isStart) {
              slotBg = context.palette.primary;
              slotBorder = context.palette.primary;
              slotText = context.palette.onAccent;
            } else if (isContinuation) {
              if (isAvailable) {
                slotBg = context.palette.success.withValues(alpha: 0.2);
                slotBorder = context.palette.success;
                slotText = context.palette.success;
              } else if (isOccupied) {
                slotBg = context.palette.error.withValues(alpha: 0.25);
                slotBorder = context.palette.error;
                slotText = context.palette.error;
              } else {
                slotBg = context.palette.nestedBg;
                slotBorder = context.palette.border;
                slotText = context.palette.textTertiary;
              }
            } else if (isAvailable) {
              slotBg = context.palette.success.withValues(alpha: 0.22);
              slotBorder = context.palette.success.withValues(alpha: 0.85);
              slotText = context.palette.success;
            } else if (isOccupied) {
              slotBg = context.palette.error.withValues(alpha: 0.25);
              slotBorder = context.palette.error;
              slotText = context.palette.error;
            } else if (!isPastToday) {
              // Нет свободного окна на это время (не в ответе API) — явно отличимо от «свободно».
              slotBg = context.palette.warning.withValues(alpha: 0.14);
              slotBorder = context.palette.warning.withValues(alpha: 0.45);
              slotText = context.palette.warning;
            } else {
              slotBg = context.palette.nestedBg;
              slotBorder = context.palette.border;
              slotText = context.palette.textTertiary;
            }

            final showVisitStrip = isContinuation;

            return GestureDetector(
              onTap: isDisabled ? null : () => _pickSlot(i, slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 42,
                decoration: BoxDecoration(
                  color: slotBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: slotBorder, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showVisitStrip)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: visitStripColor,
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(top: showVisitStrip ? 2 : 0),
                        child: Text(
                          slot,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: slotText,
                          ),
                        ),
                      ),
                    ],
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
        color: context.palette.cardBg,
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Итого:',
                style: TextStyle(fontSize: 16, color: context.palette.textSecondary),
              ),
              Text(
                Formatters.money(_total),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.palette.primary,
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    if (resourceLine != null) ...[
                      SizedBox(height: 4),
                      Text(
                        resourceLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 12),
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
    final services =
        ref.read(stoServicesProvider(widget.sto.id)).valueOrNull ?? [];
    final pkg = widget.packageContext;
    final body = _bodyTypeForCar();
    final orderLines = pkg != null
        ? _packageOrderLines(pkg, _packageAddonIds, services, body)
        : null;
    final result = await orderRepo.createOrder(
      carId: car.id,
      organizationId: widget.sto.id,
      serviceIds: _allServiceIdsForSlots,
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
      bodyType: _provideVehicleData ? car.bodyType : body,
      color: _provideVehicleData ? car.color : null,
      mileage: _provideVehicleData && car.mileage > 0 ? car.mileage : null,
      engineType: _provideVehicleData ? car.engineType : null,
      carPhotoUrl: _carPhotoUrlForApi(car.photoUrl),
      orderLineItems: orderLines,
    );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.read(ordersProvider.notifier).loadOrders();
        ref.read(chatsProvider.notifier).loadChats();
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        final slot = _timeSlots[_selectedTimeSlotIndex];
        final start = Formatters.dateAtTimeSlot(_selectedDate, slot);
        final end = start?.add(Duration(minutes: _totalDuration));
        final range = (start != null && end != null)
            ? Formatters.bookingRangeLabel(start, end)
            : '${Formatters.dateFullRu(_selectedDate)}, $slot';
        final detail = '${widget.sto.name} · $range · ≈ ${Formatters.durationMinutes(_totalDuration)}';
        // Не вызывать setState перед pop — лишний rebuild + снятие маршрута даёт сбои Overlay (`_elements.contains`).
        Navigator.of(context).pop<String?>('Запись создана!\n$detail');
      },
      failure: (e) {
        if (mounted) setState(() => _isSubmitting = false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: context.palette.error),
        );
      },
    );
  }
}
