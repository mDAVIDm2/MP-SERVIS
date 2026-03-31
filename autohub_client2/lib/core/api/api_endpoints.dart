import '../config/app_config.dart';

/// Все API endpoints экосистемы AutoHub.
/// Соответствует спецификации из промта (Часть 4: Backend API).
/// Базовый URL задаётся в AppConfig (переменная окружения AUTOHUB_API_HOST или defaultValue).
class ApiEndpoints {
  ApiEndpoints._();

  static String get baseUrl => AppConfig.baseUrl;
  static String get wsUrl => AppConfig.wsUrl;

  // ═══════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════
  static const String sendSms = '/auth/send-code';
  static const String verifySms = '/auth/verify-code';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String authSessions = '/auth/sessions';
  static String authSession(String id) => '/auth/sessions/$id';
  static const String authRevokeOthers = '/auth/sessions/revoke-others';
  static const String authSecurityEvents = '/auth/security-events';

  // ═══════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════
  static const String profile = '/profile';
  static const String profileNotificationPreferences = '/profile/notification-preferences';
  static const String profileAvatar = '/profile/avatar';
  static const String profileDelete = '/profile/delete';

  // ═══════════════════════════════════════
  // CARS
  // ═══════════════════════════════════════
  static const String cars = '/cars';
  static String car(String id) => '/cars/$id';
  static String carMileage(String id) => '/cars/$id/mileage';
  static String carReminders(String id) => '/cars/$id/reminders';
  static String carDocuments(String id) => '/cars/$id/documents';

  // ═══════════════════════════════════════
  // ORDERS
  // ═══════════════════════════════════════
  static const String orders = '/orders';
  static String order(String id) => '/orders/$id';
  /// Чат по заказу (GET /orders/:orderId/chat → { chat_id }). Для открытия чата по orderId.
  static String orderChat(String orderId) => '/orders/$orderId/chat';
  static String orderConfirm(String id) => '/orders/$id/confirm';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderItems(String id) => '/orders/$id/items';
  static String orderApproval(String id) => '/orders/$id/approval';
  static String orderPhotos(String id) => '/orders/$id/photos';
  static String orderReview(String id) => '/orders/$id/review';

  // ═══════════════════════════════════════
  // CATALOG (организации, услуги, поиск)
  // ═══════════════════════════════════════
  static const String catalogSearch = '/catalog/search';
  static const String catalogServices = '/catalog/services';
  static const String catalogFavorites = '/catalog/favorites';
  static String catalogOrganization(String id) => '/catalog/organizations/$id';
  static String catalogOrgServices(String id) => '/catalog/organizations/$id/services';
  static String catalogOrgReviews(String id) => '/catalog/organizations/$id/reviews';
  static String catalogOrgAvailability(String id) => '/catalog/organizations/$id/availability';

  // ═══════════════════════════════════════
  // BOOKING
  // ═══════════════════════════════════════
  static const String bookingAvailableSlots = '/booking/available-slots';
  static const String bookings = '/bookings';
  static String booking(String id) => '/bookings/$id';

  // ═══════════════════════════════════════
  // CHATS
  // ═══════════════════════════════════════
  static const String chats = '/chats';
  static const String chatsSupportOpen = '/chats/support/open';
  static String chat(String id) => '/chats/$id';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';
  static String chatMessagesWithMedia(String chatId) => '/chats/$chatId/messages/with-media';
  static String chatRead(String chatId) => '/chats/$chatId/read';
  static String chatMessageRead(String chatId, String msgId) =>
      '/chats/$chatId/messages/$msgId/read';

  // ═══════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String registerPushToken = '/notifications/register-device';

  // ═══════════════════════════════════════
  // СПРАВОЧНИКИ
  // ═══════════════════════════════════════
  static const String carBrands = '/reference/car-brands';
  static String carModels(int brandId) => '/reference/car-brands/$brandId/models';
  static String carGenerations(int modelId) => '/reference/car-models/$modelId/generations';
  static const String serviceCategories = '/reference/service-categories';
  static const String cities = '/reference/cities';
}
