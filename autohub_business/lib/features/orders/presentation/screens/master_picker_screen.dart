import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/staff_model.dart';

/// Экран выбора мастера для назначения на заказ. Проверяет навыки мастера и услуги заказа.
class MasterPickerScreen extends ConsumerWidget {
  final String orderId;

  const MasterPickerScreen({super.key, required this.orderId});

  /// Требуемые навыки по позициям заказа (из настроек: услуга по имени → required_skill).
  static Set<String> _requiredSkillsForOrder(List<dynamic> orderItemNames, List<dynamic> settingsServices) {
    final names = orderItemNames.map((e) => (e as String).trim().toLowerCase()).toSet();
    final skills = <String>{};
    for (final s in settingsServices) {
      final m = s as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').trim().toLowerCase();
      if (names.contains(name)) {
        final skill = m['required_skill'] as String?;
        if (skill != null && skill.isNotEmpty) skills.add(skill);
      }
    }
    return skills;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffListProvider);
    final staffEntries = ref.watch(staffRepositoryProvider).where((e) => e.isActive && e.role == StaffRole.master).toList();
    final order = ref.watch(orderByIdProvider(orderId));
    final settings = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(orderRepositoryProvider.notifier);

    final itemNames = order?.items.map((i) => i.name).toList() ?? [];
    final servicesJson = settings.services.map((s) => {'name': s.name, 'required_skill': s.requiredSkill}).toList();
    final requiredSkills = _requiredSkillsForOrder(itemNames, servicesJson);
    final masterSkillsById = {for (final e in staffEntries) e.id: Set<String>.from(e.skills)};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Назначить мастера'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: staff.length,
        itemBuilder: (context, i) {
          final m = staff[i];
          final masterSkills = masterSkillsById[m.id] ?? {};
          final missing = requiredSkills.where((s) => !masterSkills.contains(s)).toList();
          final hasAllSkills = missing.isEmpty;
          final missingLabel = missing.map((s) => skillLabel(s)).join(', ');

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: hasAllSkills ? AppColors.primary.withValues(alpha: 0.3) : AppColors.textTertiary.withValues(alpha: 0.3),
                child: Text(
                  m.name[0].toUpperCase(),
                  style: TextStyle(
                    color: hasAllSkills ? AppColors.primary : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text(m.name),
              subtitle: Text(
                hasAllSkills ? (m.roleLabel ?? '') : 'Требуется: $missingLabel',
                style: TextStyle(fontSize: 13, color: hasAllSkills ? AppColors.textSecondary : AppColors.error),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (!hasAllSkills) {
                  final assignAnyway = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Навыки мастера'),
                      content: Text(
                        'Этот мастер не специализируется на данных работах (Требуется: $missingLabel). Всё равно назначить?',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Назначить')),
                      ],
                    ),
                  );
                  if (assignAnyway != true || !context.mounted) return;
                }
                final result = await repo.assignMaster(orderId, m);
                if (!context.mounted) return;
                if (result.errorOrNull == null) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Назначен: ${m.name}'),
                      backgroundColor: AppColors.cardBg,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorOrNull!.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
