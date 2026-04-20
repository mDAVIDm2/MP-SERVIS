/// Лимиты тарифа (snake_case с бэкенда `subscription_usage.limits`).
class SubscriptionLimitsInfo {
  final int? maxActiveStaff;
  final int? maxConfirmedOrdersPerMonth;
  final int? maxOrderMediaAttachments;
  final int? maxChatImagesPerMessage;

  const SubscriptionLimitsInfo({
    this.maxActiveStaff,
    this.maxConfirmedOrdersPerMonth,
    this.maxOrderMediaAttachments,
    this.maxChatImagesPerMessage,
  });

  static SubscriptionLimitsInfo fromJson(dynamic raw) {
    if (raw is! Map) return const SubscriptionLimitsInfo();
    final m = Map<String, dynamic>.from(raw);
    int? n(String k) {
      final v = m[k];
      if (v is num) return v.toInt();
      return null;
    }

    return SubscriptionLimitsInfo(
      maxActiveStaff: n('max_active_staff'),
      maxConfirmedOrdersPerMonth: n('max_confirmed_orders_per_month'),
      maxOrderMediaAttachments: n('max_order_media_attachments'),
      maxChatImagesPerMessage: n('max_chat_images_per_message'),
    );
  }

  String describeChatPhotoLimit() => _limitLabel(maxChatImagesPerMessage);
  String describeOrderMediaLimit() => _limitLabel(maxOrderMediaAttachments);
  String describeStaffLimit() => _limitLabel(maxActiveStaff);
  String describeOrdersMonthLimit() => _limitLabel(maxConfirmedOrdersPerMonth);

  static String _limitLabel(int? max) {
    if (max == null) return 'без лимита';
    return 'до $max';
  }
}

/// Сводка по подписке из `GET/PATCH /organizations/:id` → `subscription_usage`.
class OrganizationSubscriptionUsage {
  final String planKey;
  final SubscriptionLimitsInfo limits;
  final SubscriptionLimitsInfo planLimits;
  final bool subscriptionActive;
  final String? subscriptionStatus;
  final String? subscriptionEndDate;
  final int confirmedOrdersThisMonth;
  final int activeStaff;

  const OrganizationSubscriptionUsage({
    required this.planKey,
    required this.limits,
    required this.planLimits,
    required this.subscriptionActive,
    this.subscriptionStatus,
    this.subscriptionEndDate,
    required this.confirmedOrdersThisMonth,
    required this.activeStaff,
  });

  static OrganizationSubscriptionUsage? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    return OrganizationSubscriptionUsage(
      planKey: j['plan_key']?.toString().trim().isNotEmpty == true
          ? j['plan_key'].toString()
          : 'team',
      limits: SubscriptionLimitsInfo.fromJson(j['limits']),
      planLimits: SubscriptionLimitsInfo.fromJson(j['plan_limits']),
      subscriptionActive: j['subscription_active'] == true,
      subscriptionStatus: j['subscription_status']?.toString(),
      subscriptionEndDate: j['subscription_end_date']?.toString(),
      confirmedOrdersThisMonth: (j['confirmed_orders_this_month'] as num?)?.toInt() ?? 0,
      activeStaff: (j['active_staff'] as num?)?.toInt() ?? 0,
    );
  }

  static String planTitleRu(String key) {
    switch (key.toLowerCase()) {
      case 'solo':
        return 'Соло';
      case 'team':
        return 'Команда';
      case 'business':
        return 'Бизнес';
      case 'pro':
        return 'Про';
      case 'network':
        return 'Сеть';
      default:
        return key;
    }
  }
}
