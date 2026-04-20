import '../../../shared/models/car_model.dart';
import '../../../shared/models/order_model.dart';
import '../../api/api_exceptions.dart';
import '../../constants/mock_data.dart';
import '../car_repository.dart';

/// Мок-реализация CarRepository.
/// Работает с MockData. Когда появится API — заменим на ApiCarRepository.
class MockCarRepository implements CarRepository {
  @override
  Future<Result<List<Car>>> getCars() async {
    await _simulateDelay();
    return Result.success(List.from(MockData.cars));
  }

  @override
  Future<Result<Car>> getCarById(String id) async {
    await _simulateDelay();
    try {
      final car = MockData.cars.firstWhere((c) => c.id == id);
      return Result.success(car);
    } catch (_) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
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
    await _simulateDelay(800);

    final newCar = Car(
      id: (preferredId != null && preferredId.trim().isNotEmpty)
          ? preferredId.trim()
          : 'car_${DateTime.now().millisecondsSinceEpoch}',
      brand: brandName,
      model: modelName,
      generation: generation,
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      year: year,
      plateNumber: licensePlate,
      mileage: mileage ?? 0,
      vin: vin,
      nickname: nickname,
      engineType: engineType,
      transmission: transmission,
      drivetrain: drivetrain,
      bodyType: bodyType,
      color: color,
      reminders: [],
      mergedFromOrders: mergedFromOrders,
    );

    MockData.cars.add(newCar);
    return Result.success(newCar);
  }

  @override
  Future<Result<Car>> updateCar(String id, {
    String? nickname,
    String? licensePlate,
    int? mileage,
    String? vin,
  }) async {
    await _simulateDelay();
    final index = MockData.cars.indexWhere((c) => c.id == id);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
    }
    return Result.success(MockData.cars[index]);
  }

  @override
  Future<Result<Car>> updateCarReference(String id, {
    required int brandId,
    required int modelId,
    required int generationId,
    required String brandName,
    required String modelName,
    required String generationName,
  }) async {
    await _simulateDelay();
    final index = MockData.cars.indexWhere((c) => c.id == id);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
    }
    final old = MockData.cars[index];
    final updated = Car(
      id: old.id,
      brand: brandName,
      model: modelName,
      generation: generationName,
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      year: old.year,
      nickname: old.nickname,
      plateNumber: old.plateNumber,
      vin: old.vin,
      mileage: old.mileage,
      engineType: old.engineType,
      transmission: old.transmission,
      drivetrain: old.drivetrain,
      color: old.color,
      photoUrl: old.photoUrl,
      reminders: old.reminders,
    );
    MockData.cars[index] = updated;
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
    await _simulateDelay();
    final index = MockData.cars.indexWhere((c) => c.id == id);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
    }
    final old = MockData.cars[index];
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
    MockData.cars[index] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<Car>> updateMileage(String carId, int newMileage) async {
    await _simulateDelay(500);
    final index = MockData.cars.indexWhere((c) => c.id == carId);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
    }

    final car = MockData.cars[index];
    if (newMileage <= car.mileage) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.validation,
        message: 'Новый пробег должен быть больше текущего',
      ));
    }

    // Мутируем мок-данные
    MockData.cars[index] = Car(
      id: car.id,
      brand: car.brand,
      model: car.model,
      generation: car.generation,
      brandId: car.brandId,
      modelId: car.modelId,
      generationId: car.generationId,
      year: car.year,
      plateNumber: car.plateNumber,
      mileage: newMileage,
      vin: car.vin,
      color: car.color,
      reminders: car.reminders,
    );

    return Result.success(MockData.cars[index]);
  }

  @override
  Future<Result<Car>> updateCarPhoto(String carId, String? photoUrl) async {
    await _simulateDelay(300);
    final index = MockData.cars.indexWhere((c) => c.id == carId);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
    }
    final car = MockData.cars[index];
    final updated = Car(
      id: car.id,
      brand: car.brand,
      model: car.model,
      generation: car.generation,
      brandId: car.brandId,
      modelId: car.modelId,
      generationId: car.generationId,
      year: car.year,
      nickname: car.nickname,
      plateNumber: car.plateNumber,
      vin: car.vin,
      mileage: car.mileage,
      engineType: car.engineType,
      transmission: car.transmission,
      drivetrain: car.drivetrain,
      color: car.color,
      photoUrl: photoUrl,
      reminders: car.reminders,
    );
    MockData.cars[index] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> deleteCar(String id) async {
    await _simulateDelay();
    MockData.cars.removeWhere((c) => c.id == id);
    return Result.success(null);
  }

  @override
  Future<Result<List<CarReminder>>> getReminders(String carId) async {
    await _simulateDelay();
    try {
      final car = MockData.cars.firstWhere((c) => c.id == carId);
      return Result.success(car.reminders);
    } catch (_) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Автомобиль не найден',
      ));
    }
  }

  @override
  Future<Result<void>> dismissReminder(String carId, String reminderId) async {
    await _simulateDelay();
    return Result.success(null);
  }

  @override
  Future<Result<int>> mergeCarsFromOrders(
    Iterable<Order> orders, {
    Set<String> skipCarIds = const {},
  }) async =>
      Result.success(0);

  Future<void> _simulateDelay([int ms = 300]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }
}
