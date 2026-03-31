import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_launcher/map_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/settings/preferred_directions_map_provider.dart';

class MapSettingsScreen extends ConsumerWidget {
  const MapSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(mapProviderSettingProvider);
    final preferredMapType = ref.watch(preferredDirectionsMapProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Карты', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Карта в приложении', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
            )),
          ),
          ...MapProvider.values.map((provider) {
            final isSelected = current == provider;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => ref.read(mapProviderSettingProvider.notifier).set(provider),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppColors.primary : AppColors.textTertiary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(provider.shortName, style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                              )),
                              const SizedBox(height: 2),
                              Text(provider.description, style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary,
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Приложение для маршрутов', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
            )),
          ),
          Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                final available = await MapLauncher.installedMaps;
                if (!context.mounted) return;
                if (available.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Нет установленных карт'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                if (available.length == 1) {
                  ref.read(preferredDirectionsMapProvider.notifier).set(available.first.mapType.name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Навигатор сохранён'), behavior: SnackBarBehavior.floating),
                    );
                  }
                  return;
                }
                final chosen = await showModalBottomSheet<AvailableMap>(
                  context: context,
                  backgroundColor: AppColors.cardBg,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Выберите навигатор', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                        ...available.map((map) => ListTile(
                          leading: const Icon(Icons.map_rounded, color: AppColors.primary, size: 28),
                          title: Text(directionsMapDisplayName(map), style: const TextStyle(color: AppColors.textPrimary)),
                          onTap: () => Navigator.pop(ctx, map),
                        )),
                      ],
                    ),
                  ),
                );
                if (chosen != null) {
                  ref.read(preferredDirectionsMapProvider.notifier).set(chosen.mapType.name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Навигатор сохранён'), behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.directions_rounded, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Навигатор для маршрута', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                          )),
                          const SizedBox(height: 2),
                          Text(
                            preferredDirectionsMapDisplayName(preferredMapType),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
