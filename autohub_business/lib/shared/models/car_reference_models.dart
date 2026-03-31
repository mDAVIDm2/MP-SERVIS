/// Марка из GET /reference/car-brands.
class CarBrandRef {
  final int id;
  final String name;

  const CarBrandRef({required this.id, required this.name});

  factory CarBrandRef.fromJson(Map<String, dynamic> j) {
    return CarBrandRef(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
    );
  }
}

/// Модель из GET /reference/car-brands/:id/models.
class CarModelRef {
  final int id;
  final String name;

  const CarModelRef({required this.id, required this.name});

  factory CarModelRef.fromJson(Map<String, dynamic> j) {
    return CarModelRef(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
    );
  }
}

/// Поколение из GET /reference/car-models/:id/generations.
class CarGenerationRef {
  final int id;
  final String name;
  final int? yearFrom;
  final int? yearTo;

  const CarGenerationRef({
    required this.id,
    required this.name,
    this.yearFrom,
    this.yearTo,
  });

  factory CarGenerationRef.fromJson(Map<String, dynamic> j) {
    return CarGenerationRef(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      yearFrom: (j['yearFrom'] as num?)?.toInt() ?? (j['year_from'] as num?)?.toInt(),
      yearTo: (j['yearTo'] as num?)?.toInt() ?? (j['year_to'] as num?)?.toInt(),
    );
  }

  String get subtitle {
    if (yearFrom != null || yearTo != null) {
      final a = yearFrom?.toString() ?? '…';
      final b = yearTo?.toString() ?? '…';
      return '$a — $b';
    }
    return '';
  }
}
