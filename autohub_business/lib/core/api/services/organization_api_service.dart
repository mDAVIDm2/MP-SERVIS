import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';
import '../../../shared/models/organization_model.dart';
import '../../../shared/models/car_transfer_insight.dart';

/// API организации (профиль точки в Business).
class OrganizationApiService {
  OrganizationApiService(this._client);

  final ApiClient _client;

  Future<Result<OrganizationInfo>> get(String orgId) async {
    try {
      final res = await _client.get(ApiEndpoints.organization(orgId));
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(OrganizationInfo.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Загрузить фото точки (отображается в карточке у клиентов).
  Future<Result<String>> addPhoto(String orgId, File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final name = imageFile.path.split(RegExp(r'[/\\]')).last;
    return addPhotoBytes(orgId, bytes, name);
  }

  /// Надёжнее на Android (Oplus и др.): байты из галереи без зависимости от пути к файлу.
  Future<Result<String>> addPhotoBytes(String orgId, Uint8List bytes, String filename) async {
    try {
      final safeName = filename.trim().isEmpty ? 'photo.jpg' : filename.trim();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: safeName),
      });
      final res = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.organizationPhotos(orgId),
        data: formData,
      );
      final url = res.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет URL в ответе'));
      }
      return Result.success(url);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Удалить фото точки ([photoUrl] — значение из `photo_urls`, как в ответе GET организации).
  Future<Result<bool>> deletePhoto(String orgId, String photoUrl) async {
    try {
      await _client.delete<void>(
        ApiEndpoints.organizationPhotos(orgId),
        data: {'url': photoUrl},
      );
      return Result.success(true);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<OrganizationInfo>> update(String orgId, OrganizationInfo org) async {
    try {
      final body = {
        'name': org.name,
        'address': org.address,
        'phone': org.phone,
        'working_hours': org.workingHours,
        if (org.workingHoursWeek != null)
          'working_hours_week': org.workingHoursWeek!.days.map((d) => d.toJson()).toList(),
        if (org.workingHoursExceptions != null)
          'working_hours_exceptions':
              org.workingHoursExceptions!.map((e) => e.toJson()).toList(),
        'business_kind': org.businessKind,
        'scheduling_mode': org.schedulingMode,
        'latitude': org.latitude,
        'longitude': org.longitude,
      };
      final res = await _client.patch(ApiEndpoints.organization(orgId), data: body);
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(OrganizationInfo.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Подсказка о передаче автомобиля между клиентами (по car_id из заказа).
  Future<Result<CarTransferInsight>> getCarTransferInsight(String orgId, String carId) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.organizationCarTransferInsight(orgId, carId),
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(CarTransferInsight.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
