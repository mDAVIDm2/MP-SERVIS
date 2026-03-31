/// Русские подписи для ролей, статусов и т.д.

class LabelsRu {
  LabelsRu._();

  static String orderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_confirmation':
        return 'Ожидает подтверждения';
      case 'confirmed':
        return 'Подтверждён';
      case 'in_progress':
        return 'В работе';
      case 'pending_approval':
        return 'На согласовании';
      case 'completed':
      case 'done':
        return 'Выполнен';
      case 'cancelled':
        return 'Отменён';
      default:
        return status ?? '—';
    }
  }

  static String subscriptionStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Активна';
      case 'deactivated':
        return 'Деактивирована';
      case 'expired':
        return 'Истекла';
      default:
        return status ?? '—';
    }
  }

  static String userRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'master':
        return 'Мастер';
      case 'solo':
        return 'Клиент';
      default:
        return role ?? '—';
    }
  }

  static String staffRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'master':
        return 'Мастер';
      default:
        return role ?? '—';
    }
  }

  static String accountType(String? type) {
    switch (type?.toLowerCase()) {
      case 'business':
        return 'Бизнес';
      case 'client':
        return 'Клиент';
      default:
        return type ?? '—';
    }
  }
}
