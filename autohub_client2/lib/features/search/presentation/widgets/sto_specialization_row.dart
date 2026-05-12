import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/sto_model.dart';
import 'sto_brands_list_screen.dart';

/// Строка «Специализация»: при выбранном авто в гараже — марка и галочка, если марка в списке СТО; тап — полный список.
class StoSpecializationRow extends ConsumerWidget {
  const StoSpecializationRow({super.key, required this.sto});

  final STO sto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final brands = sto.specializations;
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
    final hasList = brands.isNotEmpty;
    final match =
        carBrand != null && hasList && stoMatchesCarBrand(brands, carBrand);
    final String tailLabel;
    if (!hasList) {
      tailLabel = 'все марки';
    } else if (carBrand != null) {
      tailLabel = carBrand;
    } else {
      final n = brands.length;
      final w = n % 10 == 1 && n % 100 != 11
          ? 'марка'
          : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)
                ? 'марки'
                : 'марок');
      tailLabel = '$n $w';
    }
    final showCarBrandTail = carBrand != null && hasList;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          pushCupertino(
            context,
            StoBrandsListScreen(
              stoName: sto.name,
              brands: brands,
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.directions_car_outlined, size: 18, color: p.textTertiary),
              const SizedBox(width: 10),
              Text(
                'Специализация',
                style: TextStyle(
                  fontSize: 14,
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (showCarBrandTail) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: match ? p.success : p.border,
                      width: 1.4,
                    ),
                    color: match ? p.success.withValues(alpha: 0.12) : p.nestedBg,
                  ),
                  child: match
                      ? Icon(Icons.check_rounded, size: 14, color: p.success)
                      : Icon(Icons.remove_rounded, size: 14, color: p.textTertiary),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: carBrand,
                          style: TextStyle(
                            fontSize: 14,
                            color: match ? p.success : p.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' >',
                          style: TextStyle(
                            fontSize: 14,
                            color: p.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: p.textTertiary,
                ),
              ] else ...[
                Flexible(
                  child: Text(
                    tailLabel,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: p.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: p.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
