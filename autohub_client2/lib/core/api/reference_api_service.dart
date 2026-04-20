import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// DTO марки автомобиля из справочника API.
class CarBrandDto {
  const CarBrandDto({required this.id, required this.name});
  final int id;
  final String name;

  static CarBrandDto fromJson(Map<String, dynamic> json) => CarBrandDto(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );
}

/// DTO модели автомобиля из справочника API.
class CarModelDto {
  const CarModelDto({required this.id, required this.name});
  final int id;
  final String name;

  static CarModelDto fromJson(Map<String, dynamic> json) => CarModelDto(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );
}

/// DTO поколения автомобиля из справочника API.
class CarGenerationDto {
  const CarGenerationDto({
    required this.id,
    required this.name,
    this.yearFrom,
    this.yearTo,
  });
  final int id;
  final String name;
  final int? yearFrom;
  final int? yearTo;

  static CarGenerationDto fromJson(Map<String, dynamic> json) => CarGenerationDto(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        yearFrom: (json['yearFrom'] as num?)?.toInt(),
        yearTo: (json['yearTo'] as num?)?.toInt(),
      );

  String get yearRange {
    if (yearFrom != null && yearTo != null) return '$yearFrom–$yearTo';
    if (yearFrom != null) return 'с $yearFrom';
    return '';
  }
}

/// API справочников (марки, модели и поколения автомобилей).
class ReferenceApiService {
  ReferenceApiService(this._client);
  final ApiClient _client;

  /// Список марок автомобилей.
  Future<Result<List<CarBrandDto>>> getCarBrands() async {
    try {
      final res = await _client.get(ApiEndpoints.carBrands);
      final data = res.data;
      if (data is! List) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final list = data
          .map((e) => CarBrandDto.fromJson(e as Map<String, dynamic>))
          .where((e) => e.name.isNotEmpty)
          .toList();
      return Result.success(list);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Список моделей по id марки.
  Future<Result<List<CarModelDto>>> getCarModels(int brandId) async {
    try {
      final res = await _client.get(ApiEndpoints.carModels(brandId));
      final data = res.data;
      if (data is! List) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final list = data
          .map((e) => CarModelDto.fromJson(e as Map<String, dynamic>))
          .where((e) => e.name.isNotEmpty)
          .toList();
      return Result.success(list);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Список поколений по id модели.
  Future<Result<List<CarGenerationDto>>> getCarGenerations(int modelId) async {
    try {
      final res = await _client.get(ApiEndpoints.carGenerations(modelId));
      final data = res.data;
      if (data is! List) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final list = data
          .map((e) => CarGenerationDto.fromJson(e as Map<String, dynamic>))
          .where((e) => e.name.isNotEmpty)
          .toList();
      return Result.success(list);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Отправить на подтверждение разработчиком введённые вручную марку/модель/поколение.
  /// Все три поля всегда отправляются (значение или null), чтобы бэкенд точно получил модель.
  Future<Result<Map<String, dynamic>>> submitPendingCar({
    required String carId,
    String? pendingBrand,
    String? pendingModel,
    String? pendingGeneration,
    int? referenceBrandId,
    int? referenceModelId,
  }) async {
    final hasAny = (pendingBrand?.trim().isNotEmpty ?? false) ||
        (pendingModel?.trim().isNotEmpty ?? false) ||
        (pendingGeneration?.trim().isNotEmpty ?? false);
    if (!hasAny) return Result.success(<String, dynamic>{});
    try {
      final payload = <String, dynamic>{
        'carId': carId,
        'pendingBrand': pendingBrand?.trim().isNotEmpty == true ? pendingBrand!.trim() : null,
        'pendingModel': pendingModel?.trim().isNotEmpty == true ? pendingModel!.trim() : null,
        'pendingGeneration': pendingGeneration?.trim().isNotEmpty == true ? pendingGeneration!.trim() : null,
      };
      if (referenceBrandId != null) payload['referenceBrandId'] = referenceBrandId;
      if (referenceModelId != null) payload['referenceModelId'] = referenceModelId;
      final res = await _client.post<Map<String, dynamic>>(
        '/reference/pending-car',
        data: payload,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.success(<String, dynamic>{});
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
