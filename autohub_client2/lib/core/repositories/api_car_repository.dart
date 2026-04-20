import 'dart:io';

import 'package:dio/dio.dart';

import '../../shared/models/car_model.dart';
import '../../shared/models/order_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../garage/garage_from_orders.dart';
import 'car_repository.dart';

/// Гараж клиента: REST `/profile/cars` на бэкенде.
class ApiCarRepository implements CarRepository {
  ApiCarRepository(this._client);
  final ApiClient _client;

  @override
  Future<Result<List<Car>>> getCars() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.profileCars);
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      final raw = (data['items'] as List<dynamic>?) ?? [];
      final cars = raw
          .map((e) => Car.fromProfileApiJson(e as Map<String, dynamic>))
          .where((c) => c.id.isNotEmpty)
          .toList();
      return Result.success(cars);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  @override
  Future<Result<Car>> getCarById(String id) async {
    final all = await getCars();
    return all.when(
      success: (cars) {
        try {
          return Result.success(cars.firstWhere((c) => c.id == id));
        } catch (_) {
          return Result.failure(
            const ApiException(code: ApiErrorCode.notFound, message: 'Автомобиль не найден'),
          );
        }
      },
      failure: (e) => Result.failure(e),
    );
  }

  Map<String, dynamic> _createBody({
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
  }) {
    return {
      if (preferredId != null && preferredId.trim().isNotEmpty) 'id': preferredId.trim(),
      'brand': brandName,
      'model': modelName,
      if (generation != null) 'generation': generation,
      if (brandId != null) 'brand_id': brandId,
      if (modelId != null) 'model_id': modelId,
      if (generationId != null) 'generation_id': generationId,
      'year': year,
      if (nickname != null) 'nickname': nickname,
      if (licensePlate != null) 'plate_number': licensePlate,
      if (mileage != null) 'mileage': mileage,
      if (vin != null) 'vin': vin,
      if (engineType != null) 'engine_type': engineType,
      if (transmission != null) 'transmission': transmission,
      if (drivetrain != null) 'drivetrain': drivetrain,
      if (bodyType != null) 'body_type': bodyType,
      if (color != null) 'color': color,
      if (mergedFromOrders) 'merged_from_orders': true,
    };
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
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.profileCars,
        data: _createBody(
          brandName: brandName,
          modelName: modelName,
          generation: generation,
          brandId: brandId,
          modelId: modelId,
          generationId: generationId,
          year: year,
          licensePlate: licensePlate,
          mileage: mileage,
          vin: vin,
          nickname: nickname,
          engineType: engineType,
          transmission: transmission,
          drivetrain: drivetrain,
          bodyType: bodyType,
          color: color,
          preferredId: preferredId,
          mergedFromOrders: mergedFromOrders,
        ),
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(Car.fromProfileApiJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  @override
  Future<Result<Car>> updateCar(
    String id, {
    String? nickname,
    String? licensePlate,
    int? mileage,
    String? vin,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nickname != null) body['nickname'] = nickname;
      if (licensePlate != null) body['plate_number'] = licensePlate;
      if (mileage != null) body['mileage'] = mileage;
      if (vin != null) body['vin'] = vin;
      final res = await _client.patch<Map<String, dynamic>>(ApiEndpoints.profileCar(id), data: body);
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(Car.fromProfileApiJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
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
    try {
      final res = await _client.patch<Map<String, dynamic>>(
        ApiEndpoints.profileCar(id),
        data: {
          'brand_id': brandId,
          'model_id': modelId,
          'generation_id': generationId,
          'brand': brandName,
          'model': modelName,
          'generation': generationName,
        },
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(Car.fromProfileApiJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
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
    try {
      // Не передаём null для generation / generation_id — иначе бэкенд обнулит поля,
      // хотя клиент имел в виду «не менять» (выбраны только марка и модель из списка).
      final body = <String, dynamic>{
        'brand': brand,
        'model': model,
        'brand_id': brandId,
        'model_id': modelId,
      };
      if (generation != null) body['generation'] = generation;
      if (generationId != null) body['generation_id'] = generationId;
      if (nickname != null) body['nickname'] = nickname;
      final res = await _client.patch<Map<String, dynamic>>(
        ApiEndpoints.profileCar(id),
        data: body,
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(Car.fromProfileApiJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  @override
  Future<Result<Car>> updateMileage(String carId, int newMileage) async {
    return updateCar(carId, mileage: newMileage);
  }

  @override
  Future<Result<Car>> updateCarPhoto(String carId, String? photoUrl) async {
    try {
      if (photoUrl == null || photoUrl.trim().isEmpty) {
        final res = await _client.patch<Map<String, dynamic>>(
          ApiEndpoints.profileCar(carId),
          data: {'photo_url': null},
        );
        final data = res.data;
        if (data == null) {
          return Result.failure(
            const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
          );
        }
        return Result.success(Car.fromProfileApiJson(data));
      }
      final p = photoUrl.trim();
      if (p.startsWith('http://') || p.startsWith('https://')) {
        final res = await _client.patch<Map<String, dynamic>>(
          ApiEndpoints.profileCar(carId),
          data: {'photo_url': p},
        );
        final data = res.data;
        if (data == null) {
          return Result.failure(
            const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
          );
        }
        return Result.success(Car.fromProfileApiJson(data));
      }
      final file = File(p);
      if (!await file.exists()) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.validation, message: 'Файл фото не найден'),
        );
      }
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(p),
      });
      final up = await _client.upload<Map<String, dynamic>>(
        ApiEndpoints.profileCarPhoto(carId),
        formData: form,
      );
      final data = up.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(Car.fromProfileApiJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  @override
  Future<Result<void>> deleteCar(String id) async {
    try {
      await _client.delete(ApiEndpoints.profileCar(id));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  @override
  Future<Result<List<CarReminder>>> getReminders(String carId) async {
    final r = await getCarById(carId);
    return r.when(
      success: (c) => Result.success(c.reminders),
      failure: (e) => Result.failure(e),
    );
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
    final listRes = await getCars();
    final existing = listRes.dataOrNull ?? [];
    final ids = existing.map((c) => c.id).toSet();
    var n = 0;
    for (final o in orders) {
      final cid = o.carId.trim();
      if (cid.isEmpty || cid == 'unknown' || ids.contains(cid) || skipCarIds.contains(cid)) {
        continue;
      }
      final snap = carFromOrderSnapshot(o);
      if (snap == null) continue;
      final r = await addCar(
        brandName: snap.brand,
        modelName: snap.model,
        generation: snap.generation,
        year: snap.year,
        licensePlate: snap.plateNumber,
        mileage: snap.mileage,
        vin: snap.vin,
        preferredId: snap.id,
        mergedFromOrders: true,
      );
      if (r.dataOrNull != null) {
        ids.add(snap.id);
        n++;
        final pu = snap.photoUrl?.trim();
        if (pu != null && pu.isNotEmpty) {
          await updateCarPhoto(snap.id, pu);
        }
      }
    }
    return Result.success(n);
  }
}
