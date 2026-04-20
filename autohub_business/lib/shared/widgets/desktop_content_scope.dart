import 'package:flutter/material.dart';

/// Оборачивает вложенный [Navigator] контента десктопа: [IndexedStack] в первом маршруте
/// читает актуальный индекс вкладки и список экранов без пересоздания навигатора.
class DesktopContentScope extends InheritedWidget {
  const DesktopContentScope({
    super.key,
    required this.tabIndex,
    required this.screens,
    required super.child,
  });

  final int tabIndex;
  final List<Widget> screens;

  static DesktopContentScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<DesktopContentScope>();
    assert(s != null, 'DesktopContentScope not found');
    return s!;
  }

  @override
  bool updateShouldNotify(covariant DesktopContentScope oldWidget) {
    return tabIndex != oldWidget.tabIndex || !identical(screens, oldWidget.screens);
  }
}
