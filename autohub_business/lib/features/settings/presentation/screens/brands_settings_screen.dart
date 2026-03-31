import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../widgets/car_reference_picker_dialog.dart';
import 'brands_settings_desktop_screen.dart';

class BrandsSettingsScreen extends ConsumerStatefulWidget {
  const BrandsSettingsScreen({super.key});

  @override
  ConsumerState<BrandsSettingsScreen> createState() => _BrandsSettingsScreenState();
}

class _BrandsSettingsScreenState extends ConsumerState<BrandsSettingsScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform) {
      return const BrandsSettingsDesktopScreen();
    }
    final brands = ref.watch(settingsRepositoryProvider).carBrands;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Специализация по маркам'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
          ref.invalidate(carReferenceBrandsProvider);
        },
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => CarReferencePickerDialog.show(context, ref),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Из справочника БД (марки и модели)'),
          ),
          const SizedBox(height: 8),
          Text(
            'Или введите текст вручную, если нет в списке:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Добавить марку',
              hintText: 'Например: Toyota',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () {
                  repo.addBrand(_controller.text);
                  _controller.clear();
                },
              ),
            ),
            onSubmitted: (v) {
              repo.addBrand(v);
              _controller.clear();
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Марки',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...brands.map((b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(b),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => repo.removeBrand(b),
                  ),
                ),
              )),
        ],
        ),
      ),
    );
  }
}
