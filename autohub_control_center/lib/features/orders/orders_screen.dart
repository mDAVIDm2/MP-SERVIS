import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/constants/labels_ru.dart';
import '../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _search = TextEditingController();
  String? _statusFilter;

  static const _statusKeys = <String>[
    'pending_confirmation',
    'confirmed',
    'in_progress',
    'pending_approval',
    'completed',
    'cancelled',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const params = (limit: 500, offset: 0);
    final async = ref.watch(ordersProvider(params));
    return SectionScaffold(
      expandBody: true,
      title: 'Заказы',
      titleActions: [
        IconButton(
          tooltip: 'Обновить сейчас',
          onPressed: () => ref.invalidate(ordersProvider(params)),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: async.when(
        data: (data) {
          final raw = _extractOrdersList(data);
          final total = _extractOrdersTotal(data, raw.length);
          final maps = raw.map((e) {
            if (e is! Map) return <String, dynamic>{};
            return Map<String, dynamic>.from(e);
          }).toList();
          final q = _search.text.trim().toLowerCase();
          final filtered = maps.where((m) {
            if (_statusFilter != null && '${m['status']}'.toLowerCase() != _statusFilter) return false;
            if (q.isEmpty) return true;
            final bucket = [
              '${m['order_number']}',
              '${m['organization_name']}',
              '${m['client_name']}',
              '${m['client_phone']}',
              '${m['car_info']}',
              '${m['license_plate']}',
              '${m['vin']}',
              '${m['master_name']}',
              LabelsRu.orderStatus(m['status'] as String?),
            ].join(' ').toLowerCase();
            return bucket.contains(q);
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OrdersToolbar(
                searchController: _search,
                onSearchChanged: () => setState(() {}),
                totalAll: total,
                shown: filtered.length,
                statusFilter: _statusFilter,
                onStatus: (s) => setState(() => _statusFilter = s),
                statusKeys: _statusKeys,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _OrdersEmpty(hasOrders: maps.isNotEmpty),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          return RepaintBoundary(
                            child: _OrderCard(order: filtered[i]),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _OrdersError(message: '$e', onRetry: () => ref.invalidate(ordersProvider(params))),
      ),
    );
  }
}

class _OrdersToolbar extends StatelessWidget {
  const _OrdersToolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.totalAll,
    required this.shown,
    required this.statusFilter,
    required this.onStatus,
    required this.statusKeys,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final int totalAll;
  final int shown;
  final String? statusFilter;
  final void Function(String?) onStatus;
  final List<String> statusKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: 'Номер заказа, организация, клиент, авто…',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _OrdersCountBadge(total: totalAll, shown: shown),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Все'),
                selected: statusFilter == null,
                showCheckmark: false,
                onSelected: (_) => onStatus(null),
              ),
              const SizedBox(width: 8),
              for (final k in statusKeys) ...[
                FilterChip(
                  label: Text(LabelsRu.orderStatus(k)),
                  selected: statusFilter == k,
                  showCheckmark: false,
                  onSelected: (_) => onStatus(statusFilter == k ? null : k),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _OrdersCountBadge extends StatelessWidget {
  const _OrdersCountBadge({required this.total, required this.shown});

  final int total;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$shown',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          Text(
            shown == total ? 'заказов' : 'из $total',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusStyle {
  const _OrderStatusStyle({required this.color, required this.bg, required this.icon});

  final Color color;
  final Color bg;
  final IconData icon;

  static _OrderStatusStyle forStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_confirmation':
        return const _OrderStatusStyle(
          color: Color(0xFFD97706),
          bg: Color(0xFFFFFBEB),
          icon: Icons.schedule_rounded,
        );
      case 'confirmed':
        return _OrderStatusStyle(
          color: AppColors.primary,
          bg: AppColors.primary.withValues(alpha: 0.08),
          icon: Icons.check_circle_outline_rounded,
        );
      case 'in_progress':
        return const _OrderStatusStyle(
          color: Color(0xFF7C3AED),
          bg: Color(0xFFF5F3FF),
          icon: Icons.engineering_outlined,
        );
      case 'pending_approval':
        return const _OrderStatusStyle(
          color: Color(0xFFEA580C),
          bg: Color(0xFFFFF7ED),
          icon: Icons.help_outline_rounded,
        );
      case 'completed':
      case 'done':
        return const _OrderStatusStyle(
          color: Color(0xFF15803D),
          bg: Color(0xFFF0FDF4),
          icon: Icons.verified_rounded,
        );
      case 'cancelled':
        return _OrderStatusStyle(
          color: AppColors.danger,
          bg: AppColors.danger.withValues(alpha: 0.08),
          icon: Icons.cancel_outlined,
        );
      default:
        return const _OrderStatusStyle(
          color: AppColors.textSecondary,
          bg: AppColors.background,
          icon: Icons.receipt_long_outlined,
        );
    }
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Map<String, dynamic> order;

  static String _formatDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    final local = d.toLocal();
    return DateFormat('dd.MM.yyyy HH:mm').format(local);
  }

  static String _formatPhone(String? p) {
    if (p == null || p.trim().isEmpty) return '—';
    final d = p.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('8')) {
      return '+7 ${d.substring(1, 4)} ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
    }
    if (d.length == 11 && d.startsWith('7')) {
      return '+7 ${d.substring(1, 4)} ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
    }
    return p;
  }

  static String _formatRubFromKopecks(int kopecks) {
    final rub = kopecks / 100.0;
    final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: rub == rub.roundToDouble() ? 0 : 2);
    return fmt.format(rub);
  }

  static String _pluralPositions(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'позиций';
    if (m10 == 1) return 'позиция';
    if (m10 >= 2 && m10 <= 4) return 'позиции';
    return 'позиций';
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String?;
    final st = _OrderStatusStyle.forStatus(status);
    final label = LabelsRu.orderStatus(status);
    final items = order['items'] is List ? order['items'] as List : <dynamic>[];
    var sumKop = 0;
    for (final it in items) {
      if (it is Map && it['price_kopecks'] != null) {
        sumKop += (it['price_kopecks'] as num).toInt();
      }
    }
    final names = items
        .map((it) => it is Map ? '${it['name'] ?? ''}' : '')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final preview = names.length <= 2 ? names.join(' · ') : '${names.take(2).join(' · ')} +${names.length - 2}';

    final plate = order['license_plate']?.toString();
    final vin = order['vin']?.toString();
    final carInfo = order['car_info']?.toString() ?? '';
    final hasCar = carInfo.isNotEmpty || (plate != null && plate.isNotEmpty) || (vin != null && vin.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: ColoredBox(color: st.color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${order['order_number'] ?? '—'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(order['date_time']),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: st.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: st.color.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(st.icon, size: 18, color: st.color),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: st.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (order['previous_status'] != null && '${order['previous_status']}'.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Было: ${LabelsRu.orderStatus(order['previous_status'] as String?)}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.9)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoPill(
                          icon: Icons.storefront_outlined,
                          text: '${order['organization_name'] ?? '—'}',
                        ),
                        _InfoPill(
                          icon: Icons.person_outline_rounded,
                          text: '${order['client_name'] ?? '—'}',
                        ),
                        _InfoPill(
                          icon: Icons.phone_iphone_rounded,
                          text: _formatPhone(order['client_phone'] as String?),
                        ),
                        if (order['master_name'] != null && '${order['master_name']}'.trim().isNotEmpty)
                          _InfoPill(
                            icon: Icons.handyman_outlined,
                            text: '${order['master_name']}',
                          ),
                      ],
                    ),
                    if (hasCar) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.directions_car_filled_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Автомобиль',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ],
                            ),
                            if (carInfo.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(carInfo, style: const TextStyle(fontSize: 14)),
                            ],
                            if (plate != null && plate.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Госномер: $plate', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                            if (vin != null && vin.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              SelectableText(
                                'VIN: $vin',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (order['planned_start_time'] != null || order['planned_end_time'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.event_available_outlined, size: 16, color: AppColors.textSecondary.withValues(alpha: 0.85)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'План: ${_formatDate(order['planned_start_time'])} — ${_formatDate(order['planned_end_time'])}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${items.length} ${_pluralPositions(items.length)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                if (preview.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final it in items.take(6))
                                      if (it is Map && '${it['name'] ?? ''}'.trim().isNotEmpty)
                                        _MiniChip(
                                          label: '${it['name']}',
                                          done: it['is_completed'] == true,
                                          extra: it['is_additional'] == true,
                                        ),
                                    if (items.length > 6)
                                      _MiniChip(label: '+${items.length - 6}', done: false, extra: false),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (sumKop > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _formatRubFromKopecks(sumKop),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (order['comment'] != null && '${order['comment']}'.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFFFFBEB),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded, size: 18, color: Color(0xFFB45309)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${order['comment']}',
                                style: const TextStyle(fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.done, required this.extra});

  final String label;
  final bool done;
  final bool extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: extra
            ? const Color(0xFFFFF7ED)
            : (done ? const Color(0xFFF0FDF4) : AppColors.background),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: extra
              ? const Color(0xFFFDBA74)
              : (done ? AppColors.success.withValues(alpha: 0.45) : AppColors.border),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: extra ? const Color(0xFFC2410C) : (done ? const Color(0xFF15803D) : AppColors.textSecondary),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.hasOrders});

  final bool hasOrders;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasOrders ? Icons.search_off_rounded : Icons.receipt_long_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 16),
                Text(
                  hasOrders ? 'Ничего не найдено' : 'Заказов пока нет',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (hasOrders)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Попробуйте другой запрос или фильтр.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Ошибка загрузки заказов', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              SelectableText(message, style: const TextStyle(color: AppColors.danger, height: 1.4)),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<dynamic> _extractOrdersList(Map<String, dynamic> data) {
  var raw = data['items'];
  if (raw is! List) {
    final inner = data['data'];
    if (inner is Map && inner['items'] is List) {
      raw = inner['items'];
    }
  }
  if (raw is! List && data['orders'] is List) {
    raw = data['orders'];
  }
  if (raw is! List) return [];
  return raw;
}

int _extractOrdersTotal(Map<String, dynamic> data, int itemsLen) {
  final t = data['total'];
  if (t is int) return t;
  if (t is num) return t.round();
  return itemsLen;
}
