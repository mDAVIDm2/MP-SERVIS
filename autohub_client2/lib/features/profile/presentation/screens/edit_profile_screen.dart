import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/widgets/common_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _initializedFromUser = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user != null && !_initializedFromUser) {
      _initializedFromUser = true;
      final parts = user.name.trim().split(RegExp(r'\s+'));
      _nameController.text = parts.isNotEmpty ? parts.first : user.name;
      _surnameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : (user.surname ?? '');
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email ?? '';
    }
    final initials = user?.initials ?? '?';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Редактировать профиль', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Аватар
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.nestedBg,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Center(child: Text(initials, style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary,
                  ))),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 18, color: Color(0xFF0D0D0D)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildField('Имя', _nameController),
          const SizedBox(height: 16),
          _buildField('Фамилия', _surnameController),
          const SizedBox(height: 16),
          _buildField('Email', _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildField('Телефон', _phoneController, keyboardType: TextInputType.phone, enabled: false),
          const SizedBox(height: 8),
          const Text('Для смены номера обратитесь в поддержку',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: GoldButton(
          text: 'Сохранить',
          onPressed: () async {
            HapticFeedback.mediumImpact();
            final name = _nameController.text.trim();
            final surname = _surnameController.text.trim();
            await ref.read(authProvider.notifier).updateProfile(
              name: name.isEmpty ? null : name,
              surname: surname.isEmpty ? null : surname,
            );
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Профиль обновлён'), backgroundColor: AppColors.success),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {
    TextInputType? keyboardType, bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppColors.cardBg : AppColors.nestedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 16, color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
