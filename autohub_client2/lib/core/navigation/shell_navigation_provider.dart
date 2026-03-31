import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Переключить вкладку главного shell (0 гараж … 2 поиск).
final shellTargetTabProvider = StateProvider<int?>((ref) => null);

/// Применить фильтр услуг на экране поиска (после того как shell обработал открытие поиска).
final searchServiceFilterBootstrapProvider = StateProvider<List<String>?>((ref) => null);

/// Открыть вкладку «Поиск» и задать фильтр по ID услуг (обрабатывает [MainShell]).
final openSearchWithServicesProvider = StateProvider<List<String>?>((ref) => null);
