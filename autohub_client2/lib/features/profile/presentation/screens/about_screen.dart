import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/constants/app_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('О приложении', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: context.palette.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: context.palette.goldGlow,
              ),
              child: Center(
                child: Text(
                  'MS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: context.palette.onAccent,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Center(child: Text('MP-Servis', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
          ))),
          SizedBox(height: 4),
          Center(child: Text('Версия $appVersion (сборка $appBuildNumber)', style: TextStyle(
            fontSize: 14, color: context.palette.textSecondary,
          ))),
          SizedBox(height: 24),
          _ChangelogSection(items: changelog),
          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.palette.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.border),
            ),
            child: Text(
              'MP-Servis — платформа для управления автосервисными услугами. '
              'Записывайтесь в проверенные автосервисы, отслеживайте статус работ в реальном времени, '
              'управляйте обслуживанием вашего автомобиля и храните всю историю в одном месте.',
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary, height: 1.6),
            ),
          ),
          SizedBox(height: 16),
          _InfoRow(icon: Icons.map_rounded, label: 'Выбор карт', value: 'Профиль → Настройки → Карты'),
          _InfoRow(icon: Icons.code_rounded, label: 'Flutter', value: '3.10'),
          _InfoRow(icon: Icons.build_rounded, label: 'Сборка', value: '№$appBuildNumber'),
          _InfoRow(icon: Icons.shield_rounded, label: 'Лицензия', value: 'MIT'),
          SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.palette.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              children: [
                _LinkRow(label: 'Политика конфиденциальности', onTap: () {}),
                _LinkRow(label: 'Пользовательское соглашение', onTap: () {}),
                _LinkRow(label: 'Открытые лицензии', onTap: () {}),
              ],
            ),
          ),
          SizedBox(height: 32),
          Center(child: Text('© 2025 MP-Servis Team',
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary))),
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
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update_rounded, size: 20, color: context.palette.primary),
              SizedBox(width: 8),
              Text('Последние изменения', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
              )),
            ],
          ),
          SizedBox(height: 12),
          ...items.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 14, color: context.palette.primary)),
                Expanded(child: Text(e, style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35))),
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
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.palette.textTertiary),
            SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.palette.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: context.palette.primary))),
            Icon(Icons.open_in_new_rounded, size: 16, color: context.palette.textTertiary),
          ],
        ),
      ),
    );
  }
}
