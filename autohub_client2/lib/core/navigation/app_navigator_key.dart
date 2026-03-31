import 'package:flutter/material.dart';

/// Корневой навигатор авторизованного приложения (для push / deep link поверх [MainShell]).
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();
