import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';
import 'staff_detail_panel.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  final StaffEntry entry;

  const StaffDetailScreen({super.key, required this.entry});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  final GlobalKey<StaffDetailPanelState> _panelKey = GlobalKey<StaffDetailPanelState>();

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(staffRepositoryProvider);
    final match = list.where((e) => e.id == widget.entry.id);
    final entry = match.isEmpty ? widget.entry : match.first;
    final canManageStaff = ref.watch(authProvider).user?.role.canInviteStaff ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(entry.name),
        actions: canManageStaff
            ? [
                TextButton(
                  onPressed: () => _panelKey.currentState?.submitSave(),
                  child: const Text('Сохранить'),
                ),
              ]
            : null,
      ),
      body: StaffDetailPanel(
        key: _panelKey,
        entry: widget.entry,
        embedded: false,
        manageStaff: canManageStaff,
      ),
    );
  }
}
