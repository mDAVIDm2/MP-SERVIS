import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/widgets/garage_car_photo_image.dart';

class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    this.onCardTap,
    this.onMileageTap,
    this.onImageTap,
    this.onFixReferenceTap,
    this.unreadNotificationsCount = 0,
  });

  final Car car;
  final VoidCallback? onCardTap;
  final VoidCallback? onMileageTap;
  final VoidCallback? onImageTap;
  /// Открыть экран уточнения марки/модели/поколения (после отклонения заявки и т.п.).
  final VoidCallback? onFixReferenceTap;
  final int unreadNotificationsCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusOrderCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 180),
          child: Ink(
            decoration: AppDesignSystem.carCardDecoration(p),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Stack(
              children: [
                Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (car.nickname != null)
                    Text(car.nickname!, style: TextStyle(
                      fontSize: 12, color: p.gold1, fontWeight: FontWeight.w500,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text(
                    car.displayName,
                    style: AppTextStyles.carModelTitle(p),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (car.mergedFromOrders) ...[
                    SizedBox(height: 6),
                    _infoChip(
                      p,
                      'Карточка из записей в сервис (после переустановки локальный гараж пуст). Добавьте автомобиль снова в гараж.',
                    ),
                  ],
                  if (car.hasManualReferencePending) ...[
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (car.hasPendingBrand)
                          _pendingChip(p, 'Ожидается подтверждения марки разработчиками'),
                        if (car.hasPendingModel)
                          _pendingChip(p, 'Ожидается подтверждения модели разработчиками'),
                        if (car.hasPendingGeneration)
                          _pendingChip(p, 'Ожидается подтверждения поколения разработчиками'),
                      ],
                    ),
                    if (onFixReferenceTap != null) ...[
                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onFixReferenceTap,
                          style: TextButton.styleFrom(
                            foregroundColor: p.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Указать марку и модель…'),
                        ),
                      ),
                    ],
                  ],
                  SizedBox(height: 12),
                  GestureDetector(
                    onTap: onMileageTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Formatters.mileage(car.mileage), style: AppTextStyles.bodySecondary(p)),
                        SizedBox(width: 6),
                        Icon(Icons.edit, size: 14, color: p.textSecondary),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('${car.year} • ${car.engineType ?? ''}', style: AppTextStyles.caption(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
              SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onImageTap,
                    child: Container(
                      width: 108,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                        border: Border.all(color: p.strokeSoft),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                              child: GarageCarPhotoImage(photoUrl: car.photoUrl),
                            ),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, p.nestedBg.withValues(alpha: 0.9)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (car.plateNumber != null) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(car.plateNumber!, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.black, letterSpacing: 0.5,
                      )),
                    ),
                  ],
                ],
              ),
            ],
          ),
              if (unreadNotificationsCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      unreadNotificationsCount > 99 ? '99+' : '$unreadNotificationsCount',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.onAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

Widget _infoChip(ClientPalette p, String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: p.info.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: p.info.withValues(alpha: 0.35)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: p.textSecondary, height: 1.25),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _pendingChip(ClientPalette p, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: p.warning.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: p.warning.withValues(alpha: 0.5)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: p.warning, fontWeight: FontWeight.w500),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

