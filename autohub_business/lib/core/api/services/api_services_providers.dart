import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/service_catalog_models.dart';
import '../api_client.dart';
import 'auth_api_service.dart';
import 'order_api_service.dart';
import 'chat_api_service.dart';
import 'organization_api_service.dart';
import 'staff_api_service.dart';
import 'settings_api_service.dart';
import 'service_catalog_api_service.dart';
import 'reference_api_service.dart';
import '../../../shared/models/car_reference_models.dart';
import '../../../core/utils/russian_plate_utils.dart';
import 'notifications_api_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final orderApiServiceProvider = Provider<OrderApiService>((ref) {
  return OrderApiService(ref.watch(apiClientProvider));
});

/// Байты фото по заказу (для отображения с авторизацией).
final orderPhotoBytesProvider = FutureProvider.family<Uint8List?, (String, String)>((ref, key) async {
  final (orderId, photoId) = key;
  final api = ref.read(orderApiServiceProvider);
  final r = await api.getOrderPhotoBytes(orderId, photoId);
  return r.dataOrNull;
});

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(apiClientProvider));
});

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService(ref.watch(apiClientProvider));
});

final organizationApiServiceProvider = Provider<OrganizationApiService>((ref) {
  return OrganizationApiService(ref.watch(apiClientProvider));
});

final staffApiServiceProvider = Provider<StaffApiService>((ref) {
  return StaffApiService(ref.watch(apiClientProvider));
});

final settingsApiServiceProvider = Provider<SettingsApiService>((ref) {
  return SettingsApiService(ref.watch(apiClientProvider));
});

final serviceCatalogApiServiceProvider = Provider<ServiceCatalogApiService>((ref) {
  return ServiceCatalogApiService(ref.watch(apiClientProvider));
});

final serviceCatalogDataProvider = FutureProvider<ServiceCatalogData>((ref) async {
  final api = ref.watch(serviceCatalogApiServiceProvider);
  final r = await api.getCatalog();
  return r.when(
    success: (d) => d,
    failure: (e) => throw e,
  );
});

final referenceApiServiceProvider = Provider<ReferenceApiService>((ref) {
  return ReferenceApiService(ref.watch(apiClientProvider));
});

final carReferenceBrandsProvider = FutureProvider<List<CarBrandRef>>((ref) async {
  final api = ref.watch(referenceApiServiceProvider);
  final r = await api.getCarBrands();
  return r.when(success: (d) => d, failure: (e) => throw e);
});

final carReferenceModelsProvider = FutureProvider.family<List<CarModelRef>, int>((ref, brandId) async {
  final api = ref.watch(referenceApiServiceProvider);
  final r = await api.getCarModels(brandId);
  return r.when(success: (d) => d, failure: (e) => throw e);
});

final carReferenceGenerationsProvider = FutureProvider.family<List<CarGenerationRef>, int>((ref, modelId) async {
  final api = ref.watch(referenceApiServiceProvider);
  final r = await api.getCarGenerations(modelId);
  return r.when(success: (d) => d, failure: (e) => throw e);
});

/// Плоский список марка+модель для быстрого заказа (подсказки и блок «из справочника»).
final quickOrderCatalogPicksProvider = FutureProvider<List<QuickRefCarPick>>((ref) async {
  final api = ref.watch(referenceApiServiceProvider);
  final br = await api.getCarBrands();
  final brands = br.dataOrNull;
  if (brands == null || brands.isEmpty) return [];
  final out = <QuickRefCarPick>[];
  for (final b in brands) {
    final mr = await api.getCarModels(b.id);
    final models = mr.dataOrNull;
    if (models == null || models.isEmpty) continue;
    for (final m in models) {
      out.add(QuickRefCarPick(
        brandId: b.id,
        modelId: m.id,
        brandName: b.name,
        modelName: m.name,
      ));
    }
  }
  out.sort((a, b) => a.label.compareTo(b.label));
  return out;
});

final notificationsApiServiceProvider = Provider<NotificationsApiService>((ref) {
  return NotificationsApiService(ref.watch(apiClientProvider));
});
