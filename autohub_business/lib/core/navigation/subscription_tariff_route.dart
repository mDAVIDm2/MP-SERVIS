import 'package:flutter/material.dart';

/// Избегаем цикла импортов (чат → тариф → чат): экран регистрируется в [main].
Widget Function()? _subscriptionTariffFactory;

void registerSubscriptionTariffFactory(Widget Function() factory) {
  _subscriptionTariffFactory = factory;
}

void openSubscriptionTariffScreen(BuildContext context) {
  final f = _subscriptionTariffFactory;
  if (f == null) return;
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => f()),
  );
}
