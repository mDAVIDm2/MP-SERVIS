import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Открывает экран с переходом в стиле iOS; возврат свайпом вправо поддерживается.
Future<T?> pushCupertino<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}
