import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/settings_models.dart';
import '../../shared/models/service_catalog_models.dart';
import '../../shared/models/sto_amenity_catalog.dart';
import '../api/services/api_services_providers.dart';
import '../api/services/settings_api_service.dart';
import '../auth/auth_provider.dart';
import 'organization_repository.dart';

const _kCategoriesPrefix = 'settings_categories_';
const _kServicesPrefix = 'settings_services_';
const _kPackagesPrefix = 'settings_packages_';
const _kBrandsPrefix = 'settings_brands_';
const _kSlotsPrefix = 'settings_slots_';
const _kNotificationsPrefix = 'settings_notifications_';
const _kTemplatesPrefix = 'settings_templates_';
const _kAmenitiesPrefix = 'settings_amenities_';
const _kPublicDescPrefix = 'settings_public_desc_';

/// Репозиторий настроек: загрузка с API (GET), сохранение через API (PATCH) после каждой мутации + кэш в prefs по orgId.
class SettingsRepository extends StateNotifier<SettingsState> {
  SettingsRepository(this._api, this._prefs, this._ref)
    : super(SettingsState()) {
    final orgId = _ref.read(authProvider).user?.effectiveOrganizationId;
    _orgId = orgId;
    state = _loadFromPrefs(_prefs, orgId);
    load(orgId);
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final nextId = next.user?.effectiveOrganizationId;
      if (nextId != _orgId) load(nextId);
    });
  }

  final SettingsApiService _api;
  final SharedPreferences _prefs;
  final Ref _ref;
  String? _orgId;

  String _key(String prefix) => prefix + (_orgId ?? '');

  static SettingsState _loadFromPrefs(SharedPreferences prefs, String? orgId) {
    if (orgId == null || orgId.isEmpty)
      return SettingsState(
        categories: _defaultCategories(),
        services: _defaultServices(),
        carBrands: _defaultBrands(),
        amenityIds: const [],
        publicDescription: '',
        packages: const [],
        slotsSettings: const SlotsSettings(),
        notificationSettings: const NotificationSettings(),
        messageTemplates: _defaultTemplates(),
      );
    final categories = _loadCategories(prefs, orgId);
    final services = _loadServices(prefs, orgId);
    final brands = _loadBrands(prefs, orgId);
    final packages = _loadPackages(prefs, orgId);
    final slots = _loadSlots(prefs, orgId);
    final notifications = _loadNotifications(prefs, orgId);
    final templates = _loadTemplates(prefs, orgId);
    final amenityIds = _loadAmenityIds(prefs, orgId);
    final publicDescription = _loadPublicDescription(prefs, orgId);
    return SettingsState(
      categories: categories,
      services: services,
      packages: packages,
      carBrands: brands,
      amenityIds: amenityIds,
      publicDescription: publicDescription,
      slotsSettings: slots,
      notificationSettings: notifications,
      messageTemplates: templates,
    );
  }

  static List<String> _loadAmenityIds(SharedPreferences prefs, String orgId) {
    final raw = prefs.getString(_kAmenitiesPrefix + orgId);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => e.toString())
          .where((id) => StoAmenityCatalog.ids.contains(id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _loadPublicDescription(SharedPreferences prefs, String orgId) {
    return prefs.getString(_kPublicDescPrefix + orgId) ?? '';
  }

  static List<ServiceCategory> _loadCategories(
    SharedPreferences prefs,
    String orgId,
  ) {
    final raw = prefs.getString(_kCategoriesPrefix + orgId);
    if (raw == null) return _defaultCategories();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultCategories();
    }
  }

  static List<ServiceItem> _loadServices(
    SharedPreferences prefs,
    String orgId,
  ) {
    final raw = prefs.getString(_kServicesPrefix + orgId);
    if (raw == null) return _defaultServices();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultServices();
    }
  }

  static List<String> _loadBrands(SharedPreferences prefs, String orgId) {
    final raw = prefs.getString(_kBrandsPrefix + orgId);
    if (raw == null) return _defaultBrands();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e as String).toList();
    } catch (_) {
      return _defaultBrands();
    }
  }

  static List<ServicePackage> _loadPackages(
    SharedPreferences prefs,
    String orgId,
  ) {
    final raw = prefs.getString(_kPackagesPrefix + orgId);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ServicePackage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static SlotsSettings _loadSlots(SharedPreferences prefs, String orgId) {
    final raw = prefs.getString(_kSlotsPrefix + orgId);
    if (raw == null) return const SlotsSettings();
    try {
      return SlotsSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SlotsSettings();
    }
  }

  static NotificationSettings _loadNotifications(
    SharedPreferences prefs,
    String orgId,
  ) {
    final raw = prefs.getString(_kNotificationsPrefix + orgId);
    if (raw == null) return const NotificationSettings();
    try {
      return NotificationSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const NotificationSettings();
    }
  }

  static List<MessageTemplate> _loadTemplates(
    SharedPreferences prefs,
    String orgId,
  ) {
    final raw = prefs.getString(_kTemplatesPrefix + orgId);
    if (raw == null) return _defaultTemplates();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultTemplates();
    }
  }

  static List<ServiceCategory> _defaultCategories() => [
    const ServiceCategory(id: 'cat_1', name: 'ТО и ремонт', order: 0),
    const ServiceCategory(id: 'cat_2', name: 'Шины и колёса', order: 1),
  ];

  static List<ServiceItem> _defaultServices() => [
    const ServiceItem(
      id: 's1',
      categoryId: 'cat_1',
      name: 'Замена масла',
      priceKopecks: 350000,
      durationMinutes: 60,
    ),
    const ServiceItem(
      id: 's2',
      categoryId: 'cat_1',
      name: 'Диагностика',
      priceKopecks: 200000,
      durationMinutes: 45,
    ),
    const ServiceItem(
      id: 's3',
      categoryId: 'cat_2',
      name: 'Шиномонтаж',
      priceKopecks: 400000,
      durationMinutes: 90,
    ),
  ];

  static List<String> _defaultBrands() => [
    'Toyota',
    'Honda',
    'BMW',
    'Volkswagen',
  ];

  static List<MessageTemplate> _defaultTemplates() => [
    const MessageTemplate(
      id: 't1',
      title: 'Подтверждение записи',
      body: 'Ваша запись подтверждена. Ждём вас в указанное время.',
    ),
    const MessageTemplate(
      id: 't2',
      title: 'Готово к выдаче',
      body: 'Ваш автомобиль готов к выдаче. Можете забирать.',
    ),
  ];

  void _saveCategories() {
    if (_orgId != null)
      _prefs.setString(
        _key(_kCategoriesPrefix),
        jsonEncode(state.categories.map((e) => e.toJson()).toList()),
      );
  }

  void _saveServices() {
    if (_orgId != null)
      _prefs.setString(
        _key(_kServicesPrefix),
        jsonEncode(state.services.map((e) => e.toJson()).toList()),
      );
  }

  void _savePackages() {
    if (_orgId != null)
      _prefs.setString(
        _key(_kPackagesPrefix),
        jsonEncode(state.packages.map((e) => e.toJson()).toList()),
      );
  }

  void _saveBrands() {
    if (_orgId != null)
      _prefs.setString(_key(_kBrandsPrefix), jsonEncode(state.carBrands));
  }

  void _saveSlots() {
    if (_orgId != null)
      _prefs.setString(
        _key(_kSlotsPrefix),
        jsonEncode(state.slotsSettings.toJson()),
      );
  }

  void _saveNotifications() {
    if (_orgId != null)
      _prefs.setString(
        _key(_kNotificationsPrefix),
        jsonEncode(state.notificationSettings.toJson()),
      );
  }

  void _saveTemplates() {
    if (_orgId != null)
      _prefs.setString(
        _key(_kTemplatesPrefix),
        jsonEncode(state.messageTemplates.map((e) => e.toJson()).toList()),
      );
  }

  void _saveAmenityIds() {
    if (_orgId != null) {
      _prefs.setString(_key(_kAmenitiesPrefix), jsonEncode(state.amenityIds));
    }
  }

  void _savePublicDescription() {
    if (_orgId != null) {
      _prefs.setString(_key(_kPublicDescPrefix), state.publicDescription);
    }
  }

  /// Загрузить настройки: при наличии orgId — GET API, иначе или при ошибке — из prefs.
  Future<void> load(String? orgId) async {
    _orgId = orgId;
    if (orgId == null || orgId.isEmpty) {
      if (mounted) state = _loadFromPrefs(_prefs, null);
      return;
    }
    final result = await _api.get(orgId);
    if (!mounted) return;
    final data = result.dataOrNull;
    if (data != null) {
      state = data;
      _saveCategories();
      _saveServices();
      _saveBrands();
      _savePackages();
      _saveSlots();
      _saveNotifications();
      _saveTemplates();
      _saveAmenityIds();
      _savePublicDescription();
    } else {
      state = _loadFromPrefs(_prefs, orgId);
    }
  }

  Future<void> _patchApi() async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) return;
    final result = await _api.update(orgId, state);
    final updated = result.dataOrNull;
    if (updated != null) {
      state = updated;
      _saveCategories();
      _saveServices();
      _saveBrands();
      _savePackages();
      _saveSlots();
      _saveNotifications();
      _saveTemplates();
      _saveAmenityIds();
      _savePublicDescription();
    }
  }

  /// Удобства для карточки в приложении клиента (только id из [StoAmenityCatalog]).
  void setAmenityIds(List<String> ids) {
    final next = ids.where((id) => StoAmenityCatalog.ids.contains(id)).toList();
    state = state.copyWith(amenityIds: next);
    _saveAmenityIds();
    _patchApi();
  }

  void toggleAmenity(String id) {
    if (!StoAmenityCatalog.byId.containsKey(id)) return;
    final list = List<String>.from(state.amenityIds);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    setAmenityIds(list);
  }

  void setPublicDescription(String text) {
    state = state.copyWith(publicDescription: text.trim());
    _savePublicDescription();
    _patchApi();
  }

  // Categories
  /// Категория организации по имени из справочника (совпадение по названию или новая).
  String categoryIdForCatalogCategory(ServiceCatalogCategoryRef cat) {
    for (final c in state.categories) {
      if (c.name.trim().toLowerCase() == cat.categoryName.trim().toLowerCase()) {
        return c.id;
      }
    }
    return addCategory(cat.categoryName);
  }

  /// Возвращает id созданной категории.
  String addCategory(String name) {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final order = state.categories.isEmpty
        ? 0
        : state.categories.map((e) => e.order).reduce((a, b) => a > b ? a : b) +
              1;
    state = state.copyWith(
      categories: [
        ...state.categories,
        ServiceCategory(id: id, name: name, order: order),
      ],
    );
    _saveCategories();
    _patchApi();
    return id;
  }

  /// Услуга из единого справочника (название — снимок для заказов; [catalogItemId] для связи со справочником).
  void addServiceFromCatalog({
    required String categoryId,
    required String catalogItemId,
    required String name,
    required int priceKopecks,
    required int durationMinutes,
    String? requiredSkill,
  }) {
    final id = 's_${DateTime.now().microsecondsSinceEpoch}_$catalogItemId';
    addService(
      ServiceItem(
        id: id,
        categoryId: categoryId,
        name: name,
        catalogItemId: catalogItemId,
        priceKopecks: priceKopecks,
        durationMinutes: durationMinutes,
        requiredSkill: requiredSkill,
      ),
    );
  }

  void updateCategory(ServiceCategory cat) {
    state = state.copyWith(
      categories: state.categories
          .map((e) => e.id == cat.id ? cat : e)
          .toList(),
    );
    _saveCategories();
    _patchApi();
  }

  /// Переставить категории в списке (удержание «ТО и обслуживание» первой при наличии).
  void reorderCategories(int oldIndex, int newIndex) {
    final sorted = sortedServiceCategoriesForDisplay(state.categories);
    if (oldIndex < 0 || oldIndex >= sorted.length) return;
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    if (ni < 0 || ni >= sorted.length) return;
    final moved = sorted.removeAt(oldIndex);
    sorted.insert(ni, moved);
    final ensured = _ensureToCategoryFirst(sorted);
    final renumbered = <ServiceCategory>[];
    for (var i = 0; i < ensured.length; i++) {
      renumbered.add(ensured[i].copyWith(order: i));
    }
    state = state.copyWith(categories: renumbered);
    _saveCategories();
    _patchApi();
  }

  static List<ServiceCategory> _ensureToCategoryFirst(List<ServiceCategory> list) {
    final idx = list.indexWhere((c) => c.name.trim().toLowerCase() == kToServiceCategoryName.toLowerCase());
    if (idx <= 0) return list;
    final t = list.removeAt(idx);
    return [t, ...list];
  }

  void deleteCategory(String id) {
    state = state.copyWith(
      categories: state.categories.where((e) => e.id != id).toList(),
      services: state.services.where((e) => e.categoryId != id).toList(),
      packages: state.packages.where((e) => e.categoryId != id).toList(),
    );
    _saveCategories();
    _saveServices();
    _savePackages();
    _patchApi();
  }

  // Services
  void addService(ServiceItem item) {
    state = state.copyWith(services: [...state.services, item]);
    _saveServices();
    _patchApi();
  }

  void updateService(ServiceItem item) {
    state = state.copyWith(
      services: state.services.map((e) => e.id == item.id ? item : e).toList(),
    );
    _saveServices();
    _patchApi();
  }

  void deleteService(String id) {
    state = state.copyWith(
      services: state.services.where((e) => e.id != id).toList(),
      packages: state.packages
          .map(
            (p) => p.copyWith(
              includedServiceIds: p.includedServiceIds
                  .where((sid) => sid != id)
                  .toList(),
              addons: p.addons.where((a) => a.serviceId != id).toList(),
            ),
          )
          .toList(),
    );
    _saveServices();
    _savePackages();
    _patchApi();
  }

  List<ServiceItem> servicesForCategory(String categoryId) =>
      state.services.where((s) => s.categoryId == categoryId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  // Packages
  void addPackage(ServicePackage item) {
    state = state.copyWith(packages: [...state.packages, item]);
    _savePackages();
    _patchApi();
  }

  void updatePackage(ServicePackage item) {
    state = state.copyWith(
      packages: state.packages.map((e) => e.id == item.id ? item : e).toList(),
    );
    _savePackages();
    _patchApi();
  }

  void deletePackage(String id) {
    state = state.copyWith(
      packages: state.packages.where((e) => e.id != id).toList(),
    );
    _savePackages();
    _patchApi();
  }

  List<ServicePackage> packagesForCategory(String categoryId) =>
      state.packages.where((p) => p.categoryId == categoryId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  // Brands
  void addBrand(String brand) {
    final trimmed = brand.trim();
    if (trimmed.isEmpty || state.carBrands.contains(trimmed)) return;
    state = state.copyWith(carBrands: [...state.carBrands, trimmed]..sort());
    _saveBrands();
    _patchApi();
  }

  void removeBrand(String brand) {
    state = state.copyWith(
      carBrands: state.carBrands.where((b) => b != brand).toList(),
    );
    _saveBrands();
    _patchApi();
  }

  // Slots
  void updateSlots(SlotsSettings s) {
    state = state.copyWith(slotsSettings: s);
    _saveSlots();
    _patchApi();
  }

  // Notifications
  void updateNotifications(NotificationSettings n) {
    state = state.copyWith(notificationSettings: n);
    _saveNotifications();
    _patchApi();
  }

  // Templates
  void addTemplate(MessageTemplate t) {
    state = state.copyWith(messageTemplates: [...state.messageTemplates, t]);
    _saveTemplates();
    _patchApi();
  }

  void updateTemplate(MessageTemplate t) {
    state = state.copyWith(
      messageTemplates: state.messageTemplates
          .map((e) => e.id == t.id ? t : e)
          .toList(),
    );
    _saveTemplates();
    _patchApi();
  }

  void deleteTemplate(String id) {
    state = state.copyWith(
      messageTemplates: state.messageTemplates
          .where((e) => e.id != id)
          .toList(),
    );
    _saveTemplates();
    _patchApi();
  }
}

final settingsRepositoryProvider =
    StateNotifierProvider<SettingsRepository, SettingsState>((ref) {
      final api = ref.watch(settingsApiServiceProvider);
      final prefs = ref.watch(sharedPreferencesOrgProvider).valueOrNull;
      return SettingsRepository(api, prefs ?? _StubPrefs(), ref);
    });

class _StubPrefs implements SharedPreferences {
  Set<String> get keys => {};
  @override
  Object? get(String key) => null;
  @override
  bool? getBool(String key) => null;
  @override
  int? getInt(String key) => null;
  @override
  double? getDouble(String key) => null;
  @override
  String? getString(String key) => null;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<bool> setBool(String key, bool value) async => false;
  @override
  Future<bool> setInt(String key, int value) async => false;
  @override
  Future<bool> setDouble(String key, double value) async => false;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
  @override
  Set<String> getKeys() => {};
  @override
  bool containsKey(String key) => false;
  @override
  Future<bool> commit() async => false;
  @override
  Future<bool> reload() async => false;
}
