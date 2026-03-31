import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Режим колонок расписания (если в настройках заданы именованные посты).
enum ScheduleBoardMode {
  /// Колонки по мастерам; в мини-карточке при наличии постов показываем пост.
  byMasters,
  /// Колонки по постам; в мини-карточке обязательно показываем мастера (если назначен).
  byBays,
}

final scheduleBoardModeProvider = StateProvider<ScheduleBoardMode>((ref) => ScheduleBoardMode.byMasters);

/// Фильтр списка заказов на экране «Заказы» по посту (null — все).
final ordersListBayFilterIdProvider = StateProvider<String?>((ref) => null);
