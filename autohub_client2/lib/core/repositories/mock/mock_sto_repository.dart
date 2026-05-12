import '../../../shared/models/sto_model.dart';
import '../../api/api_exceptions.dart';
import '../sto_repository.dart';

/// Заглушка STORepository: каталог подтягивается с сервера (API). Пока возвращаем пустые результаты.
class MockSTORepository implements STORepository {
  @override
  Future<Result<List<STO>>> searchSTOs({
    String? query,
    String? businessKind,
    String? category,
    double? lat,
    double? lng,
    double? radius,
    String? sortBy,
  }) async {
    return Result.success([]);
  }

  @override
  Future<Result<STO>> getSTOById(String id) async {
    return Result.failure(const ApiException(
      code: ApiErrorCode.notFound,
      message: 'Автосервис не найден',
    ));
  }

  @override
  Future<Result<List<STO>>> getFavorites() async {
    return Result.success([]);
  }

  @override
  Future<Result<void>> toggleFavorite(String stoId) async {
    return Result.success(null);
  }

  @override
  Future<Result<List<STOService>>> getServices(String stoId) async {
    return Result.success([]);
  }

  @override
  Future<Result<List<STOService>>> getAllServices() async {
    return Result.success([]);
  }

  @override
  Future<Result<AvailableSlotsResult>> getAvailableSlots(
    String stoId,
    DateTime date,
    List<String> serviceIds, {
    List<SlotAvailabilityItem>? items,
  }) async {
    return Result.success(const AvailableSlotsResult(
      startTimes: [],
      slotChoices: [],
      schedulingMode: 'staff_based',
      slotDurationMinutes: 30,
      workStartMinutes: 9 * 60,
      workEndMinutes: 18 * 60,
    ));
  }

  @override
  Future<Result<List<STOReview>>> getReviews(String stoId) async {
    return Result.success([]);
  }
}
