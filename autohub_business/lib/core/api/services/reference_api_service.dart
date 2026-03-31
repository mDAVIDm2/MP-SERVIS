import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../../../shared/models/car_reference_models.dart';

class ReferenceApiService {
  ReferenceApiService(this._client);
  final ApiClient _client;

  static dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      return raw['data'];
    }
    return raw;
  }

  Future<Result<List<CarBrandRef>>> getCarBrands() async {
    try {
      final res = await _client.get('/reference/car-brands');
      final raw = _unwrap(res.data);
      if (raw is! List) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Неверный формат списка марок',
        ));
      }
      final list = raw
          .map((e) => CarBrandRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((b) => b.id > 0 && b.name.isNotEmpty)
          .toList();
      return Result.success(list);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<CarModelRef>>> getCarModels(int brandId) async {
    try {
      final res = await _client.get('/reference/car-brands/$brandId/models');
      final raw = _unwrap(res.data);
      if (raw is! List) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Неверный формат списка моделей',
        ));
      }
      final list = raw
          .map((e) => CarModelRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((m) => m.id > 0 && m.name.isNotEmpty)
          .toList();
      return Result.success(list);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<CarGenerationRef>>> getCarGenerations(int modelId) async {
    try {
      final res = await _client.get('/reference/car-models/$modelId/generations');
      final raw = _unwrap(res.data);
      if (raw is! List) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Неверный формат списка поколений',
        ));
      }
      final list = raw
          .map((e) => CarGenerationRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((g) => g.id > 0 && g.name.isNotEmpty)
          .toList();
      return Result.success(list);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
