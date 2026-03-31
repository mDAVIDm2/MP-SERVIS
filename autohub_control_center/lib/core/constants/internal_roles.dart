import 'package:flutter/material.dart';

enum InternalRole {
  superadmin,
  support,
  billingManager,
  contentManager,
  analyst;

  String get label {
    switch (this) {
      case InternalRole.superadmin:
        return 'Суперадмин';
      case InternalRole.support:
        return 'Поддержка';
      case InternalRole.billingManager:
        return 'Биллинг';
      case InternalRole.contentManager:
        return 'Контент-менеджер';
      case InternalRole.analyst:
        return 'Аналитик';
    }
  }

  /// Доступ к разделам: суперадмин видит всё, остальные — по необходимости.
  bool canAccessSection(String sectionId) {
    switch (this) {
      case InternalRole.superadmin:
        return true;
      case InternalRole.support:
        return sectionId == 'dashboard' ||
            sectionId == 'organizations' ||
            sectionId == 'orders' ||
            sectionId == 'audit' ||
            sectionId == 'client-cars' ||
            sectionId == 'support-chats';
      case InternalRole.billingManager:
        return sectionId == 'dashboard' || sectionId == 'subscriptions' || sectionId == 'audit';
      case InternalRole.contentManager:
        return sectionId == 'dashboard' ||
            sectionId == 'car-dictionaries' ||
            sectionId == 'service-dictionaries' ||
            sectionId == 'audit';
      case InternalRole.analyst:
        return sectionId == 'dashboard' || sectionId == 'audit' || sectionId == 'client-cars';
    }
  }

  static InternalRole fromString(String? value) {
    if (value == null) return InternalRole.analyst;
    return InternalRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => InternalRole.analyst,
    );
  }
}

/// Элемент бокового меню с путём и метаданными.
class NavSection {
  const NavSection({
    required this.sectionId,
    required this.label,
    required this.path,
    required this.icon,
  });
  final String sectionId;
  final String label;
  final String path;
  final IconData icon;
}

const List<NavSection> kAllNavSections = [
  NavSection(sectionId: 'dashboard', label: 'Панель', path: '/app', icon: Icons.dashboard_rounded),
  NavSection(sectionId: 'organizations', label: 'Организации', path: '/app/organizations', icon: Icons.business_rounded),
  NavSection(sectionId: 'users', label: 'Пользователи', path: '/app/users', icon: Icons.people_rounded),
  NavSection(sectionId: 'subscriptions', label: 'Подписки', path: '/app/subscriptions', icon: Icons.card_membership_rounded),
  NavSection(sectionId: 'car-dictionaries', label: 'Авто-справочники', path: '/app/car-dictionaries', icon: Icons.directions_car_rounded),
  NavSection(sectionId: 'service-dictionaries', label: 'Справочники услуг', path: '/app/service-dictionaries', icon: Icons.build_rounded),
  NavSection(sectionId: 'orders', label: 'Заказы', path: '/app/orders', icon: Icons.receipt_long_rounded),
  NavSection(sectionId: 'client-cars', label: 'Авто клиентов', path: '/app/client-cars', icon: Icons.directions_car_rounded),
  NavSection(sectionId: 'support-chats', label: 'Поддержка', path: '/app/support-chats', icon: Icons.support_agent_rounded),
  NavSection(sectionId: 'audit', label: 'Аудит', path: '/app/audit', icon: Icons.history_rounded),
];
