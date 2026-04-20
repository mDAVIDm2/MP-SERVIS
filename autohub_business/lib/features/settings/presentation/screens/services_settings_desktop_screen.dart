import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../shared/models/service_catalog_models.dart';
import 'service_item_edit_screen.dart';
import 'service_category_edit_screen.dart';
import 'service_packages_screen.dart';

/// Десктоп: услуги и цены — светлая тема, выбор из единого справочника, запрос недостающих позиций.
class ServicesSettingsDesktopScreen extends ConsumerStatefulWidget {
  const ServicesSettingsDesktopScreen({super.key});

  @override
  ConsumerState<ServicesSettingsDesktopScreen> createState() =>
      _ServicesSettingsDesktopScreenState();
}

class _ServicesSettingsDesktopScreenState
    extends ConsumerState<ServicesSettingsDesktopScreen> {
  int _selectedCategoryIndex = 0;

  String _durationStr(int min) {
    if (min < 60) return '$min мин';
    final h = min ~/ 60;
    final m = min % 60;
    if (m == 0) return '$h ч';
    return '$h ч $m мин';
  }

  Future<void> _pickFromCatalog(BuildContext context) async {
    ServiceCatalogData data;
    try {
      data = await ref.read(serviceCatalogDataProvider.future);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось загрузить справочник. Нажмите «Справочник» для обновления.',
            ),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (data.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Справочник пуст. Выполните миграции БД и перезапустите сервер.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) {
        var q = '';
        return themeDesktopLight(
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              final flat = data.allItems.where((e) {
                if (q.isEmpty) return true;
                final n = e.item.name.toLowerCase();
                final c = e.cat.categoryName.toLowerCase();
                return n.contains(q) || c.contains(q);
              }).toList();
              return AlertDialog(
                backgroundColor: AppColorsDesktop.surface,
                surfaceTintColor: Colors.transparent,
                title: const Text('Добавить из справочника MP-Servis'),
                content: SizedBox(
                  width: 520,
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию или категории…',
                          filled: true,
                          fillColor: AppColorsDesktop.nestedBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              DesktopDesignSystem.radiusButton,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColorsDesktop.textTertiary,
                          ),
                        ),
                        onChanged: (v) =>
                            setLocal(() => q = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: flat.length,
                          itemBuilder: (_, i) {
                            final e = flat[i];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              title: Text(
                                e.item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                e.cat.categoryName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColorsDesktop.textSecondary,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _askPriceAndAdd(context, e.cat, e.item);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Закрыть'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _askPriceAndAdd(
    BuildContext context,
    ServiceCatalogCategoryRef cat,
    ServiceCatalogItemRef item,
  ) async {
    final priceCtrl = TextEditingController();
    final durCtrl = TextEditingController(
      text: '${item.defaultDurationMinutes}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => themeDesktopLight(
        child: AlertDialog(
          backgroundColor: AppColorsDesktop.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Цена и длительность'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColorsDesktop.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Цена, ₽',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Длительность, мин',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final rub = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final priceKopecks = (rub * 100).round();
    final dur = int.tryParse(durCtrl.text) ?? item.defaultDurationMinutes;
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final catId = repo.categoryIdForCatalogCategory(cat);
    repo.addServiceFromCatalog(
      categoryId: catId,
      catalogItemId: item.id,
      name: item.name,
      priceKopecks: priceKopecks,
      durationMinutes: dur,
      requiredSkill: item.requiredSkill,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Добавлено: ${item.name}')));
    }
  }

  Future<void> _requestMissingService(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final hintCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => themeDesktopLight(
        child: AlertDialog(
          backgroundColor: AppColorsDesktop.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Запросить позицию в справочник'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Это не добавляет услугу в ваш прайс. Заявка уходит разработчикам MP-Servis: после проверки строка появится в общем справочнике, и все организации смогут выбрать её кнопкой «Из справочника».\n\n'
                    'Если нужна только ваша уникальная позиция без единого названия — используйте «Своя услуга».',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColorsDesktop.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название услуги *',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hintCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Категория (подсказка)',
                      hintText: 'Например: Двигатель',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий для разработчиков',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Отправить заявку'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final api = ref.read(serviceCatalogApiServiceProvider);
    final res = await api.submitSuggestion(
      requestedName: name,
      categoryHint: hintCtrl.text.trim().isEmpty ? null : hintCtrl.text.trim(),
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );
    if (!context.mounted) return;
    res.when(
      success: (m) {
        final msg = m['message']?.toString() ?? 'Запрос отправлен';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final categories = List<ServiceCategory>.from(settings.categories)
      ..sort((a, b) => a.order.compareTo(b.order));
    final catalogAsync = ref.watch(serviceCatalogDataProvider);

    if (_selectedCategoryIndex >= categories.length) {
      _selectedCategoryIndex = categories.isEmpty ? 0 : categories.length - 1;
    }
    final selectedCat = categories.isEmpty
        ? null
        : categories[_selectedCategoryIndex.clamp(0, categories.length - 1)];
    final services = selectedCat == null
        ? <ServiceItem>[]
        : repo.servicesForCategory(selectedCat.id);

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColorsDesktop.surface,
        foregroundColor: AppColorsDesktop.textPrimary,
        title: const Text('Услуги и цены'),
        actions: [
          TextButton.icon(
            onPressed: catalogAsync.isLoading
                ? null
                : () => ref.invalidate(serviceCatalogDataProvider),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Справочник'),
            style: TextButton.styleFrom(
              foregroundColor: AppColorsDesktop.primary,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServicePackagesScreen()),
            ),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Комплексы'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColorsDesktop.primary,
              side: const BorderSide(color: AppColorsDesktop.border),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _requestMissingService(context),
            icon: const Icon(Icons.outgoing_mail, size: 18),
            label: const Text('Запросить в справочник'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColorsDesktop.primary,
              side: const BorderSide(color: AppColorsDesktop.border),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        color: AppColorsDesktop.primary,
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
          ref.invalidate(serviceCatalogDataProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
          children: [
            _InfoBanner(catalogAsync: catalogAsync),
            const SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.sizeOf(context).height - 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 268,
                    child: _CategorySidebar(
                      categories: categories,
                      selectedIndex: categories.isEmpty
                          ? 0
                          : _selectedCategoryIndex.clamp(
                              0,
                              categories.length - 1,
                            ),
                      onSelect: (i) =>
                          setState(() => _selectedCategoryIndex = i),
                      onAddCategory: () => _promptNewCategory(context, repo),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ServicesPanel(
                      category: selectedCat,
                      services: services,
                      catalogAsync: catalogAsync,
                      onAddFromCatalog: () => _pickFromCatalog(context),
                      onAddCustom: selectedCat == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceItemEditScreen(
                                  categoryId: selectedCat.id,
                                  categoryName: selectedCat.name,
                                ),
                              ),
                            ),
                      onEdit: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceItemEditScreen(
                            categoryId: selectedCat!.id,
                            categoryName: selectedCat.name,
                            existing: s,
                          ),
                        ),
                      ),
                      onDelete: (s) => ref
                          .read(settingsRepositoryProvider.notifier)
                          .deleteService(s.id),
                      onEditCategory: selectedCat == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceCategoryEditScreen(
                                  category: selectedCat,
                                ),
                              ),
                            ),
                      durationStr: _durationStr,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptNewCategory(
    BuildContext context,
    SettingsRepository repo,
  ) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => themeDesktopLight(
        child: AlertDialog(
          backgroundColor: AppColorsDesktop.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Новая категория'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty && context.mounted) {
      repo.addCategory(c.text.trim());
      final next = ref.read(settingsRepositoryProvider).categories.length - 1;
      setState(() => _selectedCategoryIndex = next < 0 ? 0 : next);
    }
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.catalogAsync});
  final AsyncValue<ServiceCatalogData> catalogAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(
          DesktopDesignSystem.radiusCardLarge,
        ),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColorsDesktop.primary.withValues(alpha: 0.9),
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Единый справочник услуг',
                  style: DesktopDesignSystem.sectionTitle.copyWith(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '«Из справочника» — единые названия для всех точек. «Своя услуга» — только ваш прайс. '
                  '«Запросить в справочник» — заявка разработчикам, в прайс сама не попадает.',
                  style: DesktopDesignSystem.bodySecondary.copyWith(
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                catalogAsync.when(
                  data: (d) => Text(
                    d.allItems.isEmpty
                        ? 'Справочник загружен, но список пуст. На сервере выполните миграции и перезапуск (сид зальёт позиции).'
                        : 'В справочнике: ${d.allItems.length} позиций в ${d.categories.length} категориях',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: d.allItems.isEmpty
                          ? AppColorsDesktop.warning
                          : AppColorsDesktop.primary,
                    ),
                  ),
                  loading: () => const Text(
                    'Загрузка справочника…',
                    style: TextStyle(fontSize: 12),
                  ),
                  error: (e, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Справочник не загрузился (сеть, JWT или адрес API).',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColorsDesktop.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$e',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColorsDesktop.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Базовый URL: ${AppConfig.baseUrl} → GET /reference/service-catalog',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColorsDesktop.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddCategory,
  });

  final List<ServiceCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Ваши категории',
              style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 14),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final c = categories[i];
                final sel = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: sel
                        ? AppColorsDesktop.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      DesktopDesignSystem.radiusButton,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        DesktopDesignSystem.radiusButton,
                      ),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                            color: sel
                                ? AppColorsDesktop.primary
                                : AppColorsDesktop.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onAddCategory,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Категория'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColorsDesktop.primary,
                side: const BorderSide(color: AppColorsDesktop.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesPanel extends StatelessWidget {
  const _ServicesPanel({
    required this.category,
    required this.services,
    required this.catalogAsync,
    required this.onAddFromCatalog,
    required this.onAddCustom,
    required this.onEdit,
    required this.onDelete,
    required this.onEditCategory,
    required this.durationStr,
  });

  final ServiceCategory? category;
  final List<ServiceItem> services;
  final AsyncValue<ServiceCatalogData> catalogAsync;
  final VoidCallback onAddFromCatalog;
  final VoidCallback? onAddCustom;
  final void Function(ServiceItem) onEdit;
  final void Function(ServiceItem) onDelete;
  final VoidCallback? onEditCategory;
  final String Function(int) durationStr;

  @override
  Widget build(BuildContext context) {
    if (category == null) {
      return Center(
        child: Text(
          'Создайте категорию слева',
          style: DesktopDesignSystem.bodySecondary,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColorsDesktop.nestedBg.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(
                  DesktopDesignSystem.radiusContainer,
                ),
                border: Border.all(color: AppColorsDesktop.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Три способа',
                    style: DesktopDesignSystem.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ServiceHintLine(
                    icon: Icons.library_add_check_outlined,
                    title: 'Из справочника',
                    subtitle:
                        'Общая строка для всех организаций; сразу в вашем прайсе.',
                  ),
                  const SizedBox(height: 6),
                  _ServiceHintLine(
                    icon: Icons.edit_note_rounded,
                    title: 'Своя услуга',
                    subtitle:
                        'Только у вас; название любое; в общий список не уходит.',
                  ),
                  const SizedBox(height: 6),
                  _ServiceHintLine(
                    icon: Icons.outgoing_mail,
                    title: 'Запросить в справочник',
                    subtitle:
                        'Нет в списке — письмо разработчикам; в прайс не добавляет.',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category!.name,
                    style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 18),
                  ),
                ),
                if (onEditCategory != null)
                  IconButton(
                    tooltip: 'Переименовать категорию',
                    onPressed: onEditCategory,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColorsDesktop.textSecondary,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: catalogAsync.isLoading ? null : onAddFromCatalog,
                  icon: const Icon(Icons.library_add_check_outlined, size: 18),
                  label: const Text('Из справочника'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColorsDesktop.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onAddCustom,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Своя услуга'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColorsDesktop.textPrimary,
                    side: const BorderSide(color: AppColorsDesktop.border),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: services.isEmpty
                ? Center(
                    child: Text(
                      'Нет услуг в этой категории.\nДобавьте из справочника или свою позицию.',
                      textAlign: TextAlign.center,
                      style: DesktopDesignSystem.bodySecondary,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: services.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = services[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColorsDesktop.nestedBg.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(
                            DesktopDesignSystem.radiusContainer,
                          ),
                          border: Border.all(
                            color: AppColorsDesktop.border.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (s.isFromCatalog)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColorsDesktop.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            'Справочник',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColorsDesktop.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${formatMoney(s.priceKopecks)} · ${durationStr(s.durationMinutes)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColorsDesktop.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Изменить',
                              onPressed: () => onEdit(s),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColorsDesktop.textSecondary,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => onDelete(s),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColorsDesktop.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServiceHintLine extends StatelessWidget {
  const _ServiceHintLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColorsDesktop.primary.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DesktopDesignSystem.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: DesktopDesignSystem.meta.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
