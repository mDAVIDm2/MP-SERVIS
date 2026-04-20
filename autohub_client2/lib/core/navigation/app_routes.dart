import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Открывает экран с переходом в стиле iOS; возврат свайпом вправо поддерживается.
Future<T?> pushCupertino<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}

/// Карточка организации (СТО): плавный переход ~1 с, как просили в UX.
/// При отключённых анимациях в системе — без перехода (иначе экран «прыгает», пока на фоне двигается карта).
Future<T?> pushStoDetailScreen<T>(BuildContext context, Widget page) {
  final instant =
      MediaQuery.of(context).disableAnimations || !TickerMode.of(context);
  if (instant) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder<T>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
      ),
    );
  }
  return Navigator.push<T>(
    context,
    PageRouteBuilder<T>(
      transitionDuration: const Duration(seconds: 1),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
