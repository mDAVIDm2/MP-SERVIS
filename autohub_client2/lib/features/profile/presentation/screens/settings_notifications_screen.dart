import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/client_notification_prefs_provider.dart';

class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  ConsumerState<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends ConsumerState<SettingsNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientNotificationPrefsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Уведомления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить настройки',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (p) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildSection('Основные', [
              _SwitchRow(
                label: 'Push-уведомления',
                subtitle: 'Показывать всплывающие уведомления (нужен Firebase и разрешение ОС)',
                value: p.pushEnabled,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setServerFields(p.copyWith(pushEnabled: v)),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Типы уведомлений', [
              _SwitchRow(
                label: 'Обновления заказов',
                subtitle: 'Статусы, согласования, завершение',
                value: p.orderUpdates,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setServerFields(p.copyWith(orderUpdates: v)),
              ),
              _SwitchRow(
                label: 'Сообщения в чатах',
                subtitle: 'Ответы сервиса и поддержки',
                value: p.chatMessages,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setServerFields(p.copyWith(chatMessages: v)),
              ),
              _SwitchRow(
                label: 'Напоминания о ТО и справочнике',
                subtitle: 'Марка/модель авто, напоминания из гаража',
                value: p.reminders,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setServerFields(p.copyWith(reminders: v)),
              ),
              _SwitchRow(
                label: 'Акции и предложения',
                value: p.promotions,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setServerFields(p.copyWith(promotions: v)),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Звук и вибрация', [
              _SwitchRow(
                label: 'Звук',
                value: p.sound,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setSound(v),
              ),
              _SwitchRow(
                label: 'Вибрация',
                value: p.vibration,
                onChanged: (v) => ref.read(clientNotificationPrefsProvider.notifier).setVibration(v),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              'Типы и push синхронизируются с сервером и влияют на список уведомлений в приложении. Звук и вибрация применяются локально к push.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchRow({required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged == null
                ? null
                : (v) {
                    HapticFeedback.lightImpact();
                    onChanged!(v);
                  },
            activeTrackColor: AppColors.primary.withValues(alpha: 0.45),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
