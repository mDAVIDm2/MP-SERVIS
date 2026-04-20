import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/constants/labels_ru.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_url_resolver.dart';
import '../../shared/widgets/cc_auth_network_image.dart';

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
    /// Десктоп: после полного удаления сбросить выбор в [ClientCarsScreen], иначе панель деталей
    /// остаётся с тем же car_id и [ref.invalidate] ломает дерево виджетов (`_dependents.isEmpty`).
    this.onAfterHardDeleteSuccess,
  });

  final String clientPhone;
  final String carId;
  final bool showBack;
  final String? previewCarInfo;
  final String? previewClientName;
  final String? previewOrdersCount;
  final String? previewLastAt;
  final VoidCallback? onAfterHardDeleteSuccess;

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
                  const SizedBox(height: 16),
                  _ModerationCard(clientPhone: clientPhone, carId: carId),
                  const SizedBox(height: 16),
                  _CarLifecycleCard(
                    clientPhone: clientPhone,
                    carId: carId,
                    onAfterHardDeleteSuccess: onAfterHardDeleteSuccess,
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

class _CarLifecycleCard extends ConsumerWidget {
  const _CarLifecycleCard({
    required this.clientPhone,
    required this.carId,
    this.onAfterHardDeleteSuccess,
  });

  final String clientPhone;
  final String carId;
  final VoidCallback? onAfterHardDeleteSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Гараж и заказы (разработчики)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Скрытие: данные в БД сохраняются, клиент не видит авто и заказы с этим car_id. Полное удаление — безвозвратно.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Скрыть у клиента?'),
                      content: const Text(
                        'Авто и все заказы с этим car_id перестанут отображаться в клиентском приложении. В БД всё останется.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Скрыть')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final api = ref.read(internalApiProvider);
                  final r = await api.hideClientCarFromUser(clientPhone, carId);
                  ref.invalidate(clientCarsProvider);
                  ref.invalidate(clientCarHistoryProvider((clientPhone: clientPhone, carId: carId)));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          r.ok ? 'Скрыто у клиента' : (r.error ?? 'Ошибка запроса'),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Скрыть у клиента'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final api = ref.read(internalApiProvider);
                  final r = await api.restoreClientCarForUser(clientPhone, carId);
                  ref.invalidate(clientCarsProvider);
                  ref.invalidate(clientCarHistoryProvider((clientPhone: clientPhone, carId: carId)));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          r.ok ? 'Снова видно клиенту' : (r.error ?? 'Ошибка запроса'),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Вернуть отображение'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () async {
                  final controller = TextEditingController();
                  final typed = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Полное удаление'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Будут удалены все заказы с этим car_id и запись в гараже (если есть). Введите DELETE для подтверждения.',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              labelText: 'Подтверждение',
                              border: OutlineInputBorder(),
                            ),
                            autocorrect: false,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          child: const Text('Удалить навсегда'),
                        ),
                      ],
                    ),
                  ).whenComplete(controller.dispose);
                  if (!context.mounted) return;
                  if (typed != 'DELETE') {
                    if (typed != null && typed.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Нужно ввести DELETE')),
                      );
                    }
                    return;
                  }
                  if (!context.mounted) return;
                  final container = ProviderScope.containerOf(context, listen: false);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final router = GoRouter.maybeOf(context);
                  final api = ref.read(internalApiProvider);
                  final r = await api.hardDeleteClientCar(clientPhone, carId, confirm: 'DELETE');
                  if (!r.ok) {
                    container.invalidate(clientCarsProvider);
                    container.invalidate(clientCarHistoryProvider((clientPhone: clientPhone, carId: carId)));
                    messenger?.showSnackBar(
                      SnackBar(content: Text(r.error ?? 'Ошибка запроса')),
                    );
                    return;
                  }

                  messenger?.showSnackBar(const SnackBar(content: Text('Удалено из БД')));

                  onAfterHardDeleteSuccess?.call();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    container.invalidate(clientCarsProvider);
                    if (onAfterHardDeleteSuccess == null) {
                      router?.go('/app/client-cars');
                    }
                  });
                },
                child: const Text('Удалить из БД'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModerationCard extends ConsumerWidget {
  const _ModerationCard({required this.clientPhone, required this.carId});

  final String clientPhone;
  final String carId;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required bool vin,
    required bool licensePlate,
    required bool carInfo,
    required bool carPhotoUrl,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(internalApiProvider);
    final success = await api.moderateClearClientCar(
      clientPhone,
      carId,
      vin: vin,
      licensePlate: licensePlate,
      carInfo: carInfo,
      carPhotoUrl: carPhotoUrl,
    );
    ref.invalidate(clientCarsProvider);
    ref.invalidate(clientCarHistoryProvider((clientPhone: clientPhone, carId: carId)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Данные очищены в заказах' : 'Ошибка запроса')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Модерация (разработчики)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Очистка полей во всех заказах с этим телефоном и car_id.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _run(context, ref,
                    title: 'Очистить VIN?',
                    message: 'VIN будет удалён из всех связанных заказов.',
                    vin: true,
                    licensePlate: false,
                    carInfo: false,
                    carPhotoUrl: false),
                child: const Text('VIN'),
              ),
              OutlinedButton(
                onPressed: () => _run(context, ref,
                    title: 'Очистить госномер?',
                    message: 'Номер будет удалён из всех связанных заказов.',
                    vin: false,
                    licensePlate: true,
                    carInfo: false,
                    carPhotoUrl: false),
                child: const Text('Госномер'),
              ),
              OutlinedButton(
                onPressed: () => _run(context, ref,
                    title: 'Очистить описание авто?',
                    message: 'Текст car_info будет очищен.',
                    vin: false,
                    licensePlate: false,
                    carInfo: true,
                    carPhotoUrl: false),
                child: const Text('Описание'),
              ),
              OutlinedButton(
                onPressed: () => _run(context, ref,
                    title: 'Убрать фото авто?',
                    message: 'Ссылки на фото в заказах будут удалены.',
                    vin: false,
                    licensePlate: false,
                    carInfo: false,
                    carPhotoUrl: true),
                child: const Text('Фото авто'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => _run(context, ref,
                    title: 'Очистить всё по авто?',
                    message: 'VIN, госномер, описание и фото авто в заказах будут очищены.',
                    vin: true,
                    licensePlate: true,
                    carInfo: true,
                    carPhotoUrl: true),
                child: const Text('Всё сразу'),
              ),
            ],
          ),
        ],
      ),
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

  static String? _firstCarPhotoUrl(List<Map<String, dynamic>> orders) {
    for (final x in orders) {
      final u = x['car_photo_url']?.toString().trim();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

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
    final carPhotoUrl = internalClientCarPhotoImageUrl(_firstCarPhotoUrl(orders));
    final carThumbPlaceholder = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 32),
    );

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
              if (carPhotoUrl != null)
                CcAuthNetworkImage(
                  url: carPhotoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(14),
                  placeholder: carThumbPlaceholder,
                )
              else
                carThumbPlaceholder,
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
