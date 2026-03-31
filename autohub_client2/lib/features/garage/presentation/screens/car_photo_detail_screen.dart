import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/car_model.dart';

class CarPhotoDetailScreen extends ConsumerWidget {
  const CarPhotoDetailScreen({super.key, required this.carId});

  final String carId;

  bool _isLocalFile(String value) {
    if (value.isEmpty) return false;
    return !(value.startsWith('http://') || value.startsWith('https://'));
  }

  Future<void> _pickNewPhoto(BuildContext context, WidgetRef ref, Car car) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final ok = await ref.read(carsProvider.notifier).updateCarPhoto(car.id, picked.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Фото автомобиля обновлено' : 'Не удалось обновить фото'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _deletePhoto(BuildContext context, WidgetRef ref, Car car) async {
    if ((car.photoUrl ?? '').isEmpty) return;
    final ok = await ref.read(carsProvider.notifier).updateCarPhoto(car.id, null);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Фото удалено' : 'Не удалось удалить фото'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).valueOrNull ?? const <Car>[];
    Car? car;
    for (final c in cars) {
      if (c.id == carId) {
        car = c;
        break;
      }
    }
    if (car == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Автомобиль не найден', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final currentCar = car;

    final photo = currentCar.photoUrl?.trim() ?? '';
    if (photo.isNotEmpty) {
      return _CarPhotoFullscreen(
        car: currentCar,
        photoUrl: photo,
        isLocalFile: _isLocalFile(photo),
        onPickNew: () => _pickNewPhoto(context, ref, currentCar),
        onDelete: () => _deletePhoto(context, ref, currentCar),
      );
    }

    final docs = ref.watch(carDocumentsProvider).where((d) => d.carId == currentCar.id).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Карточка автомобиля', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.nestedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(Icons.directions_car_rounded, size: 52, color: AppColors.textTertiary.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deletePhoto(context, ref, currentCar),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Удалить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _pickNewPhoto(context, ref, currentCar),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Изменить картинку'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoBlock(
            title: 'Основная информация',
            rows: [
              _InfoRow('Марка и модель', currentCar.displayName),
              _InfoRow('Год', '${currentCar.year}'),
              _InfoRow('Пробег', '${currentCar.mileage} км'),
              _InfoRow('VIN', (currentCar.vin == null || currentCar.vin!.isEmpty) ? '—' : currentCar.vin!),
              _InfoRow('Госномер', (currentCar.plateNumber == null || currentCar.plateNumber!.isEmpty) ? '—' : currentCar.plateNumber!),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: 'Документы',
            rows: docs.isEmpty
                ? const [_InfoRow('Данные', 'Документы не добавлены')]
                : docs.map((d) => _InfoRow(d.type, d.detail)).toList(),
          ),
        ],
      ),
    );
  }
}

class _CarPhotoFullscreen extends StatelessWidget {
  const _CarPhotoFullscreen({
    required this.car,
    required this.photoUrl,
    required this.isLocalFile,
    required this.onPickNew,
    required this.onDelete,
  });

  final Car car;
  final String photoUrl;
  final bool isLocalFile;
  final VoidCallback onPickNew;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = isLocalFile ? Image.file(File(photoUrl), fit: BoxFit.contain) : Image.network(photoUrl, fit: BoxFit.contain);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(car.displayName, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(child: image),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Удалить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onPickNew,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Установить новую картинку'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}
