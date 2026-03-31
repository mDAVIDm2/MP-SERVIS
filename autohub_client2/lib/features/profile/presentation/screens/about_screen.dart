import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('О приложении', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.goldGlow,
              ),
              child: const Center(child: Text('AH', style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0D0D0D),
              ))),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('AutoHub', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          ))),
          const SizedBox(height: 4),
          Center(child: Text('Версия $appVersion (сборка $appBuildNumber)', style: const TextStyle(
            fontSize: 14, color: AppColors.textSecondary,
          ))),
          const SizedBox(height: 24),
          _ChangelogSection(items: changelog),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'AutoHub — платформа для управления автосервисными услугами. '
              'Записывайтесь в проверенные автосервисы, отслеживайте статус работ в реальном времени, '
              'управляйте обслуживанием вашего автомобиля и храните всю историю в одном месте.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.map_rounded, label: 'Выбор карт', value: 'Профиль → Настройки → Карты'),
          _InfoRow(icon: Icons.code_rounded, label: 'Flutter', value: '3.10'),
          _InfoRow(icon: Icons.build_rounded, label: 'Сборка', value: '№$appBuildNumber'),
          _InfoRow(icon: Icons.shield_rounded, label: 'Лицензия', value: 'MIT'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _LinkRow(label: 'Политика конфиденциальности', onTap: () {}),
                _LinkRow(label: 'Пользовательское соглашение', onTap: () {}),
                _LinkRow(label: 'Открытые лицензии', onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Center(child: Text('© 2025 AutoHub Team',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
        ],
      ),
    );
  }
}

class _ChangelogSection extends StatelessWidget {
  final List<String> items;
  const _ChangelogSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Последние изменения', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
              )),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 14, color: AppColors.primary)),
                Expanded(child: Text(e, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.primary))),
            const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
