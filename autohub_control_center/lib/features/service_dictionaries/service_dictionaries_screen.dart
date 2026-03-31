import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class ServiceDictionariesScreen extends ConsumerStatefulWidget {
  const ServiceDictionariesScreen({super.key});

  @override
  ConsumerState<ServiceDictionariesScreen> createState() => _ServiceDictionariesScreenState();
}

class _ServiceDictionariesScreenState extends ConsumerState<ServiceDictionariesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _categoryTitle(Map<String, dynamic> m) {
    final name = m['category_name'] ?? m['categoryName'] ?? m['name'];
    final key = m['category_key'] ?? m['categoryKey'] ?? m['id'];
    if (name != null && '$name'.trim().isNotEmpty) return '$name';
    if (key != null && '$key'.trim().isNotEmpty) return '$key';
    return '—';
  }

  static String _categoryKey(Map<String, dynamic> m) {
    final key = m['category_key'] ?? m['categoryKey'];
    return key != null ? '$key' : '';
  }

  static List<dynamic> _categoryItems(Map<String, dynamic> m) {
    final raw = m['items'];
    return raw is List ? raw : <dynamic>[];
  }

  static int _totalServiceCount(List<dynamic> categories) {
    var n = 0;
    for (final e in categories) {
      if (e is Map) {
        n += _categoryItems(Map<String, dynamic>.from(e)).length;
      }
    }
    return n;
  }

  List<Map<String, dynamic>> _filteredCategories(List<dynamic> categories) {
    final qq = _query.trim().toLowerCase();
    if (qq.isEmpty) {
      return categories.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final out = <Map<String, dynamic>>[];
    for (final e in categories) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final title = _categoryTitle(m).toLowerCase();
      final key = _categoryKey(m).toLowerCase();
      final items = _categoryItems(m);
      final titleHit = title.contains(qq) || key.contains(qq);
      final sub = items.where((it) {
        if (it is! Map) return false;
        final im = Map<String, dynamic>.from(it);
        final name = '${im['name'] ?? ''}'.toLowerCase();
        final id = '${im['id'] ?? ''}'.toLowerCase();
        return name.contains(qq) || id.contains(qq);
      }).toList();
      if (titleHit) {
        final copy = Map<String, dynamic>.from(m);
        copy['items'] = List<dynamic>.from(items);
        out.add(copy);
      } else if (sub.isNotEmpty) {
        final copy = Map<String, dynamic>.from(m);
        copy['items'] = sub;
        out.add(copy);
      }
    }
    return out;
  }

  Future<void> _reload() async {
    ref.invalidate(serviceDictionariesProvider);
  }

  Future<void> _snack(String msg, {bool error = false}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onReorderCategory(String categoryKey, int delta) async {
    try {
      await ref.read(internalApiProvider).reorderServiceCatalogCategory(categoryKey: categoryKey, delta: delta);
      await _reload();
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _onReorderItem(String itemId, int delta) async {
    try {
      await ref.read(internalApiProvider).reorderServiceCatalogItem(id: itemId, delta: delta);
      await _reload();
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _confirmDeleteCategory(String categoryKey, String title, int itemCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория «$title» и все позиции ($itemCount шт.) будут удалены без восстановления.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(internalApiProvider).deleteServiceCatalogCategory(categoryKey);
      await _reload();
      await _snack('Категория удалена');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _confirmDeleteItem(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить услугу?'),
        content: Text('«$name» будет удалена из глобального каталога.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(internalApiProvider).deleteServiceCatalogItem(id);
      await _reload();
      await _snack('Позиция удалена');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceDictionariesProvider);
    return SectionScaffold(
      title: 'Справочники услуг',
      titleActions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: () => ref.invalidate(serviceDictionariesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: async.when(
        data: (data) {
          final categories = data['categories'] is List ? data['categories'] as List : <dynamic>[];
          final total = _totalServiceCount(categories);
          final allMaps = categories.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final filtered = _filteredCategories(categories);
          final searchActive = _query.trim().isNotEmpty;

          if (categories.isEmpty || total == 0) {
            return _EmptyCatalog(onRetry: _reload);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CatalogHeader(
                total: total,
                categoryCount: categories.length,
                searchController: _search,
                onAddCategory: () => _showAddCategoryDialogFixed(allMaps),
                onAddService: () => _showAddServiceDialog(allMaps),
              ),
              const SizedBox(height: 8),
              Text(
                'API: ${AppConfig.baseUrl} → internal/reference/service-catalog',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Ничего не найдено по запросу',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ),
                )
              else
                ...filtered.asMap().entries.map((entry) {
                  final displayIndex = entry.key;
                  final m = entry.value;
                  final catKey = _categoryKey(m);
                  final title = _categoryTitle(m);
                  final items = _categoryItems(m);
                  final canUp = !searchActive && displayIndex > 0;
                  final canDown = !searchActive && displayIndex < filtered.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CategoryCard(
                      title: title,
                      categoryKey: catKey,
                      items: items,
                      canMoveUp: canUp,
                      canMoveDown: canDown,
                      reorderHint: searchActive ? 'Сбросьте поиск, чтобы менять порядок категорий' : null,
                      onMoveUp: catKey.isEmpty || searchActive ? null : () => _onReorderCategory(catKey, -1),
                      onMoveDown: catKey.isEmpty || searchActive ? null : () => _onReorderCategory(catKey, 1),
                      onEditCategory: catKey.isEmpty
                          ? null
                          : () => _showEditCategoryDialog(catKey, title),
                      onDeleteCategory: catKey.isEmpty
                          ? null
                          : () => _confirmDeleteCategory(catKey, title, items.length),
                      onAddService: catKey.isEmpty
                          ? null
                          : () => _showAddServiceToCategory(catKey, title),
                      onEditItem: (id, name, dur, skill) => _showEditItemDialog(
                            id: id,
                            name: name,
                            durationMinutes: dur,
                            requiredSkill: skill,
                            allCategories: allMaps,
                            currentCategoryKey: catKey,
                          ),
                      onDeleteItem: _confirmDeleteItem,
                      onReorderItem: _onReorderItem,
                    ),
                  );
                }),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _ErrorCard(message: '$e', onRetry: _reload),
      ),
    );
  }

  Future<void> _showAddCategoryDialogFixed(List<Map<String, dynamic>> allCategories) async {
    final keyCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ключ — латиница, цифры и подчёркивание. Его видят интеграции и привязки организаций.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ключ категории',
                  border: OutlineInputBorder(),
                  hintText: 'my_category',
                ),
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название в приложении для бизнеса',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstCtrl,
                decoration: const InputDecoration(
                  labelText: 'Первая услуга (необязательно)',
                  border: OutlineInputBorder(),
                  hintText: 'Пусто — будет «Новая услуга»',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    final key = keyCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final first = firstCtrl.text.trim();
    keyCtrl.dispose();
    nameCtrl.dispose();
    firstCtrl.dispose();
    if (ok != true || !mounted) return;
    if (key.isEmpty || name.isEmpty) {
      await _snack('Заполните ключ и название', error: true);
      return;
    }
    try {
      await ref.read(internalApiProvider).createServiceCatalogCategory(
            categoryKey: key,
            categoryName: name,
            firstServiceName: first.isEmpty ? null : first,
          );
      await _reload();
      await _snack('Категория создана');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _showAddServiceDialog(List<Map<String, dynamic>> allCategories) async {
    if (allCategories.isEmpty) return;
    String? selectedKey = _categoryKey(allCategories.first);
    final nameCtrl = TextEditingController();
    final durCtrl = TextEditingController(text: '60');
    final skillCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Новая услуга'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedKey,
                      items: allCategories
                          .map((c) {
                            final k = _categoryKey(c);
                            if (k.isEmpty) return null;
                            return DropdownMenuItem(value: k, child: Text(_categoryTitle(c)));
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedKey = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Название услуги',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Длительность по умолчанию (мин)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skillCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Требуемый навык (необязательно)',
                    border: OutlineInputBorder(),
                    hintText: 'ENGINE, DIAGNOSTICS…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final dur = int.tryParse(durCtrl.text.trim()) ?? 60;
    final skill = skillCtrl.text.trim();
    nameCtrl.dispose();
    durCtrl.dispose();
    skillCtrl.dispose();
    if (ok != true || !mounted || selectedKey == null) return;
    if (name.isEmpty) {
      await _snack('Введите название услуги', error: true);
      return;
    }
    Map<String, dynamic>? cat;
    for (final c in allCategories) {
      if (_categoryKey(c) == selectedKey) {
        cat = c;
        break;
      }
    }
    final catName = cat != null ? _categoryTitle(cat) : '';
    try {
      await ref.read(internalApiProvider).createServiceCatalogItem(
            categoryKey: selectedKey!,
            categoryName: catName,
            name: name,
            defaultDurationMinutes: dur,
            requiredSkill: skill.isEmpty ? null : skill,
          );
      await _reload();
      await _snack('Услуга добавлена');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _showAddServiceToCategory(String categoryKey, String categoryTitle) async {
    final nameCtrl = TextEditingController();
    final durCtrl = TextEditingController(text: '60');
    final skillCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Услуга в «$categoryTitle»'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durCtrl,
                decoration: const InputDecoration(
                  labelText: 'Длительность (мин)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skillCtrl,
                decoration: const InputDecoration(
                  labelText: 'Навык (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final dur = int.tryParse(durCtrl.text.trim()) ?? 60;
    final skill = skillCtrl.text.trim();
    nameCtrl.dispose();
    durCtrl.dispose();
    skillCtrl.dispose();
    if (ok != true || !mounted) return;
    if (name.isEmpty) {
      await _snack('Введите название', error: true);
      return;
    }
    try {
      await ref.read(internalApiProvider).createServiceCatalogItem(
            categoryKey: categoryKey,
            categoryName: categoryTitle,
            name: name,
            defaultDurationMinutes: dur,
            requiredSkill: skill.isEmpty ? null : skill,
          );
      await _reload();
      await _snack('Услуга добавлена');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _showEditCategoryDialog(String categoryKey, String currentTitle) async {
    final nameCtrl = TextEditingController(text: currentTitle);
    final newKeyCtrl = TextEditingController(text: categoryKey);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Категория'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Новый ключ (осторожно: ломает старые привязки)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.none,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    final newName = nameCtrl.text.trim();
    final newKey = newKeyCtrl.text.trim();
    nameCtrl.dispose();
    newKeyCtrl.dispose();
    if (ok != true || !mounted) return;
    if (newName.isEmpty) {
      await _snack('Название не может быть пустым', error: true);
      return;
    }
    try {
      await ref.read(internalApiProvider).patchServiceCatalogCategory(
            categoryKey: categoryKey,
            categoryName: newName,
            newCategoryKey: newKey != categoryKey ? newKey : null,
          );
      await _reload();
      await _snack('Категория обновлена');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }

  Future<void> _showEditItemDialog({
    required String id,
    required String name,
    required int? durationMinutes,
    required String? requiredSkill,
    required List<Map<String, dynamic>> allCategories,
    required String currentCategoryKey,
  }) async {
    final nameCtrl = TextEditingController(text: name);
    final durCtrl = TextEditingController(text: '${durationMinutes ?? 60}');
    final skillCtrl = TextEditingController(text: requiredSkill ?? '');
    String? moveToKey = currentCategoryKey;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Услуга'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durCtrl,
                  decoration: const InputDecoration(labelText: 'Длительность (мин)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skillCtrl,
                  decoration: const InputDecoration(labelText: 'Навык', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: moveToKey,
                      items: allCategories
                          .map((c) {
                            final k = _categoryKey(c);
                            if (k.isEmpty) return null;
                            return DropdownMenuItem(value: k, child: Text(_categoryTitle(c)));
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      onChanged: (v) => setLocal(() => moveToKey = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    final newName = nameCtrl.text.trim();
    final dur = int.tryParse(durCtrl.text.trim());
    final skill = skillCtrl.text.trim();
    nameCtrl.dispose();
    durCtrl.dispose();
    skillCtrl.dispose();
    if (ok != true || !mounted || moveToKey == null) return;
    if (newName.isEmpty) {
      await _snack('Название не может быть пустым', error: true);
      return;
    }
    try {
      await ref.read(internalApiProvider).patchServiceCatalogItem(
            id: id,
            name: newName,
            defaultDurationMinutes: dur,
            requiredSkill: skill,
            categoryKey: moveToKey != currentCategoryKey ? moveToKey : null,
          );
      await _reload();
      await _snack('Сохранено');
    } catch (e) {
      await _snack('$e', error: true);
    }
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.total,
    required this.categoryCount,
    required this.searchController,
    required this.onAddCategory,
    required this.onAddService,
  });

  final int total;
  final int categoryCount;
  final TextEditingController searchController;
  final VoidCallback onAddCategory;
  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatChip(icon: Icons.folder_outlined, label: '$categoryCount категорий'),
                  _StatChip(icon: Icons.build_outlined, label: '$total услуг'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onAddCategory,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  label: const Text('Категория'),
                ),
                FilledButton.icon(
                  onPressed: onAddService,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Услуга'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            hintText: 'Поиск по категории, услуге или id…',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      searchController.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.categoryKey,
    required this.items,
    required this.canMoveUp,
    required this.canMoveDown,
    this.reorderHint,
    this.onMoveUp,
    this.onMoveDown,
    this.onEditCategory,
    this.onDeleteCategory,
    this.onAddService,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onReorderItem,
  });

  final String title;
  final String categoryKey;
  final List<dynamic> items;
  final bool canMoveUp;
  final bool canMoveDown;
  final String? reorderHint;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEditCategory;
  final VoidCallback? onDeleteCategory;
  final VoidCallback? onAddService;
  final void Function(String id, String name, int? dur, String? skill) onEditItem;
  final void Function(String id, String name) onDeleteItem;
  final void Function(String id, int delta) onReorderItem;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.surface,
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.category_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ключ: $categoryKey · ${items.length} поз.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: reorderHint ?? 'Выше',
                      onPressed: canMoveUp ? onMoveUp : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: reorderHint ?? 'Ниже',
                      onPressed: canMoveDown ? onMoveDown : null,
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Действия',
                      child: const Icon(Icons.more_vert_rounded),
                      onSelected: (v) {
                        if (v == 'edit') {
                          onEditCategory?.call();
                        } else if (v == 'add') {
                          onAddService?.call();
                        } else if (v == 'del') {
                          onDeleteCategory?.call();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Изменить'))),
                        const PopupMenuItem(value: 'add', child: ListTile(leading: Icon(Icons.add), title: Text('Добавить услугу'))),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'del',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline, color: AppColors.danger),
                            title: Text('Удалить категорию', style: TextStyle(color: AppColors.danger)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Нет позиций — добавьте услугу.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    final im = it is Map ? Map<String, dynamic>.from(it) : <String, dynamic>{};
                    final id = '${im['id'] ?? ''}';
                    final name = im['name']?.toString() ?? id;
                    final dur = im['default_duration_minutes'] ?? im['defaultDurationMinutes'];
                    final min = dur is num ? dur.toInt() : int.tryParse('$dur');
                    final skill = im['required_skill'] ?? im['requiredSkill'];
                    final skillStr = skill != null ? '$skill' : null;
                    return _ServiceRow(
                      name: name,
                      id: id,
                      minutes: min,
                      skill: skillStr,
                      canMoveUp: i > 0,
                      canMoveDown: i < items.length - 1,
                      onMoveUp: id.isEmpty ? null : () => onReorderItem(id, -1),
                      onMoveDown: id.isEmpty ? null : () => onReorderItem(id, 1),
                      onEdit: id.isEmpty ? null : () => onEditItem(id, name, min, skillStr),
                      onDelete: id.isEmpty ? null : () => onDeleteItem(id, name),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
    required this.id,
    required this.minutes,
    required this.skill,
    required this.canMoveUp,
    required this.canMoveDown,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
  });

  final String name;
  final String id;
  final int? minutes;
  final String? skill;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final sub = StringBuffer();
    if (minutes != null) sub.write('$minutes мин');
    if (skill != null && skill!.isNotEmpty) {
      if (sub.isNotEmpty) sub.write(' · ');
      sub.write(skill);
    }
    if (id.isNotEmpty) {
      if (sub.isNotEmpty) sub.write('\n');
      sub.write(id);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: 'Выше',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.north_rounded, size: 20),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: 'Ниже',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.south_rounded, size: 20),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (sub.isNotEmpty)
                    Text(
                      sub.toString(),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Изменить',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text(
            'Каталог пуст или без позиций',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Если API отвечает пустым списком: проверьте миграции и таблицу service_catalog_items. '
            'Базовый URL: ${AppConfig.baseUrl}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ошибка загрузки',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(message, style: const TextStyle(color: AppColors.danger, height: 1.4)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
