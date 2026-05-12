import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../providers/cars_providers.dart';

/// Подсказка СТО: автомобиль мог быть передан другому владельцу в клиентском приложении.
class CarTransferInsightBanner extends ConsumerWidget {
  const CarTransferInsightBanner({
    super.key,
    required this.carId,
    this.dense = false,
  });

  final String carId;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = carId.trim();
    if (id.isEmpty || id == 'unknown') return const SizedBox.shrink();

    final async = ref.watch(carTransferInsightProvider(id));
    return async.when(
      data: (insight) {
        if (insight == null || !insight.showNotice || insight.message.isEmpty) {
          return const SizedBox.shrink();
        }
        final desktop = isDesktopPlatform;
        final bg = desktop
            ? AppColorsDesktop.warning.withValues(alpha: 0.12)
            : AppColors.warning.withValues(alpha: 0.14);
        final border = desktop
            ? AppColorsDesktop.warning.withValues(alpha: 0.45)
            : AppColors.warning.withValues(alpha: 0.4);
        final iconColor = desktop ? AppColorsDesktop.warning : AppColors.warning;
        final titleColor = desktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
        final bodyColor = desktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;

        return Padding(
          padding: EdgeInsets.only(bottom: dense ? 8 : 12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 8 : 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(dense ? 8 : 10),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.swap_horiz_rounded, size: dense ? 18 : 20, color: iconColor),
                SizedBox(width: dense ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Передача владельца (клиентское приложение)',
                        style: TextStyle(
                          fontSize: dense ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      SizedBox(height: dense ? 4 : 6),
                      Text(
                        insight.message,
                        style: TextStyle(
                          fontSize: dense ? 12 : 13,
                          height: 1.35,
                          color: bodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
