import 'package:flutter/material.dart';
import 'app_l10n.dart';

/// Предоставляет [AppL10n] по дереву виджетов. Оборачивать корневой экран (например [MainShell]).
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.l10n, required super.child});
  final AppL10n l10n;

  static AppL10n of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<L10nScope>();
    assert(scope != null, 'L10nScope not found. Wrap your app with L10nScope(l10n: ...).');
    return scope!.l10n;
  }

  static AppL10n? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<L10nScope>()?.l10n;
  }

  @override
  bool updateShouldNotify(L10nScope oldWidget) => l10n.locale != oldWidget.l10n.locale;
}
