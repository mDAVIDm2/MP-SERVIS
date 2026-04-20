import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/car_model.dart';
import '../../shared/models/order_model.dart';
import '../api/api_exceptions.dart';
import '../garage/garage_from_orders.dart';
import 'car_repository.dart';

/// Хранит машины в SharedPreferences по ключу cars_<userId>. У каждого аккаунта свой список.
class PrefsCarRepository implements CarRepository {
  PrefsCarRepository(this._prefs, this._userId);
  final SharedPreferences _prefs;
  final String? _userId;

  static const _prefix = 'cars_';
  static const _hiddenMergePrefix = 'garage_hidden_merge_car_ids_';

  String get _key => _prefix + (_userId ?? 'guest');

  String get _hiddenKey => _hiddenMergePrefix + (_userId ?? 'guest');

  Set<String> _loadHiddenMergeCarIds() {
    if (_userId == null || _userId.isEmpty) return {};
    final raw = _prefs.getString(_hiddenKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return {};
      return list.map((e) => '$e').where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  void _saveHiddenMergeCarIds(Set<String> ids) {
    if (_userId == null || _userId.isEmpty) return;
    _prefs.setString(_hiddenKey, jsonEncode(ids.toList()));
  }

  List<Car> _loadList() {
    if (_userId == null || _userId.isEmpty) return [];
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => Car.fromJson(e as Map<String, dynamic>))
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveList(List<Car> cars) {
    if (_userId == null || _userId.isEmpty) return;
    final list = cars.map((c) => c.toJson()).toList();
    _prefs.setString(_key, jsonEncode(list));
  }

  @override
  Future<Result<List<Car>>> getCars() async {
    return Result.success(_loadList());
  }

  @override
  Future<Result<Car>> getCarById(String id) async {
    final cars = _loadList();
    try {
      final car = cars.firstWhere((c) => c.id == id);
      return Result.success(car);
    } catch (_) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.notFound,
          message: 'Автомобиль не найден',
        ),
      );
    }
  }

  @override
  Future<Result<Car>> addCar({
    required String brandName,
    required String modelName,
    String? generation,
    int? brandId,
    int? modelId,
    int? generationId,
    required int year,
    String? licensePlate,
    int? mileage,
    String? vin,
    String? nickname,
    String? engineType,
    String? transmission,
    String? drivetrain,
    String? bodyType,
    String? color,
    String? preferredId,
    bool mergedFromOrders = false,
  }) async {
    if (_userId == null || _userId.isEmpty) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.unauthorized,
          message: 'Войдите в аккаунт',
        ),
      );
    }
    final cars = _loadList();
    final id = (preferredId != null && preferredId.trim().isNotEmpty)
        ? preferredId.trim()
        : 'car_${DateTime.now().millisecondsSinceEpoch}';
    final car = Car(
      id: id,
      brand: brandName,
      model: modelName,
      generation: generation,
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      year: year,
      nickname: nickname,
      plateNumber: licensePlate,
      vin: vin,
      mileage: mileage ?? 0,
      engineType: engineType,
      transmission: transmission,
      drivetrain: drivetrain,
      bodyType: bodyType,
      color: color,
    );
    cars.add(car);
    _saveList(cars);
    return Result.success(car);
  }

  @override
  Future<Result<Car>> updateCar(
    String id, {
    String? nickname,
    String? licensePlate,
    int? mileage,
    String? vin,
  }) async {
    final cars = _loadList();
    final index = cars.indexWhere((c) => c.id == id);
    if (index < 0) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.notFound,
          message: 'Автомобиль не найден',
        ),
      );
    }
    final old = cars[index];
    final updated = Car(
      id: old.id,
      brand: old.brand,
      model: old.model,
      generation: old.generation,
      brandId: old.brandId,
      modelId: old.modelId,
      generationId: old.generationId,
      year: old.year,
      nickname: nickname ?? old.nickname,
      plateNumber: licensePlate ?? old.plateNumber,
      vin: vin ?? old.vin,
      mileage: mileage ?? old.mileage,
      engineType: old.engineType,
      transmission: old.transmission,
      drivetrain: old.drivetrain,
      bodyType: old.bodyType,
      color: old.color,
      photoUrl: old.photoUrl,
      reminders: old.reminders,
      mergedFromOrders: old.mergedFromOrders,
    );
    cars[index] = updated;
    _saveList(cars);
    return Result.success(updated);
  }

  @override
  Future<Result<Car>> updateCarReference(
    String id, {
    required int brandId,
    required int modelId,
    required int generationId,
    required String brandName,
    required String modelName,
    required String generationName,
  }) async {
    final cars = _loadList();
    final index = cars.indexWhere((c) => c.id == id);
    if (index < 0) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.notFound,
          message: 'Автомобиль не найден',
        ),
      );
    }
    final old = cars[index];
    final useGeneration = generationId != 0 && generationName.trim().isNotEmpty;
    final updated = Car(
      id: old.id,
      brand: brandName,
      model: modelName,
      generation: useGeneration ? generationName.trim() : old.generation,
      brandId: brandId,
      modelId: modelId,
      generationId: useGeneration ? generationId : null,
      year: old.year,
      nickname: old.nickname,
      plateNumber: old.plateNumber,
      vin: old.vin,
      mileage: old.mileage,
      engineType: old.engineType,
      transmission: old.transmission,
      drivetrain: old.drivetrain,
      bodyType: old.bodyType,
      color: old.color,
      photoUrl: old.photoUrl,
      reminders: old.reminders,
      mergedFromOrders: false,
    );
    cars[index] = updated;
    _saveList(cars);
    return Result.success(updated);
  }

  @override
  Future<Result<Car>> patchCarGarageReference(
    String id, {
    required String brand,
    required String model,
    String? generation,
    int? brandId,
    int? modelId,
    int? generationId,
    String? nickname,
  }) async {
    final cars = _loadList();
    final index = cars.indexWhere((c) => c.id == id);
    if (index < 0) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.notFound,
          message: 'Автомобиль не найден',
        ),
      );
    }
    final old = cars[index];
    final updated = Car(
      id: old.id,
      brand: brand,
      model: model,
      generation: generation,
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      year: old.year,
      nickname: nickname,
      plateNumber: old.plateNumber,
      vin: old.vin,
      mileage: old.mileage,
      engineType: old.engineType,
      transmission: old.transmission,
      drivetrain: old.drivetrain,
      bodyType: old.bodyType,
      color: old.color,
      photoUrl: old.photoUrl,
      reminders: old.reminders,
      mergedFromOrders: old.mergedFromOrders,
    );
    cars[index] = updated;
    _saveList(cars);
    return Result.success(updated);
  }

  @override
  Future<Result<Car>> updateMileage(String carId, int newMileage) async {
    final cars = _loadList();
    final index = cars.indexWhere((c) => c.id == carId);
    if (index < 0) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.notFound,
          message: 'Автомобиль не найден',
        ),
      );
    }
    final old = cars[index];
    final updated = Car(
      id: old.id,
      brand: old.brand,
      model: old.model,
      generation: old.generation,
      brandId: old.brandId,
      modelId: old.modelId,
      generationId: old.generationId,
      year: old.year,
      nickname: old.nickname,
      plateNumber: old.plateNumber,
      vin: old.vin,
      mileage: newMileage,
      engineType: old.engineType,
      transmission: old.transmission,
      drivetrain: old.drivetrain,
      bodyType: old.bodyType,
      color: old.color,
      photoUrl: old.photoUrl,
      reminders: old.reminders,
      mergedFromOrders: old.mergedFromOrders,
    );
    cars[index] = updated;
    _saveList(cars);
    return Result.success(updated);
  }

  @override
  Future<Result<Car>> updateCarPhoto(String carId, String? photoUrl) async {
    final cars = _loadList();
    final index = cars.indexWhere((c) => c.id == carId);
    if (index < 0) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.notFound,
          message: 'Автомобиль не найден',
        ),
      );
    }
    final old = cars[index];
    final updated = Car(
      id: old.id,
      brand: old.brand,
      model: old.model,
      generation: old.generation,
      brandId: old.brandId,
      modelId: old.modelId,
      generationId: old.generationId,
      year: old.year,
      nickname: old.nickname,
      plateNumber: old.plateNumber,
      vin: old.vin,
      mileage: old.mileage,
      engineType: old.engineType,
      transmission: old.transmission,
      drivetrain: old.drivetrain,
      bodyType: old.bodyType,
      color: old.color,
      photoUrl: photoUrl,
      reminders: old.reminders,
      mergedFromOrders: old.mergedFromOrders,
    );
    cars[index] = updated;
    _saveList(cars);
    return Result.success(updated);
  }

  @override
  Future<Result<void>> deleteCar(String id) async {
    final cars = _loadList();
    cars.removeWhere((c) => c.id == id);
    _saveList(cars);
    final hidden = _loadHiddenMergeCarIds();
    hidden.add(id);
    _saveHiddenMergeCarIds(hidden);
    return Result.success(null);
  }

  @override
  Future<Result<List<CarReminder>>> getReminders(String carId) async {
    final result = await getCarById(carId);
    final car = result.dataOrNull;
    if (car == null) return Result.failure(result.errorOrNull!);
    return Result.success(car.reminders);
  }

  @override
  Future<Result<void>> dismissReminder(String carId, String reminderId) async {
    return Result.success(null);
  }

  @override
  Future<Result<int>> mergeCarsFromOrders(
    Iterable<Order> orders, {
    Set<String> skipCarIds = const {},
  }) async {
    if (_userId == null || _userId.isEmpty) {
      return Result.success(0);
    }
    final byCarId = <String, Order>{};
    for (final o in orders) {
      final cid = o.carId.trim();
      if (cid.isEmpty || cid == 'unknown') continue;
      final prev = byCarId[cid];
      if (prev == null || o.dateTime.isAfter(prev.dateTime)) {
        byCarId[cid] = o;
      }
    }
    if (byCarId.isEmpty) return Result.success(0);

    final hidden = {..._loadHiddenMergeCarIds(), ...skipCarIds};
    var changed = 0;
    final next = List<Car>.from(_loadList());

    for (final e in byCarId.entries) {
      if (hidden.contains(e.key)) continue;
      final idx = next.indexWhere((c) => c.id == e.key);
      if (idx < 0) {
        final car = carFromOrderSnapshot(e.value);
        if (car != null) {
          next.add(car);
          changed++;
        }
        continue;
      }

      final o = e.value;
      final old = next[idx];
      final newPhoto = _nonEmpty(old.photoUrl) ? old.photoUrl : _nonEmptyStr(o.carPhotoUrl);
      final newVin = _nonEmpty(old.vin) ? old.vin : _nonEmptyStr(o.vin);
      final newPlate = _nonEmpty(old.plateNumber) ? old.plateNumber : _nonEmptyStr(o.licensePlate);
      var newMileage = old.mileage;
      if (newMileage <= 0 && (o.mileage ?? 0) > 0) {
        newMileage = o.mileage!;
      }

      if (newPhoto != old.photoUrl ||
          newVin != old.vin ||
          newPlate != old.plateNumber ||
          newMileage != old.mileage) {
        next[idx] = Car(
          id: old.id,
          brand: old.brand,
          model: old.model,
          generation: old.generation,
          brandId: old.brandId,
          modelId: old.modelId,
          generationId: old.generationId,
          year: old.year,
          nickname: old.nickname,
          plateNumber: newPlate,
          vin: newVin,
          mileage: newMileage,
          engineType: old.engineType,
          transmission: old.transmission,
          drivetrain: old.drivetrain,
          bodyType: old.bodyType,
          color: old.color,
          photoUrl: newPhoto,
          reminders: old.reminders,
          mergedFromOrders: old.mergedFromOrders,
        );
        changed++;
      }
    }

    if (changed > 0) {
      _saveList(next);
    }
    return Result.success(changed);
  }

  static bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;

  static String? _nonEmptyStr(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
