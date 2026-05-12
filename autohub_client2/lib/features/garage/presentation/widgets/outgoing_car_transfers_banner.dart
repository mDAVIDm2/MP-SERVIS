import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/client_palette.dart';

/// Исходящие запросы передачи (ожидают ответа) — отмена с гаража.
class OutgoingCarTransfersBanner extends ConsumerWidget {
  const OutgoingCarTransfersBanner({super.key, required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = items.where((m) => (m['status'] as String?) == 'pending').toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.outbox_rounded, color: p.textSecondary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ожидают ответа',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...pending.map((t) => _OutgoingRow(transfer: t)),
        ],
      ),
    );
  }
}

class _OutgoingRow extends ConsumerWidget {
  const _OutgoingRow({required this.transfer});

  final Map<String, dynamic> transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final id = transfer['id'] as String? ?? '';
    final label = transfer['car_label'] as String? ?? 'Автомобиль';
    final api = ref.read(carTransferApiServiceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Получатель должен принять или отклонить запрос в приложении.',
            style: TextStyle(fontSize: 12, color: p.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: id.isEmpty
                  ? null
                  : () async {
                      final r = await api.cancel(id);
                      if (!context.mounted) return;
                      if (r.errorOrNull == null) {
                        ref.invalidate(outgoingCarTransfersProvider);
                        ref.invalidate(incomingCarTransfersProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Запрос отменён')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(r.errorOrNull?.message ?? 'Не удалось отменить')),
                        );
                      }
                    },
              child: Text('Отменить запрос', style: TextStyle(color: p.error)),
            ),
          ),
        ],
      ),
    );
  }
}
