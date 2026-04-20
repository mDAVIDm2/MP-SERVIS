import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';

class InviteStaffScreen extends ConsumerStatefulWidget {
  const InviteStaffScreen({super.key, this.desktopChrome = false});

  /// Светлая тема для десктопа (как у остальных экранов настроек).
  final bool desktopChrome;

  @override
  ConsumerState<InviteStaffScreen> createState() => _InviteStaffScreenState();
}

class _InviteStaffScreenState extends ConsumerState<InviteStaffScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  StaffRole _role = StaffRole.master;

  bool get _d => widget.desktopChrome;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    if (authUser != null && !authUser.role.canInviteStaff) {
      final msg = 'Приглашать сотрудников могут только владелец, администратор или самозанятый.';
      if (_d) {
        return themeDesktopLight(
          child: Scaffold(
            backgroundColor: AppColorsDesktop.background,
            appBar: AppBar(title: const Text('Пригласить')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: AppColorsDesktop.textSecondary)),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Пригласить')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center))),
      );
    }

    final bg = _d ? AppColorsDesktop.background : AppColors.background;
    final textPri = _d ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSec = _d ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final border = _d ? AppColorsDesktop.border : AppColors.border;

    final scaffold = Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Пригласить сотрудника'),
        backgroundColor: _d ? AppColorsDesktop.surface : null,
        foregroundColor: _d ? AppColorsDesktop.textPrimary : null,
        surfaceTintColor: _d ? Colors.transparent : null,
        elevation: _d ? 0 : null,
      ),
      body: ListView(
        padding: EdgeInsets.all(_d ? 24 : 16),
        children: [
          if (_d) ...[
            Text(
              'Контакты сотрудника',
              style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Укажите телефон или email — приглашённый увидит его в разделе «Входящие приглашения».',
              style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.4),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _nameController,
            style: TextStyle(color: textPri),
            decoration: InputDecoration(
              labelText: 'Имя',
              hintText: 'Как к сотруднику обращаться',
              labelStyle: TextStyle(color: textSec),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _d ? AppColorsDesktop.primary : AppColors.primary, width: 2),
              ),
            ),
          ),
          SizedBox(height: _d ? 18 : 16),
          TextField(
            controller: _phoneController,
            style: TextStyle(color: textPri),
            decoration: InputDecoration(
              labelText: 'Телефон',
              hintText: '+7 999 123-45-67',
              labelStyle: TextStyle(color: textSec),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _d ? AppColorsDesktop.primary : AppColors.primary, width: 2),
              ),
            ),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: _d ? 18 : 16),
          TextField(
            controller: _emailController,
            style: TextStyle(color: textPri),
            decoration: InputDecoration(
              labelText: 'Email (необязательно)',
              hintText: 'email@example.com',
              labelStyle: TextStyle(color: textSec),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _d ? AppColorsDesktop.primary : AppColors.primary, width: 2),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: _d ? 28 : 24),
          Text(
            'Роль',
            style: TextStyle(
              fontSize: 14,
              color: textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<StaffRole>(
            segments: const [
              ButtonSegment(value: StaffRole.master, label: Text('Мастер'), icon: Icon(Icons.build_rounded)),
              ButtonSegment(value: StaffRole.admin, label: Text('Админ'), icon: Icon(Icons.admin_panel_settings_rounded)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
            style: _d
                ? ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColorsDesktop.primary;
                      }
                      return AppColorsDesktop.textSecondary;
                    }),
                  )
                : null,
          ),
          SizedBox(height: _d ? 36 : 32),
          FilledButton(
            onPressed: _invite,
            style: FilledButton.styleFrom(
              backgroundColor: _d ? AppColorsDesktop.primary : null,
              foregroundColor: _d ? Colors.white : null,
              padding: EdgeInsets.symmetric(vertical: _d ? 16 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_d ? DesktopDesignSystem.radiusButton : 8),
              ),
            ),
            child: const Text('Пригласить'),
          ),
        ],
      ),
    );
    if (_d) return themeDesktopLight(child: scaffold);
    return scaffold;
  }

  Future<void> _invite() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
    if (phone == null && email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Укажите телефон или email'),
          backgroundColor: _d ? AppColorsDesktop.nestedBg : AppColors.cardBg,
        ),
      );
      return;
    }
    final result = await ref.read(staffRepositoryProvider.notifier).invite(
          name: name.isEmpty ? null : name,
          phone: phone,
          email: email,
          role: _role,
        );
    if (!context.mounted) return;
    result.when(
      success: (entry) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Приглашение отправлено'),
            backgroundColor: _d ? AppColorsDesktop.nestedBg : AppColors.cardBg,
          ),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: _d ? AppColorsDesktop.error : AppColors.error,
          ),
        );
      },
    );
  }
}
