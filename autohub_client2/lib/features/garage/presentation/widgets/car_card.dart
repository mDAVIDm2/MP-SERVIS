import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';

class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    this.onCardTap,
    this.onMileageTap,
    this.onImageTap,
    this.unreadNotificationsCount = 0,
  });

  final Car car;
  final VoidCallback? onCardTap;
  final VoidCallback? onMileageTap;
  final VoidCallback? onImageTap;
  final int unreadNotificationsCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusOrderCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Ink(
            decoration: AppDesignSystem.carCardDecoration,
            padding: const EdgeInsets.all(AppDesignSystem.cardPadding),
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
                    Text(car.nickname!, style: const TextStyle(
                      fontSize: 12, color: AppColors.gold1, fontWeight: FontWeight.w500,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(car.displayName, style: AppTextStyles.carModelTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (car.hasPendingModel || car.hasPendingGeneration || car.hasPendingBrand) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (car.hasPendingBrand)
                          _pendingChip('Ожидается подтверждения марки разработчиками'),
                        if (car.hasPendingModel)
                          _pendingChip('Ожидается подтверждения модели разработчиками'),
                        if (car.hasPendingGeneration)
                          _pendingChip('Ожидается подтверждения поколения разработчиками'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onMileageTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Formatters.mileage(car.mileage), style: AppTextStyles.bodySecondary),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${car.year} • ${car.engineType ?? ''}', style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onImageTap,
                    child: Container(
                      width: 120, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                        border: Border.all(color: AppColors.strokeSoft),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                              child: _CarPhoto(car.photoUrl),
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
                                  colors: [Colors.transparent, AppColors.nestedBg.withValues(alpha: 0.9)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (car.plateNumber != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(car.plateNumber!, style: const TextStyle(
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
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      unreadNotificationsCount > 99 ? '99+' : '$unreadNotificationsCount',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
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

  static Widget _pendingChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
    );
  }
}

class _CarPhoto extends StatelessWidget {
  const _CarPhoto(this.photoUrl);

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final photo = (photoUrl ?? '').trim();
    if (photo.isEmpty) {
      return Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 48,
          color: AppColors.textTertiary.withValues(alpha: 0.3),
        ),
      );
    }
    final isNetwork = photo.startsWith('http://') || photo.startsWith('https://');
    if (isNetwork) {
      return Image.network(photo, fit: BoxFit.cover);
    }
    return Image.file(File(photo), fit: BoxFit.cover);
  }
}
