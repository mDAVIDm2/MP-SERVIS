import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../widgets/car_reference_picker_dialog.dart';

/// Десктоп: марки в работе — светлая тема, быстрый ввод, чипы брендов.
class BrandsSettingsDesktopScreen extends ConsumerStatefulWidget {
  const BrandsSettingsDesktopScreen({super.key});

  @override
  ConsumerState<BrandsSettingsDesktopScreen> createState() => _BrandsSettingsDesktopScreenState();
}

class _BrandsSettingsDesktopScreenState extends ConsumerState<BrandsSettingsDesktopScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(WidgetRef ref) {
    final repo = ref.read(settingsRepositoryProvider.notifier);
    repo.addBrand(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(settingsRepositoryProvider).carBrands;
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final sorted = List<String>.from(brands)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColorsDesktop.surface,
        foregroundColor: AppColorsDesktop.textPrimary,
        title: const Text('Специализация по маркам'),
      ),
      body: RefreshIndicator(
        color: AppColorsDesktop.primary,
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
          ref.invalidate(carReferenceBrandsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
          children: [
            Container(
              padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
              decoration: BoxDecoration(
                color: AppColorsDesktop.surface,
                borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCardLarge),
                border: Border.all(color: AppColorsDesktop.borderLight),
                boxShadow: DesktopDesignSystem.shadowCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Марки автомобилей', style: DesktopDesignSystem.sectionTitle),
                  const SizedBox(height: 6),
                  Text(
                    'Сначала выберите позиции из справочника MP-Servis (те же названия, что в базе марок/моделей). '
                    'Свободный ввод — только если в списке нет нужной строки.',
                    style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => CarReferencePickerDialog.show(context, ref),
                    icon: const Icon(Icons.library_books_outlined, size: 20),
                    label: const Text('Выбрать из справочника БД'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColorsDesktop.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Свободный ввод', style: DesktopDesignSystem.label),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: 'Текст вручную',
                            hintText: 'Если нет в справочнике',
                            filled: true,
                            fillColor: AppColorsDesktop.nestedBg.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                              borderSide: const BorderSide(color: AppColorsDesktop.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                              borderSide: const BorderSide(color: AppColorsDesktop.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                              borderSide: const BorderSide(color: AppColorsDesktop.primary, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _add(ref),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _add(ref),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Добавить'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColorsDesktop.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Выбранные марки (${sorted.length})', style: DesktopDesignSystem.label),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColorsDesktop.surface,
                  borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
                  border: Border.all(color: AppColorsDesktop.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.directions_car_outlined, size: 48, color: AppColorsDesktop.textPlaceholder),
                    const SizedBox(height: 12),
                    Text('Пока нет марок', style: DesktopDesignSystem.sectionTitle),
                    const SizedBox(height: 6),
                    Text(
                      'Добавьте хотя бы одну марку — так проще ориентироваться в заявках.',
                      textAlign: TextAlign.center,
                      style: DesktopDesignSystem.bodySecondary,
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: sorted
                    .map(
                      (b) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColorsDesktop.surface,
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
                          border: Border.all(color: AppColorsDesktop.border),
                          boxShadow: DesktopDesignSystem.shadowCard,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(b, style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              icon: Icon(Icons.close_rounded, size: 18, color: AppColorsDesktop.textSecondary),
                              onPressed: () => repo.removeBrand(b),
                              tooltip: 'Удалить',
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
