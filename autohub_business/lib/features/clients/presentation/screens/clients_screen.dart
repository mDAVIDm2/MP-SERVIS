import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/utils/client_avatar_from_chats.dart';
import '../../../../shared/models/order_model.dart';
import '../../../chats/presentation/widgets/authenticated_profile_avatar.dart';
import 'client_detail_screen.dart';

/// Список клиентов организации (уникальные по заказам).
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key, this.embeddedInOrganizationCard = false});

  /// В карточке организации на профиле — без верхнего AppBar.
  final bool embeddedInOrganizationCard;

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _ordersWord(int n) {
    final m = n % 100;
    if (m >= 11 && m <= 14) return 'заказов';
    switch (n % 10) {
      case 1:
        return 'заказ';
      case 2:
      case 3:
      case 4:
        return 'заказа';
      default:
        return 'заказов';
    }
  }

  static DateTime? _lastVisit(List<Order> orders) {
    DateTime? best;
    for (final o in orders) {
      final t = o.effectiveDateTime;
      if (best == null || t.isAfter(best)) best = t;
    }
    return best;
  }

  List<_ClientInfo> _filterClients(List<_ClientInfo> clients, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients.where((c) {
      if (c.name.toLowerCase().contains(q)) return true;
      final p = c.phone?.toLowerCase() ?? '';
      return p.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderRepositoryProvider);
    final chatPreviews = ref.watch(chatRepositoryProvider).chats;
    final clients = _clientsFromOrders(orders);
    final desktop = isDesktopPlatform;
    final c = _ClientUiColors.desktop(desktop);

    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              return TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Поиск по имени или телефону',
                  hintStyle: TextStyle(color: c.hint),
                  prefixIcon: Icon(Icons.search_rounded, size: 22, color: c.iconMuted),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Очистить',
                          icon: Icon(Icons.clear_rounded, color: c.iconMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: c.fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.focusBorder, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              if (clients.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 56,
                          color: c.iconMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет клиентов',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Клиенты появятся из заказов',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final filtered = _filterClients(clients, _searchController.text);
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'Никого не нашли',
                    style: TextStyle(color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final cl = filtered[i];
                  final last = _lastVisit(cl.orders);
                  final subtitle = last != null
                      ? '${cl.orderCount} ${_ordersWord(cl.orderCount)} · ${formatDateShort(last)}'
                      : '${cl.orderCount} ${_ordersWord(cl.orderCount)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: desktop ? 0 : 0,
                    color: c.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: c.cardBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        final avatarUrl = resolvedClientAvatarUrl(
                          chats: chatPreviews,
                          orderClientAvatarUrl: cl.clientAvatarUrl,
                          clientPhone: cl.phone,
                        );
                        final page = ClientDetailScreen(
                          clientName: cl.name,
                          clientPhone: cl.phone,
                          clientAvatarUrl: avatarUrl,
                          orders: cl.orders,
                          useDesktopLightUi: desktop,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => desktop ? themeDesktopLight(child: page) : page,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AuthenticatedProfileAvatar(
                              imageUrl: resolvedClientAvatarUrl(
                                chats: chatPreviews,
                                orderClientAvatarUrl: cl.clientAvatarUrl,
                                clientPhone: cl.phone,
                              ),
                              fallbackLetter: cl.name.isNotEmpty ? cl.name[0] : '?',
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cl.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  if (cl.phone != null && cl.phone!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          size: 15,
                                          color: c.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            cl.phone!.trim(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: c.textTertiary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: c.chevron,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (desktop) {
      column = themeDesktopLight(
        child: ColoredBox(color: c.scaffoldBg, child: column),
      );
    }

    if (widget.embeddedInOrganizationCard) {
      return ColoredBox(color: c.scaffoldBg, child: column);
    }

    // Десктоп: заголовок «Клиенты» только в верхней полосе MainShell — без второго AppBar.
    if (desktop) {
      return Scaffold(
        backgroundColor: c.scaffoldBg,
        body: column,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Клиенты'),
      ),
      body: column,
    );
  }
}

class _ClientUiColors {
  _ClientUiColors({
    required this.scaffoldBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hint,
    required this.iconMuted,
    required this.fieldFill,
    required this.border,
    required this.focusBorder,
    required this.cardBg,
    required this.cardBorder,
    required this.avatarBg,
    required this.avatarFg,
    required this.chevron,
  });

  final Color scaffoldBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color hint;
  final Color iconMuted;
  final Color fieldFill;
  final Color border;
  final Color focusBorder;
  final Color cardBg;
  final Color cardBorder;
  final Color avatarBg;
  final Color avatarFg;
  final Color chevron;

  factory _ClientUiColors.desktop(bool desktop) {
    if (desktop) {
      return _ClientUiColors(
        scaffoldBg: AppColorsDesktop.background,
        textPrimary: AppColorsDesktop.textPrimary,
        textSecondary: AppColorsDesktop.textSecondary,
        textTertiary: AppColorsDesktop.textTertiary,
        hint: AppColorsDesktop.textPlaceholder,
        iconMuted: AppColorsDesktop.textTertiary.withValues(alpha: 0.75),
        fieldFill: AppColorsDesktop.nestedBg.withValues(alpha: 0.65),
        border: AppColorsDesktop.border,
        focusBorder: AppColorsDesktop.primary,
        cardBg: AppColorsDesktop.surface,
        cardBorder: AppColorsDesktop.border,
        avatarBg: AppColorsDesktop.primary.withValues(alpha: 0.12),
        avatarFg: AppColorsDesktop.primary,
        chevron: AppColorsDesktop.textTertiary.withValues(alpha: 0.75),
      );
    }
    return _ClientUiColors(
      scaffoldBg: AppColors.background,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textTertiary: AppColors.textTertiary,
      hint: AppColors.textTertiary.withValues(alpha: 0.9),
      iconMuted: AppColors.textTertiary.withValues(alpha: 0.9),
      fieldFill: AppColors.nestedBg,
      border: AppColors.border.withValues(alpha: 0.85),
      focusBorder: AppColors.primary.withValues(alpha: 0.65),
      cardBg: AppColors.cardBg,
      cardBorder: AppColors.border.withValues(alpha: 0.9),
      avatarBg: AppColors.primary.withValues(alpha: 0.14),
      avatarFg: AppColors.primary.withValues(alpha: 0.95),
      chevron: AppColors.textTertiary.withValues(alpha: 0.75),
    );
  }
}

class _ClientInfo {
  final String name;
  final String? phone;
  /// С любого заказа клиента (API `client_avatar_url`).
  final String? clientAvatarUrl;
  final int orderCount;
  final List<Order> orders;

  _ClientInfo({
    required this.name,
    this.phone,
    this.clientAvatarUrl,
    required this.orderCount,
    required this.orders,
  });
}

List<_ClientInfo> _clientsFromOrders(List<Order> orders) {
  final map = <String, _ClientInfo>{};
  for (final o in orders) {
    final name = o.clientName ?? 'Клиент';
    final key = '${name}_${o.clientPhone ?? ''}';
    if (map.containsKey(key)) {
      final existing = map[key]!;
      map[key] = _ClientInfo(
        name: existing.name,
        phone: existing.phone,
        clientAvatarUrl: existing.clientAvatarUrl ?? o.clientAvatarUrl,
        orderCount: existing.orderCount + 1,
        orders: [...existing.orders, o],
      );
    } else {
      map[key] = _ClientInfo(
        name: name,
        phone: o.clientPhone,
        clientAvatarUrl: o.clientAvatarUrl,
        orderCount: 1,
        orders: [o],
      );
    }
  }
  final list = map.values.toList();
  list.sort((a, b) => b.orderCount.compareTo(a.orderCount));
  return list;
}
