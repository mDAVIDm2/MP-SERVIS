import '../config/app_config.dart';

/// API endpoints — общий бэкенд с клиентом MP-Servis.
class ApiEndpoints {
  ApiEndpoints._();

  static String get baseUrl => AppConfig.baseUrl;
  static String get wsUrl => AppConfig.wsUrl;

  // Auth
  static const String sendSms = '/auth/send-code';
  static const String verifySms = '/auth/verify-code';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Profile (Business: с ролью и organization_id)
  static const String profile = '/profile';
  static const String profileDelete = '/profile/delete';
  static const String profileAvatar = '/profile/avatar';
  static const String profileSwitchOrganization = '/profile/switch-organization';
  static const String profileCreateOrganization = '/profile/organizations';
  static const String profileInvitations = '/profile/invitations';
  static String profileInvitationAccept(String invitationId) => '/profile/invitations/$invitationId/accept';
  static String profileInvitationDecline(String invitationId) => '/profile/invitations/$invitationId/decline';

  // Orders (scoped по organization_id)
  static const String orders = '/orders';
  static const String ordersClearAll = '/orders/clear-all';
  static String order(String id) => '/orders/$id';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderAssignMaster(String id) => '/orders/$id/assign-master';
  static String orderStatus(String id) => '/orders/$id/status';
  static String orderTime(String id) => '/orders/$id/time';
  static String orderItems(String id) => '/orders/$id/items';
  static String orderInventoryLines(String id) => '/orders/$id/inventory-lines';
  static String orderConfirmByPhone(String id) => '/orders/$id/confirm-by-phone';
  static String orderChat(String orderId) => '/orders/$orderId/chat';
  static String orderPhotos(String id) => '/orders/$id/photos';
  static String orderPhotoFile(String orderId, String photoId) => '/orders/$orderId/photos/$photoId/file';

  // Chats
  static const String chats = '/chats';
  static const String chatsSupportOpen = '/chats/support/open';
  static String chat(String id) => '/chats/$id';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';
  static String chatMessagesWithMedia(String chatId) => '/chats/$chatId/messages/with-media';
  static String chatMarkRead(String chatId) => '/chats/$chatId/read';

  // Organizations (профиль организации, сотрудники, услуги)
  static String organization(String id) => '/organizations/$id';
  static String organizationPhotos(String id) => '/organizations/$id/photos';
  static String organizationStaff(String id) => '/organizations/$id/staff';
  static String organizationInvitations(String id) => '/organizations/$id/invitations';
  static String organizationInvitationCancel(String orgId, String invitationId) =>
      '/organizations/$orgId/invitations/$invitationId/cancel';
  static String organizationStaffAddMeAsMaster(String id) => '/organizations/$id/staff/add-me-as-master';
  static String organizationStaffMember(String orgId, String staffId) => '/organizations/$orgId/staff/$staffId';
  static String organizationServices(String id) => '/organizations/$id/services';
  static String organizationSettings(String id) => '/organizations/$id/settings';
  static String organizationClients(String id) => '/organizations/$id/clients';

  /// Справка по передаче авто между клиентами (для Business).
  static String organizationCarTransferInsight(String orgId, String carId) =>
      '/organizations/$orgId/client-cars/${Uri.encodeComponent(carId)}/transfer-insight';

  // Booking (слоты для записи)
  static const String bookingAvailableSlots = '/booking/available-slots';

  // Notifications
  static const String notifications = '/notifications';
  static const String registerPushToken = '/notifications/register-device';

  // Inventory (Business; X-MP-Servis-App: business)
  static const String inventoryItems = '/inventory/items';
  static String inventoryItem(String id) => '/inventory/items/${Uri.encodeComponent(id)}';
  static String inventoryItemMovements(String id) => '/inventory/items/${Uri.encodeComponent(id)}/movements';
  static String inventoryItemReceipt(String id) => '/inventory/items/${Uri.encodeComponent(id)}/receipt';
  static const String inventoryMovements = '/inventory/movements';
}
