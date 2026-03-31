import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';

class InviteStaffScreen extends ConsumerStatefulWidget {
  const InviteStaffScreen({super.key});

  @override
  ConsumerState<InviteStaffScreen> createState() => _InviteStaffScreenState();
}

class _InviteStaffScreenState extends ConsumerState<InviteStaffScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  StaffRole _role = StaffRole.master;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Пригласить сотрудника'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Как к сотруднику обращаться',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              hintText: '+7 999 123-45-67',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email (необязательно)',
              hintText: 'email@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          const Text(
            'Роль',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
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
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _invite,
            child: const Text('Пригласить'),
          ),
        ],
      ),
    );
  }

  Future<void> _invite() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
    if (phone == null && email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите телефон или email'), backgroundColor: AppColors.cardBg),
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
          const SnackBar(
            content: Text('Приглашение отправлено'),
            backgroundColor: AppColors.cardBg,
          ),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }
}
