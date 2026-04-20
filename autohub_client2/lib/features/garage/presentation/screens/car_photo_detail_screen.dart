import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/widgets/garage_car_photo_image.dart';

/// Полноэкранный просмотр фото автомобиля: удалить / установить новую картинку (без переноса слов).
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
        backgroundColor: ok ? context.palette.success : context.palette.error,
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
        backgroundColor: ok ? context.palette.success : context.palette.error,
      ),
    );
    if (ok && context.mounted) Navigator.of(context).pop();
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
      return Scaffold(
        backgroundColor: context.palette.background,
        body: Center(
          child: Text('Автомобиль не найден', style: TextStyle(color: context.palette.textSecondary)),
        ),
      );
    }
    final currentCar = car;
    final photo = currentCar.photoUrl?.trim() ?? '';

    if (photo.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(currentCar.displayName, style: TextStyle(color: Colors.white)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_outlined, size: 64, color: Colors.white.withValues(alpha: 0.5)),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _pickNewPhoto(context, ref, currentCar),
                    icon: Icon(Icons.photo_library_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Установить новую картинку',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _CarPhotoFullscreen(
      car: currentCar,
      photoUrl: photo,
      isLocalFile: _isLocalFile(photo),
      onPickNew: () => _pickNewPhoto(context, ref, currentCar),
      onDelete: () => _deletePhoto(context, ref, currentCar),
    );
  }
}

class _CarPhotoFullscreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef _) {
    final image = isLocalFile
        ? Image.file(File(photoUrl), fit: BoxFit.contain)
        : GarageCarPhotoImage(photoUrl: photoUrl, fit: BoxFit.contain);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(car.displayName, style: TextStyle(color: Colors.white)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.white),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.palette.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Удалить',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onPickNew,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Установить новую картинку',
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
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




