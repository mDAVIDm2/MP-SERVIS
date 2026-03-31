import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';

/// Частые запросы: новые заказы клиентов и заявки на авто в справочнике.
const Duration kControlCenterHotPollInterval = Duration(seconds: 6);

/// Реже: списки организаций, пользователей, аудит, подписки, карточка организации.
const Duration kControlCenterPollInterval = Duration(seconds: 12);

final organizationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getOrganizations();
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterPollInterval);
  }
});

final organizationDetailProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    yield await api.getOrganization(id);
    await Future<void>.delayed(kControlCenterPollInterval);
  }
});

final organizationStaffProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, organizationId) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getOrganizationStaff(organizationId);
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterPollInterval);
  }
});

final usersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getUsers();
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterPollInterval);
  }
});

List<dynamic> _ordersItemsFromPayload(Map<String, dynamic>? data) {
  if (data == null) return [];
  dynamic raw = data['items'];
  if (raw is! List) {
    final inner = data['data'];
    if (inner is Map && inner['items'] is List) raw = inner['items'];
  }
  if (raw is! List && data['orders'] is List) raw = data['orders'];
  if (raw is! List) return [];
  return raw;
}

int _ordersTotalFromPayload(Map<String, dynamic>? data, int itemsLen) {
  if (data == null) return itemsLen;
  final t = data['total'];
  if (t is int) return t;
  if (t is num) return t.round();
  return itemsLen;
}

final ordersProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, ({int limit, int offset})>((ref, params) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getOrders(limit: params.limit, offset: params.offset);
    final items = _ordersItemsFromPayload(data);
    final total = _ordersTotalFromPayload(data, items.length);
    yield {'items': items, 'total': total};
    await Future<void>.delayed(kControlCenterHotPollInterval);
  }
});

final subscriptionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getSubscriptions();
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterPollInterval);
  }
});

/// Справочник марок обновляется реже; интервал длиннее, чтобы не дёргать API без нужды.
const Duration _carBrandsPollInterval = Duration(seconds: 45);

final carBrandsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final list = await api.getCarBrands();
    if (list == null) {
      yield [];
    } else {
      yield list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    await Future<void>.delayed(_carBrandsPollInterval);
  }
});

final carModelsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, brandId) async {
  final api = ref.watch(internalApiProvider);
  final list = await api.getCarModels(brandId);
  if (list == null) return [];
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final carGenerationsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, modelId) async {
  final api = ref.watch(internalApiProvider);
  final list = await api.getCarGenerations(modelId);
  if (list == null) return [];
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final pendingCarProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final list = await api.getPendingCar();
    if (list == null) {
      yield [];
    } else {
      yield list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    await Future<void>.delayed(kControlCenterHotPollInterval);
  }
});

final serviceDictionariesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(internalApiProvider);
  return api.fetchServiceDictionaries();
});

final auditProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>, ({int limit, int offset, String? from, String? to})>((ref, params) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getAudit(limit: params.limit, offset: params.offset, from: params.from, to: params.to);
    final items = data?['items'] is List ? data!['items'] as List : <dynamic>[];
    final total = data?['total'] is int ? data!['total'] as int : items.length;
    yield {'items': items, 'total': total};
    await Future<void>.delayed(kControlCenterPollInterval);
  }
});

final clientCarsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getClientCars();
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterHotPollInterval);
  }
});

final clientCarHistoryProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String clientPhone, String carId})>((ref, params) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getClientCarHistory(clientPhone: params.clientPhone, carId: params.carId);
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterHotPollInterval);
  }
});

final supportChatsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getSupportChats();
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterHotPollInterval);
  }
});

final supportChatMessagesProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, chatId) async* {
  while (true) {
    final api = ref.watch(internalApiProvider);
    final data = await api.getSupportChatMessages(chatId);
    final list = data?['items'];
    if (list is List) {
      yield List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      yield [];
    }
    await Future<void>.delayed(kControlCenterHotPollInterval);
  }
});
