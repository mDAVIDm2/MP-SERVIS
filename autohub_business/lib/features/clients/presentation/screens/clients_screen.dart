import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import 'client_detail_screen.dart';

/// Список клиентов организации (уникальные по заказам).
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

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
    if (orders.isEmpty) return null;
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
    final clients = _clientsFromOrders(orders);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Клиенты'),
      ),
      body: Column(
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
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Поиск по имени или телефону',
                    hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.9)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Очистить',
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.nestedBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.65), width: 1.5),
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
                            color: AppColors.textTertiary.withValues(alpha: 0.65),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет клиентов',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Клиенты появятся из заказов',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary.withValues(alpha: 0.95),
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
                      style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    final last = _lastVisit(c.orders);
                    final subtitle = last != null
                        ? '${c.orderCount} ${_ordersWord(c.orderCount)} · ${formatDateShort(last)}'
                        : '${c.orderCount} ${_ordersWord(c.orderCount)}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientDetailScreen(
                              clientName: c.name,
                              clientPhone: c.phone,
                              orders: c.orders,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                child: Text(
                                  (c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary.withValues(alpha: 0.95),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (c.phone != null && c.phone!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            size: 15,
                                            color: AppColors.textTertiary.withValues(alpha: 0.9),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              c.phone!.trim(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textTertiary.withValues(alpha: 0.95),
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
                                color: AppColors.textTertiary.withValues(alpha: 0.75),
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
      ),
    );
  }
}

class _ClientInfo {
  final String name;
  final String? phone;
  final int orderCount;
  final List<Order> orders;

  _ClientInfo({
    required this.name,
    this.phone,
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
        orderCount: existing.orderCount + 1,
        orders: [...existing.orders, o],
      );
    } else {
      map[key] = _ClientInfo(
        name: name,
        phone: o.clientPhone,
        orderCount: 1,
        orders: [o],
      );
    }
  }
  final list = map.values.toList();
  list.sort((a, b) => b.orderCount.compareTo(a.orderCount));
  return list;
}
