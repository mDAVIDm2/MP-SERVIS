import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/sync/client_app_state_sync.dart';
import '../../../../core/theme/client_palette.dart';

/// Баннер входящих запросов на передачу авто (на вкладке «Гараж»).
class IncomingCarTransfersBanner extends ConsumerWidget {
  const IncomingCarTransfersBanner({super.key, required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forward_to_inbox_rounded, color: p.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Запросы на передачу авто',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((t) => _TransferRow(transfer: t)),
        ],
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.transfer});

  final Map<String, dynamic> transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final id = transfer['id'] as String? ?? '';
    final label = transfer['car_label'] as String? ?? 'Автомобиль';
    final api = ref.read(carTransferApiServiceProvider);

    Future<void> onAccept() async {
      final r = await api.accept(id);
      if (!context.mounted) return;
      if (r.errorOrNull == null) {
        ref.invalidate(incomingCarTransfersProvider);
        ref.invalidate(outgoingCarTransfersProvider);
        await ref.read(carsProvider.notifier).loadCars(silent: true);
        await ref.read(ordersProvider.notifier).loadOrders();
        await ref.read(clientAppStateSyncServiceProvider).pullAfterLogin();
        ref.invalidate(maintenanceRemindersProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Автомобиль добавлен в ваш гараж')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.errorOrNull?.message ?? 'Не удалось принять')),
        );
      }
    }

    Future<void> onReject() async {
      final r = await api.reject(id);
      if (!context.mounted) return;
      if (r.errorOrNull == null) {
        ref.invalidate(incomingCarTransfersProvider);
        ref.invalidate(outgoingCarTransfersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запрос отклонён')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.errorOrNull?.message ?? 'Не удалось отклонить')),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: id.isEmpty ? null : onAccept,
                  child: const Text('Принять'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: id.isEmpty ? null : onReject,
                  child: const Text('Отклонить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
