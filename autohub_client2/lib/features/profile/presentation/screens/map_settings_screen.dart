import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_launcher/map_launcher.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/settings/preferred_directions_map_provider.dart';

class MapSettingsScreen extends ConsumerWidget {
  const MapSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    final current = ref.watch(mapProviderSettingProvider);
    final preferredMapType = ref.watch(preferredDirectionsMapProvider);
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(l10n.maps, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
        )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(l10n.mapInSearchTab, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textSecondary,
            )),
          ),
          ...MapProvider.values.map((provider) {
            final isSelected = current == provider;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: context.palette.cardBg,
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
                          color: isSelected ? context.palette.primary : context.palette.textTertiary,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(provider.shortName, style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                              )),
                              SizedBox(height: 2),
                              Text(provider.description, style: TextStyle(
                                fontSize: 13, color: context.palette.textSecondary,
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
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(l10n.routingApp, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textSecondary,
            )),
          ),
          Material(
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                final available = await MapLauncher.installedMaps;
                if (!context.mounted) return;
                if (available.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.noMapsInstalled), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                if (available.length == 1) {
                  ref.read(preferredDirectionsMapProvider.notifier).set(available.first.mapType.name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.navigatorSaved), behavior: SnackBarBehavior.floating),
                    );
                  }
                  return;
                }
                final chosen = await showModalBottomSheet<AvailableMap>(
                  context: context,
                  backgroundColor: context.palette.cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.chooseNavigator, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
                        ),
                        ...available.map((map) => ListTile(
                          leading: Icon(Icons.map_rounded, color: context.palette.primary, size: 28),
                          title: Text(directionsMapDisplayName(map), style: TextStyle(color: context.palette.textPrimary)),
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
                      SnackBar(content: Text(l10n.navigatorSaved), behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.directions_rounded, color: context.palette.primary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.navigatorForRoute, style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                          )),
                          SizedBox(height: 2),
                          Text(
                            preferredDirectionsMapDisplayName(preferredMapType),
                            style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.palette.textTertiary, size: 24),
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
