import 'reference_api_service.dart';

/// Встроенный справочник марок и моделей. Используется, если API недоступен или вернул пустой список.
class CarReferenceData {
  CarReferenceData._();

  static List<CarBrandDto> get bundledBrands {
    final list = <CarBrandDto>[];
    for (var i = 0; i < _brandsAndModels.length; i++) {
      list.add(CarBrandDto(id: i + 1, name: _brandsAndModels[i].name));
    }
    return list;
  }

  static List<CarModelDto> modelsForBrand(int brandId) {
    final index = brandId - 1;
    if (index < 0 || index >= _brandsAndModels.length) return [];
    final models = _brandsAndModels[index].models;
    return List.generate(models.length, (i) => CarModelDto(id: i + 1, name: models[i]));
  }

  /// Поколения для модели (встроенный справочник). Ключ: "brandName|modelName".
  static List<CarGenerationDto> generationsForModel(String brandName, String modelName) {
    final key = '$brandName|$modelName';
    final list = _bundledGenerations[key];
    if (list == null) return [];
    return List.generate(list.length, (i) => CarGenerationDto(id: i + 1, name: list[i]));
  }

  static const Map<String, List<String>> _bundledGenerations = {
    'Toyota|Camry': ['XV70 (8-е поколение)', 'XV50 (7-е поколение)', 'XV40 (6-е поколение)', 'XV30 (5-е поколение)', 'XV20 (4-е поколение)'],
    'Toyota|Corolla': ['E210 (12-е поколение)', 'E170 (11-е поколение)', 'E150 (10-е поколение)', 'E120 (9-е поколение)'],
    'Toyota|RAV4': ['XA50 (5-е поколение)', 'XA40 (4-е поколение)', 'XA30 (3-е поколение)'],
    'Toyota|Yaris': ['XP210 (4-е поколение)', 'XP150 (3-е поколение)', 'XP90 (2-е поколение)'],
    'Lada|Vesta': ['Vesta 2 (рестайлинг)', 'Vesta 1'],
    'Lada|Granta': ['Granta 2 (рестайлинг)', 'Granta 1'],
    'Lada|Niva': ['Niva Legend (2121)', 'Niva Travel'],
    'Hyundai|Solaris': ['HC (2-е поколение, рестайлинг)', 'HC (2-е поколение)', 'RB (1-е поколение)'],
    'Hyundai|Creta': ['2-е поколение (рестайлинг)', '2-е поколение', '1-е поколение'],
    'Hyundai|Tucson': ['NX4 (4-е поколение)', 'TL (3-е поколение)', 'LM (2-е поколение)'],
    'Hyundai|Sonata': ['DN8 (8-е поколение)', 'LF (7-е поколение)', 'YF (6-е поколение)'],
    'Kia|Rio': ['QB (4-е поколение, рестайлинг)', 'QB (4-е поколение)', 'UB (3-е поколение)', 'JB (2-е поколение)'],
    'Kia|Sportage': ['NQ5 (5-е поколение)', 'QL (4-е поколение)', 'SL (3-е поколение)', 'KM (2-е поколение)'],
    'Kia|Sorento': ['MQ4 (4-е поколение)', 'UM (3-е поколение)', 'XM (2-е поколение)'],
    'Volkswagen|Polo': ['6-е поколение (рестайлинг)', '6-е поколение', '5-е поколение (6c)', '5-е поколение (6)'],
    'Volkswagen|Tiguan': ['BWD (2-е поколение, рестайлинг)', 'BWD (2-е поколение)', '5N (1-е поколение)'],
    'Volkswagen|Passat': ['B8 (8-е поколение, рестайлинг)', 'B8 (8-е поколение)', 'B7 (7-е поколение)', 'B6 (6-е поколение)'],
    'Volkswagen|Golf': ['Mk8 (8-е поколение)', 'Mk7 (7-е поколение)', 'Mk6 (6-е поколение)', 'Mk5 (5-е поколение)'],
    'Skoda|Octavia': ['4-е поколение (рестайлинг)', '4-е поколение', '3-е поколение', '2-е поколение'],
    'Skoda|Rapid': ['Рестайлинг', '1-е поколение'],
    'Skoda|Kodiaq': ['Рестайлинг', '1-е поколение'],
    'Renault|Logan': ['3-е поколение', '2-е поколение', '1-е поколение'],
    'Renault|Duster': ['2-е поколение (рестайлинг)', '2-е поколение', '1-е поколение'],
    'Renault|Sandero': ['3-е поколение', '2-е поколение', '1-е поколение'],
    'Renault|Kaptur': ['Рестайлинг', '1-е поколение'],
    'Nissan|Qashqai': ['3-е поколение (J12)', '2-е поколение (J11)', '1-е поколение (J10)'],
    'Nissan|X-Trail': ['4-е поколение (T33)', '3-е поколение (T32)', '2-е поколение (T31)', '1-е поколение (T30)'],
    'BMW|3': ['G20/G21 (7-е поколение)', 'F30/F31 (6-е поколение)', 'E90/E91 (5-е поколение)'],
    'BMW|5': ['G30/G31 (7-е поколение)', 'F10/F11 (6-е поколение)', 'E60/E61 (5-е поколение)'],
    'BMW|X3': ['G01 (3-е поколение)', 'F25 (2-е поколение)', 'E83 (1-е поколение)'],
    'BMW|X5': ['G05 (4-е поколение)', 'F15 (3-е поколение)', 'E70 (2-е поколение)', 'E53 (1-е поколение)'],
    'Mercedes-Benz|C-Class': ['W206 (5-е поколение)', 'W205 (4-е поколение)', 'W204 (3-е поколение)'],
    'Mercedes-Benz|E-Class': ['W214 (6-е поколение)', 'W213 (5-е поколение)', 'W212 (4-е поколение)'],
    'Audi|A4': ['B9 (5-е поколение, рестайлинг)', 'B9 (5-е поколение)', 'B8 (4-е поколение)'],
    'Audi|A6': ['C8 (5-е поколение)', 'C7 (4-е поколение)', 'C6 (3-е поколение)'],
    'Mazda|3': ['BP (4-е поколение)', 'BM (3-е поколение)', 'BL (2-е поколение)'],
    'Mazda|6': ['GJ (3-е поколение)', 'GH (2-е поколение)'],
    'Mazda|CX-5': ['KF (2-е поколение)', 'KE (1-е поколение)'],
    'Ford|Focus': ['4-е поколение', '3-е поколение', '2-е поколение'],
    'Ford|Kuga': ['4-е поколение', '3-е поколение', '2-е поколение'],
    'Chevrolet|Niva': ['2-е поколение', '1-е поколение'],
    'Honda|Civic': ['11-е поколение', '10-е поколение', '9-е поколение'],
    'Honda|CR-V': ['6-е поколение', '5-е поколение', '4-е поколение'],
    'Mitsubishi|Outlander': ['4-е поколение', '3-е поколение', '2-е поколение'],
    'UAZ|Patriot': ['Рестайлинг', '1-е поколение'],
    'Haval|H6': ['3-е поколение', '2-е поколение', '1-е поколение'],
    'Chery|Tiggo 7': ['Pro', '1-е поколение'],
    'Chery|Tiggo 8': ['Pro Max', 'Pro', '1-е поколение'],
  };

  static const List<({String name, List<String> models})> _brandsAndModels = [
    (name: 'Lada', models: ['Vesta', 'Granta', 'XRAY', 'Largus', 'Niva', 'Niva Travel']),
    (name: 'Toyota', models: ['Camry', 'Corolla', 'RAV4', 'Land Cruiser', 'Land Cruiser Prado', 'Hilux', 'Highlander', 'Yaris', 'C-HR']),
    (name: 'Hyundai', models: ['Solaris', 'Creta', 'Tucson', 'Santa Fe', 'Sonata', 'Elantra', 'Palisade', 'Kona']),
    (name: 'Kia', models: ['Rio', 'Sportage', 'Sorento', 'Optima', 'K5', 'Seltos', 'Cerato', 'Carnival', 'Niro']),
    (name: 'Volkswagen', models: ['Polo', 'Tiguan', 'Passat', 'Touareg', 'Golf', 'Jetta', 'T-Roc', 'Caddy']),
    (name: 'Skoda', models: ['Octavia', 'Rapid', 'Kodiaq', 'Karoq', 'Kamiq', 'Superb', 'Fabia']),
    (name: 'Renault', models: ['Logan', 'Duster', 'Sandero', 'Kaptur', 'Arkana', 'Koleos', 'Megane', 'Clio']),
    (name: 'Nissan', models: ['Qashqai', 'X-Trail', 'Terrano', 'Murano', 'Kicks', 'Pathfinder', 'Patrol']),
    (name: 'BMW', models: ['3', '5', '7', 'X1', 'X3', 'X5', 'X7', 'iX', 'i4']),
    (name: 'Mercedes-Benz', models: ['C-Class', 'E-Class', 'S-Class', 'GLA', 'GLB', 'GLC', 'GLE', 'GLS']),
    (name: 'Audi', models: ['A3', 'A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8', 'e-tron']),
    (name: 'Ford', models: ['Focus', 'Mondeo', 'Explorer', 'F-150', 'Mustang', 'Kuga', 'Puma']),
    (name: 'Chevrolet', models: ['Niva', 'Aveo', 'Cruze', 'Orlando', 'Trailblazer', 'Tahoe']),
    (name: 'Mazda', models: ['3', '6', 'CX-5', 'CX-30', 'CX-60', 'CX-90']),
    (name: 'Honda', models: ['Accord', 'Civic', 'CR-V', 'Pilot', 'HR-V', 'Jazz']),
    (name: 'Mitsubishi', models: ['Outlander', 'Pajero Sport', 'L200', 'ASX', 'Eclipse Cross']),
    (name: 'Geely', models: ['Coolray', 'Atlas', 'Monjaro', 'Tugella', 'Emgrand']),
    (name: 'Haval', models: ['F7', 'H6', 'H9', 'Jolion', 'Dargo']),
    (name: 'Chery', models: ['Tiggo 7', 'Tiggo 8', 'Tiggo 4', 'Arrizo 6', 'Omoda 5']),
    (name: 'UAZ', models: ['Patriot', 'Hunter', 'Pickup', 'Profi']),
    (name: 'GAZ', models: ['Gazelle', 'Sobol', 'Valdai']),
    (name: 'Lexus', models: ['ES', 'RX', 'NX', 'LX', 'LS', 'IS', 'UX']),
    (name: 'Volvo', models: ['S60', 'S90', 'XC40', 'XC60', 'XC90']),
    (name: 'Tesla', models: ['Model 3', 'Model Y', 'Model S', 'Model X']),
    (name: 'BYD', models: ['Atto 3', 'Han', 'Tang', 'Seal', 'Dolphin']),
  ];
}
