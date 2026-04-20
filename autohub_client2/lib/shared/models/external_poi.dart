/// Внешняя организация (из OSM/Яндекс и т.п.): нет карточки в приложении, не партнёр.
/// Цвет маркера на карте задаётся по [types] (СТО / мойка / шины / прочее).
class ExternalPOI {
  final String id;
  final String name;
  final double lat;
  final double lng;
  /// Категории для фильтра карты (см. Overpass/Yandex): в т.ч. подтипы мойки
  /// «Мойка (самообслуживание)», «Мойка (робот)», «Мойка (классическая)».
  final List<String> types;
  final String? phone;
  final String? address;

  const ExternalPOI({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.types = const [],
    this.phone,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'types': types,
        'phone': phone,
        'address': address,
      };

  static ExternalPOI fromJson(Map<String, dynamic> map) => ExternalPOI(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        types: (map['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        phone: (map['phone'] as String?)?.isNotEmpty == true ? map['phone'] as String? : null,
        address: (map['address'] as String?)?.isNotEmpty == true ? map['address'] as String? : null,
      );
}
