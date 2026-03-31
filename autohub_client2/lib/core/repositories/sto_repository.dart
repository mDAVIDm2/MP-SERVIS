import '../../shared/models/sto_model.dart';
import '../api/api_exceptions.dart';

/// Абстрактный репозиторий автосервисов
abstract class STORepository {
  /// Поиск точек в каталоге
  Future<Result<List<STO>>> searchSTOs({
    String? query,
    String? businessKind,
    String? category,
    double? lat,
    double? lng,
    double? radius,
    String? sortBy,
  });

  /// Точка по ID
  Future<Result<STO>> getSTOById(String id);

  /// Избранные точки
  Future<Result<List<STO>>> getFavorites();

  /// Добавить / убрать из избранного
  Future<Result<void>> toggleFavorite(String stoId);

  /// Услуги точки
  Future<Result<List<STOService>>> getServices(String stoId);

  /// Все категории услуг
  Future<Result<List<STOService>>> getAllServices();

  /// Доступные слоты (время начала в формате "HH:mm"). + required_skills для предупреждения при пустых слотах.
  Future<Result<AvailableSlotsResult>> getAvailableSlots(String stoId, DateTime date, List<String> serviceIds);

  /// Отзывы
  Future<Result<List<STOReview>>> getReviews(String stoId);
}

/// Один вариант записи из ответа слотов (к мастеру или на пост).
class BookingSlotChoice {
  final String startIsoUtc;
  final String timeLocalHHmm;
  final String? masterId;
  final String masterName;
  final String schedulingMode;

  const BookingSlotChoice({
    required this.startIsoUtc,
    required this.timeLocalHHmm,
    this.masterId,
    required this.masterName,
    this.schedulingMode = 'staff_based',
  });
}

/// Результат запроса доступных слотов (умное расписание).
class AvailableSlotsResult {
  /// Уникальные времена "HH:mm" для сетки (объединение вариантов).
  final List<String> startTimes;
  /// Все варианты (несколько мастеров на одно время — несколько записей).
  final List<BookingSlotChoice> slotChoices;
  /// staff_based | bay_based
  final String schedulingMode;
  /// Число постов (для bay_based), если сервер прислал.
  final int? bayCount;
  /// Требуемые навыки по выбранным услугам (если в выбранный день нет мастера — показываем предупреждение)
  final List<String> requiredSkills;
  final int totalMinutes;
  /// Шаг сетки (как на сервере), минуты.
  final int slotDurationMinutes;
  /// Начало/конец рабочего дня для построения полной сетки (минуты от полуночи).
  final int workStartMinutes;
  final int workEndMinutes;

  const AvailableSlotsResult({
    required this.startTimes,
    this.slotChoices = const [],
    this.schedulingMode = 'staff_based',
    this.bayCount,
    this.requiredSkills = const [],
    this.totalMinutes = 0,
    this.slotDurationMinutes = 30,
    this.workStartMinutes = 9 * 60,
    this.workEndMinutes = 18 * 60,
  });

  /// Варианты для выбранной метки времени на сетке.
  List<BookingSlotChoice> choicesForTimeLabel(String hhmm) =>
      slotChoices.where((c) => c.timeLocalHHmm == hhmm).toList();
}

/// Модель отзыва
class STOReview {
  final String id;
  final String authorName;
  final int rating;
  final String text;
  final DateTime createdAt;

  const STOReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.text,
    required this.createdAt,
  });
}
