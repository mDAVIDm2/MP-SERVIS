import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Общая обёртка для экрана раздела: заголовок и контент без переполнения.
///
/// По умолчанию контент в [SingleChildScrollView] (удобно для таблиц и форм).
/// Если нужен [Expanded] у потомка (список на всю высоту), задайте [expandBody]: тогда
/// область под заголовком получает ограничение по высоте от родителя ([MainShell]).
class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.expandBody = false,
    this.titleActions,
  });

  final String title;
  final Widget child;
  final bool expandBody;
  /// Кнопки справа от заголовка (например, обновить).
  final List<Widget>? titleActions;

  @override
  Widget build(BuildContext context) {
    final heading = titleActions == null || titleActions!.isEmpty
        ? Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              ...titleActions!,
            ],
          );
    const gap = SizedBox(height: 24);

    if (expandBody) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            gap,
            Expanded(child: child),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          gap,
          child,
        ],
      ),
    );
  }
}
