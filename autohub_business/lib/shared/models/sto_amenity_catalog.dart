import 'package:flutter/foundation.dart';

/// Единый список удобств (id — ключ в API `amenity_ids` и в каталоге клиента).
@immutable
class StoAmenityDef {
  const StoAmenityDef({required this.id, required this.label});

  final String id;
  final String label;
}

/// Канонический список. Порядок — в UI выбора и на карточке СТО.
class StoAmenityCatalog {
  StoAmenityCatalog._();

  static const List<StoAmenityDef> all = [
    StoAmenityDef(id: 'waiting_room', label: 'Комната ожидания'),
    StoAmenityDef(id: 'tea_coffee', label: 'Чай / кофе'),
    StoAmenityDef(id: 'card_payment', label: 'Оплата картой'),
    StoAmenityDef(id: 'qr_payment', label: 'Оплата по QR'),
    StoAmenityDef(id: 'cash', label: 'Наличный расчёт'),
    StoAmenityDef(id: 'parking', label: 'Парковка'),
    StoAmenityDef(id: 'wifi', label: 'Wi‑Fi'),
    StoAmenityDef(id: 'wc', label: 'Туалет'),
    StoAmenityDef(id: 'ac', label: 'Кондиционер'),
    StoAmenityDef(id: 'own_parts', label: 'Свои запчасти'),
    StoAmenityDef(id: 'video_inspection', label: 'Видеоосмотр / отчёт'),
    StoAmenityDef(id: 'wheel_storage', label: 'Сезонное хранение шин'),
    StoAmenityDef(id: 'pickup_service', label: 'Забор / доставка авто'),
    StoAmenityDef(id: 'ev_charging', label: 'Зарядка электромобилей'),
    StoAmenityDef(id: 'water', label: 'Питьевая вода'),
    StoAmenityDef(id: 'children_corner', label: 'Детский уголок'),
    StoAmenityDef(id: 'shop_parts', label: 'Магазин при СТО'),
    StoAmenityDef(id: 'insurance_help', label: 'Помощь с ОСАГО / КАСКО'),
  ];

  static final Map<String, StoAmenityDef> byId = {
    for (final a in all) a.id: a,
  };

  static final Set<String> ids = {for (final a in all) a.id};

  /// В свёрнутом виде на карточке клиента показываем эти id первыми (если выбраны).
  static const Set<String> primaryIds = {'waiting_room', 'tea_coffee'};

  static String? labelForId(String id) => byId[id]?.label;
}
