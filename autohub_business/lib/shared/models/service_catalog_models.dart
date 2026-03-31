/// Позиция единого справочника услуг (бэкенд GET /reference/service-catalog).
class ServiceCatalogItemRef {
  final String id;
  final String name;
  final int defaultDurationMinutes;
  final String? requiredSkill;
  final int sortOrder;

  const ServiceCatalogItemRef({
    required this.id,
    required this.name,
    required this.defaultDurationMinutes,
    this.requiredSkill,
    this.sortOrder = 0,
  });

  factory ServiceCatalogItemRef.fromJson(Map<String, dynamic> j) {
    final dur = j['default_duration_minutes'] ?? j['defaultDurationMinutes'];
    final skill = j['required_skill'] ?? j['requiredSkill'];
    final sort = j['sort_order'] ?? j['sortOrder'];
    return ServiceCatalogItemRef(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      defaultDurationMinutes: (dur is num) ? dur.toInt() : int.tryParse('$dur') ?? 60,
      requiredSkill: skill?.toString(),
      sortOrder: (sort is num) ? sort.toInt() : int.tryParse('$sort') ?? 0,
    );
  }
}

class ServiceCatalogCategoryRef {
  final String categoryKey;
  final String categoryName;
  final List<ServiceCatalogItemRef> items;

  const ServiceCatalogCategoryRef({
    required this.categoryKey,
    required this.categoryName,
    required this.items,
  });

  factory ServiceCatalogCategoryRef.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final list = raw is List<dynamic>
        ? raw.map((e) => ServiceCatalogItemRef.fromJson(e as Map<String, dynamic>)).toList()
        : <ServiceCatalogItemRef>[];
    return ServiceCatalogCategoryRef(
      categoryKey: j['category_key']?.toString() ?? j['categoryKey']?.toString() ?? '',
      categoryName: j['category_name']?.toString() ?? j['categoryName']?.toString() ?? '',
      items: list,
    );
  }
}

class ServiceCatalogData {
  final List<ServiceCatalogCategoryRef> categories;

  const ServiceCatalogData({required this.categories});

  static const empty = ServiceCatalogData(categories: []);

  factory ServiceCatalogData.fromJson(Map<String, dynamic> j) {
    final raw = j['categories'];
    final list = raw is List<dynamic>
        ? raw.map((e) => ServiceCatalogCategoryRef.fromJson(e as Map<String, dynamic>)).toList()
        : <ServiceCatalogCategoryRef>[];
    return ServiceCatalogData(categories: list);
  }

  ServiceCatalogItemRef? itemById(String id) {
    if (id.isEmpty) return null;
    for (final c in categories) {
      for (final i in c.items) {
        if (i.id == id) return i;
      }
    }
    return null;
  }

  /// Все позиции плоским списком (для поиска).
  List<({ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item})> get allItems {
    final out = <({ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item})>[];
    for (final c in categories) {
      for (final i in c.items) {
        out.add((cat: c, item: i));
      }
    }
    return out;
  }
}
