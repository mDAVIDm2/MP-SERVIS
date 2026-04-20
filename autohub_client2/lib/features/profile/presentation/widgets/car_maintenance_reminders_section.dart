import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../screens/maintenance_reminder_detail_screen.dart';
import 'compact_maintenance_reminder_tile.dart';

/// Секция напоминаний ТО для одной машины: плитки + «Добавить напоминание».
class CarMaintenanceRemindersSection extends ConsumerWidget {
  const CarMaintenanceRemindersSection({
    super.key,
    required this.car,
    required this.availableTypes,
  });

  final Car car;
  final List<MaintenanceType> availableTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maintenanceRemindersProvider);
    final configsForCar = state.configs.where((c) => c.carId == car.id).toList();
    final addedTypes = MaintenanceType.values
        .where((t) => configsForCar.any((c) => MaintenanceType.fromTypeKey(c.typeKey) == t))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...addedTypes.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CompactMaintenanceReminderTile(
              car: car,
              type: type,
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MaintenanceReminderDetailScreen(car: car, type: type),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddSheet(context, ref, car, availableTypes),
            icon: Icon(Icons.add_rounded, size: 20),
            label: Text(L10nScope.of(context).addReminder),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.palette.primary,
              side: BorderSide(color: context.palette.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, Car car, List<MaintenanceType> types) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final notifier = ref.read(maintenanceRemindersProvider.notifier);
          return _AddReminderSheet(
            car: car,
            notifier: notifier,
            availableTypes: types,
          );
        },
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet({
    required this.car,
    required this.notifier,
    required this.availableTypes,
  });

  final Car car;
  final MaintenanceRemindersNotifier notifier;
  final List<MaintenanceType> availableTypes;

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Set<MaintenanceType> _filteredAllowed(AppL10n l10n) {
    final allowed = widget.availableTypes.toSet();
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return allowed;
    return allowed
        .where(
          (t) =>
              t.localizedTitle(l10n).toLowerCase().contains(q) ||
              t.localizedSubtitle(l10n).toLowerCase().contains(q) ||
              t.name.toLowerCase().contains(q),
        )
        .toSet();
  }

  void _onTypeTap(BuildContext context, MaintenanceType type, bool isAdded) {
    final car = widget.car;
    final notifier = widget.notifier;
    final l10n = L10nScope.of(context);
    if (!isAdded) {
      notifier.setConfig(MaintenanceType.defaultConfigFor(car.id, type));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.addedLabel(type.localizedTitle(l10n))),
            backgroundColor: context.palette.success,
          ),
        );
        Navigator.pop(context);
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MaintenanceReminderDetailScreen(car: car, type: type),
          ),
        );
      }
    } else {
      Navigator.pop(context);
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MaintenanceReminderDetailScreen(car: car, type: type),
        ),
      );
    }
  }

  Widget _typeTile(BuildContext context, AppL10n l10n, MaintenanceType type, bool isAdded) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        type.localizedTitle(l10n),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.palette.textPrimary,
        ),
      ),
      subtitle: Text(
        type.localizedSubtitle(l10n),
        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
      ),
      trailing: isAdded
          ? Icon(Icons.check_circle_rounded, color: context.palette.primary, size: 24)
          : Icon(Icons.add_circle_outline_rounded, color: context.palette.textSecondary, size: 24),
      onTap: () => _onTypeTap(context, type, isAdded),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(maintenanceRemindersProvider);
    final l10n = L10nScope.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final filtered = _filteredAllowed(l10n);
    final notifier = widget.notifier;
    final car = widget.car;
    final sections = maintenanceTypeSections(l10n);

    final sectionChildren = <Widget>[];
    for (final sec in sections) {
      final items = sec.types.where(filtered.contains).toList();
      if (items.isEmpty) {
        continue;
      }
      sectionChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            sec.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.palette.textSecondary.withValues(alpha: 0.9),
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
      for (final type in items) {
        final isAdded = notifier.getConfig(car.id, type.name) != null;
        sectionChildren.add(_typeTile(context, l10n, type, isAdded));
      }
    }

    final covered = sections.expand((s) => s.types).toSet();
    final orphans = filtered.where((t) => !covered.contains(t)).toList();
    if (orphans.isNotEmpty) {
      sectionChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            l10n.otherSection,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.palette.textSecondary.withValues(alpha: 0.9),
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
      for (final type in orphans) {
        final isAdded = notifier.getConfig(car.id, type.name) != null;
        sectionChildren.add(_typeTile(context, l10n, type, isAdded));
      }
    }

    final emptySearch = filtered.isEmpty && _search.text.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                l10n.chooseServiceTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary.withValues(alpha: 0.95),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.chooseServiceSubtitle,
                style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _search,
                style: TextStyle(fontSize: 15, color: context.palette.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.searchByNameOrDesc,
                  hintStyle: TextStyle(color: context.palette.textPlaceholder, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: context.palette.textSecondary, size: 22),
                  filled: true,
                  fillColor: context.palette.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.palette.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: emptySearch
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.nothingFound,
                          style: TextStyle(fontSize: 14, color: context.palette.textSecondary.withValues(alpha: 0.9)),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: sectionChildren,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
