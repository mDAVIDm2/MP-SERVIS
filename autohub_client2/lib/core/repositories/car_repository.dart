import '../../shared/models/car_model.dart';
import '../api/api_exceptions.dart';

/// Абстрактный репозиторий автомобилей.
/// Когда подключим бэкенд — создадим ApiCarRepository с тем же интерфейсом.
abstract class CarRepository {
  /// Получить все авто пользователя
  Future<Result<List<Car>>> getCars();

  /// Получить авто по ID
  Future<Result<Car>> getCarById(String id);

  /// Добавить авто. [brandId], [modelId], [generationId] — id из справочника; null = введено вручную (ожидает подтверждения).
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
  });

  /// Обновить авто
  Future<Result<Car>> updateCar(
    String id, {
    String? nickname,
    String? licensePlate,
    int? mileage,
    String? vin,
  });

  /// Обновить привязку к справочнику (после подтверждения админом марки/модели/поколения).
  Future<Result<Car>> updateCarReference(
    String id, {
    required int brandId,
    required int modelId,
    required int generationId,
    required String brandName,
    required String modelName,
    required String generationName,
  });

  /// Обновить пробег
  Future<Result<Car>> updateMileage(String carId, int newMileage);

  /// Обновить фото автомобиля (null = удалить фото).
  Future<Result<Car>> updateCarPhoto(String carId, String? photoUrl);

  /// Удалить авто
  Future<Result<void>> deleteCar(String id);

  /// Получить напоминания для авто
  Future<Result<List<CarReminder>>> getReminders(String carId);

  /// Скрыть напоминание
  Future<Result<void>> dismissReminder(String carId, String reminderId);
}
