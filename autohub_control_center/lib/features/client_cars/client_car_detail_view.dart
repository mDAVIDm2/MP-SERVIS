import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/constants/labels_ru.dart';
import '../../core/theme/app_colors.dart';

/// Карточка авто + история заказов (по смыслу как экран авто в десктопе Business).
class ClientCarDetailView extends ConsumerWidget {
  const ClientCarDetailView({
    super.key,
    required this.clientPhone,
    required this.carId,
    this.showBack = false,
    this.previewCarInfo,
    this.previewClientName,
    this.previewOrdersCount,
    this.previewLastAt,
  });

  final String clientPhone;
  final String carId;
  final bool showBack;
  final String? previewCarInfo;
  final String? previewClientName;
  final String? previewOrdersCount;
  final String? previewLastAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientCarHistoryProvider((clientPhone: clientPhone, carId: carId)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/app/client-cars'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('К списку авто'),
              ),
            ),
          ),
        Expanded(
          child: async.when(
            data: (orders) => SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VehicleSummaryCard(
                    orders: orders,
                    clientPhone: clientPhone,
                    carId: carId,
                    previewCarInfo: previewCarInfo,
                    previewClientName: previewClientName,
                    previewOrdersCount: previewOrdersCount,
                    previewLastAt: previewLastAt,
                  ),
                  const SizedBox(height: 20),
                  _OrdersSectionCard(orders: orders),
                ],
              ),
            ),
            loading: () => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VehicleSummaryCard(
                    orders: const <Map<String, dynamic>>[],
                    clientPhone: clientPhone,
                    carId: carId,
                    previewCarInfo: previewCarInfo,
                    previewClientName: previewClientName,
                    previewOrdersCount: previewOrdersCount,
                    previewLastAt: previewLastAt,
                    loading: true,
                  ),
                  const SizedBox(height: 80),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleSummaryCard extends StatelessWidget {
  const _VehicleSummaryCard({
    required this.orders,
    required this.clientPhone,
    required this.carId,
    this.previewCarInfo,
    this.previewClientName,
    this.previewOrdersCount,
    this.previewLastAt,
    this.loading = false,
  });

  final List<Map<String, dynamic>> orders;
  final String clientPhone;
  final String carId;
  final String? previewCarInfo;
  final String? previewClientName;
  final String? previewOrdersCount;
  final String? previewLastAt;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final o = orders.isNotEmpty ? orders.first : null;
    final carInfo = (o?['car_info'] ?? previewCarInfo)?.toString().trim();
    final title = (carInfo != null && carInfo.isNotEmpty) ? carInfo : 'Автомобиль';
    final vin = o?['vin']?.toString();
    final plate = o?['license_plate']?.toString();
    final body = o?['body_type']?.toString();
    final color = o?['color']?.toString();
    final mileage = o?['mileage'];
    final engine = o?['engine_type']?.toString();
    final clientName = (o?['client_name'] ?? previewClientName)?.toString();
    final phone = (o?['client_phone'] ?? clientPhone).toString();

    final completed = orders.where((x) {
      final s = '${x['status']}'.toLowerCase();
      return s == 'completed' || s == 'done';
    }).length;
    final cancelled = orders.where((x) => '${x['status']}'.toLowerCase() == 'cancelled').length;
    final inFlight = orders.length - completed - cancelled;
    final totalK = _sumOrderKopecks(orders);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (plate != null && plate.isNotEmpty) _copyableLine(context, 'Гос. номер', plate),
                    if (vin != null && vin.isNotEmpty) _copyableLine(context, 'VIN', vin),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _infoRow('Владелец', clientName != null && clientName.isNotEmpty ? clientName : '—'),
          _infoRow('Телефон', _formatPhoneDisplay(phone)),
          if (phone.replaceAll(RegExp(r'\D'), '').length >= 10)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Телефон скопирован'), duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Скопировать номер'),
                ),
              ),
            ),
          if (body != null && body.isNotEmpty) _infoRow('Тип кузова', body),
          if (color != null && color.isNotEmpty) _infoRow('Цвет', color),
          if (mileage != null && '$mileage'.isNotEmpty && '$mileage' != 'null')
            _infoRow('Пробег', '$mileage км'),
          if (engine != null && engine.isNotEmpty) _infoRow('Двигатель', engine),
          _infoRow('ID в приложении', carId),
          if (loading && orders.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Загрузка заказов…',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.85)),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Аналитика',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          _statLine('Всего заказов', orders.isNotEmpty ? '${orders.length}' : (previewOrdersCount ?? '—')),
          if (orders.isNotEmpty) ...[
            _statLine('Выполнено', '$completed', AppColors.success),
            _statLine('В работе / прочее', '$inFlight', const Color(0xFFCA8A04)),
            _statLine('Отменено', '$cancelled', AppColors.danger),
          ],
          if (orders.isNotEmpty && totalK > 0)
            _statLine('Сумма по позициям', _formatRub(totalK), AppColors.primary),
          _statLine(
            'Последний визит',
            orders.isNotEmpty ? _formatDt(orders.first['date_time']) : (previewLastAt ?? '—'),
          ),
        ],
      ),
    );
  }

  static Widget _copyableLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
          IconButton(
            tooltip: 'Копировать',
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: AppColors.textSecondary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label скопирован'), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text('$label:', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  static Widget _statLine(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersSectionCard extends StatelessWidget {
  const _OrdersSectionCard({required this.orders});

  final List<Map<String, dynamic>> orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Заказы по этому автомобилю',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Раскройте заказ, чтобы увидеть работы и комментарий.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('Нет заказов', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...orders.map((o) => _OrderExpansionTile(order: o)),
        ],
      ),
    );
  }
}

class _OrderExpansionTile extends StatelessWidget {
  const _OrderExpansionTile({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String?;
    final statusColor = _orderStatusColor(status);
    final items = order['items'] is List ? order['items'] as List : <dynamic>[];
    final services = items.map((it) {
      if (it is! Map) return '';
      final m = Map<String, dynamic>.from(it);
      final name = m['name'] ?? '—';
      final add = m['is_additional'] == true ? ' (доп.)' : '';
      final done = m['is_completed'] == true ? ' ✓' : '';
      return '$name$add$done';
    }).where((s) => s.isNotEmpty).join(', ');

    final org = order['organization_name']?.toString() ?? '—';
    final master = order['master_name']?.toString();
    final addr = order['organization_address']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _shortOrderNo(order['order_number']?.toString() ?? '—'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ),
            title: Text(
              LabelsRu.orderStatus(status),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDt(order['date_time']),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(org, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (master != null && master.isNotEmpty)
                    Text('Мастер: $master', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  'Организация: $org\n'
                  '${addr != null && addr.isNotEmpty ? 'Адрес: $addr\n' : ''}'
                  'Работы: ${services.isEmpty ? '—' : services}\n'
                  'Комментарий: ${order['comment'] ?? '—'}',
                  style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _orderStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'completed':
    case 'done':
      return AppColors.success;
    case 'cancelled':
      return AppColors.danger;
    case 'in_progress':
      return const Color(0xFFCA8A04);
    case 'pending_approval':
      return const Color(0xFFEA580C);
    case 'pending_confirmation':
      return AppColors.textSecondary;
    case 'confirmed':
      return AppColors.primary;
    default:
      return AppColors.primary;
  }
}

String _shortOrderNo(String raw) {
  final parts = raw.split('-');
  if (parts.length > 1 && parts.last.length <= 6) return '#${parts.last}';
  if (raw.length > 8) return '#${raw.substring(raw.length - 6)}';
  return raw;
}

String _formatDt(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return DateFormat('dd.MM.yyyy HH:mm').format(d.toLocal());
}

String _formatPhoneDisplay(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('7')) {
    return '+7 (${d.substring(1, 4)}) ${d.substring(4, 7)}-${d.substring(7, 9)}-${d.substring(9)}';
  }
  return raw.isEmpty ? '—' : raw;
}

int _sumOrderKopecks(List<Map<String, dynamic>> orders) {
  var s = 0;
  for (final o in orders) {
    final items = o['items'];
    if (items is! List) continue;
    for (final it in items) {
      if (it is Map && it['price_kopecks'] != null) {
        s += (it['price_kopecks'] as num).toInt();
      }
    }
  }
  return s;
}

String _formatRub(int kopecks) {
  final rub = kopecks / 100.0;
  final whole = rub == rub.roundToDouble();
  return '${NumberFormat.decimalPattern('ru_RU').format(whole ? rub.round() : rub)} ₽';
}
