import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditProvider(const (limit: 100, offset: 0, from: null, to: null)));
    return SectionScaffold(
      title: 'Аудит',
      child: async.when(
        data: (data) {
          final items = data['items'] is List ? data['items'] as List : <dynamic>[];
          if (items.isEmpty) {
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Нет записей', style: TextStyle(color: AppColors.textSecondary))),
              ),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surface),
              columns: const [
                DataColumn(label: Text('Время')),
                DataColumn(label: Text('Действие')),
                DataColumn(label: Text('Актор')),
                DataColumn(label: Text('Ресурс')),
              ],
              rows: items.map((e) {
                final map = e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};
                final createdAt = map['created_at'];
                final timeStr = _formatDate(createdAt);
                final resource = '${map['resource_type'] ?? ''} ${map['resource_id'] ?? ''}'.trim();
                return DataRow(
                  cells: [
                    DataCell(Text(timeStr, overflow: TextOverflow.ellipsis)),
                    DataCell(Text('${map['action'] ?? '—'}', overflow: TextOverflow.ellipsis)),
                    DataCell(Text('${map['actor_name'] ?? map['actor_id'] ?? '—'}', overflow: TextOverflow.ellipsis)),
                    DataCell(Text(resource.isNotEmpty ? resource : '—', overflow: TextOverflow.ellipsis)),
                  ],
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ошибка загрузки: $e', style: const TextStyle(color: AppColors.danger)),
          ),
        ),
      ),
    );
  }
}

String _formatDate(dynamic v) {
  if (v == null) return '—';
  if (v is String) {
    try {
      final d = DateTime.parse(v);
      return DateFormat('dd.MM.yyyy HH:mm').format(d);
    } catch (_) {}
    return v;
  }
  return '—';
}
