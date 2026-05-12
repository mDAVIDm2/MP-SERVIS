import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/sto_model.dart';

/// Одна горизонтальная строка: марка из гаража (если совпала со спец.) — в зелёной рамке, остальные — сжато «·» и +N.
class StoSearchListBrandsLine extends ConsumerWidget {
  const StoSearchListBrandsLine({super.key, required this.sto});

  final STO sto;

  static String _formatCompactTail(List<String> all) {
    if (all.isEmpty) return '';
    if (all.length == 1) return all[0];
    if (all.length == 2) return '${all[0]} · ${all[1]}';
    return '${all[0]} · ${all[1]} +${all.length - 2}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final brands = sto.specializations;
    if (brands.isEmpty) return const SizedBox.shrink();

    final carId = ref.watch(selectedCarIdProvider);
    String? carBrand;
    if (carId != null) {
      final cars = ref.watch(carsProvider).valueOrNull ?? const [];
      for (final c in cars) {
        if (c.id == carId) {
          carBrand = c.brand;
          break;
        }
      }
    }
    final matched = matchingSpecializationLabel(brands, carBrand);
    final rest = brands
        .where(
          (s) =>
              matched == null ||
              s.trim().toLowerCase() != matched.trim().toLowerCase(),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (matched != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.success, width: 1.2),
                ),
                child: Text(
                  matched,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.success,
                  ),
                ),
              ),
            ),
            if (rest.isNotEmpty) const SizedBox(width: 6),
          ],
          if (matched == null)
            Expanded(
              child: Text(
                _formatCompactTail(brands),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: p.textPrimary,
                ),
              ),
            )
          else if (rest.isNotEmpty)
            Expanded(
              child: Text(
                _formatCompactTail(rest),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: p.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
