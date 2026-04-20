import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/service_catalog_models.dart';

/// Поиск сверху: при непустом запросе — общий список совпадений по всему справочнику.
/// При пустом — вкладки по категориям справочника (Двигатель и т.д.).
class ServiceCatalogBrowser extends StatefulWidget {
  const ServiceCatalogBrowser({
    super.key,
    required this.data,
    required this.onItemTap,
    this.alreadyAddedCatalogItemIds = const {},
  });

  final ServiceCatalogData data;
  final void Function(ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item) onItemTap;

  /// Скрыть или пометить позиции уже в корзине / в прайсе.
  final Set<String> alreadyAddedCatalogItemIds;

  @override
  State<ServiceCatalogBrowser> createState() => _ServiceCatalogBrowserState();
}

class _ServiceCatalogBrowserState extends State<ServiceCatalogBrowser>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  TabController? _tc;
  int _len = 0;

  @override
  void dispose() {
    _search.dispose();
    _tc?.dispose();
    super.dispose();
  }

  void _syncTabs(int n) {
    if (n == _len && _tc != null) return;
    _tc?.dispose();
    _len = n;
    _tc = n > 0 ? TabController(length: n, vsync: this) : null;
  }

  List<({ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item})> _filteredFlat(String q) {
    final flat = widget.data.allItems;
    if (q.isEmpty) return flat;
    return flat.where((e) {
      final n = e.item.name.toLowerCase();
      final c = e.cat.categoryName.toLowerCase();
      return n.contains(q) || c.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.data.categories;
    _syncTabs(cats.length);
    final q = _search.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Поиск услуги по названию или разделу…',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.nestedBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.65), width: 1.5),
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: cats.isEmpty
              ? const Center(child: Text('Справочник пуст'))
              : q.isNotEmpty
                  ? _SearchResultsList(
                      items: _filteredFlat(q),
                      alreadyAdded: widget.alreadyAddedCatalogItemIds,
                      onTap: widget.onItemTap,
                    )
                  : _TabbedCategories(
                      categories: cats,
                      controller: _tc!,
                      alreadyAdded: widget.alreadyAddedCatalogItemIds,
                      onTap: widget.onItemTap,
                    ),
        ),
      ],
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.items,
    required this.alreadyAdded,
    required this.onTap,
  });

  final List<({ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item})> items;
  final Set<String> alreadyAdded;
  final void Function(ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.9)),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final added = alreadyAdded.contains(e.item.id);
        return ListTile(
          title: Text(
            e.item.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: added ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            e.cat.categoryName,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: added
              ? const Text('Уже в списке', style: TextStyle(fontSize: 12, color: AppColors.textTertiary))
              : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
          onTap: added ? null : () => onTap(e.cat, e.item),
        );
      },
    );
  }
}

class _TabbedCategories extends StatelessWidget {
  const _TabbedCategories({
    required this.categories,
    required this.controller,
    required this.alreadyAdded,
    required this.onTap,
  });

  final List<ServiceCatalogCategoryRef> categories;
  final TabController controller;
  final Set<String> alreadyAdded;
  final void Function(ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: controller,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [for (final c in categories) Tab(text: c.categoryName)],
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: [
              for (final c in categories)
                ListView.builder(
                  itemCount: c.items.length,
                  itemBuilder: (context, i) {
                    final item = c.items[i];
                    final added = alreadyAdded.contains(item.id);
                    return ListTile(
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: added ? AppColors.textTertiary : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${item.defaultDurationMinutes} мин',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: added
                          ? const Icon(Icons.check_circle_outline_rounded, color: AppColors.textTertiary)
                          : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      onTap: added ? null : () => onTap(c, item),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
