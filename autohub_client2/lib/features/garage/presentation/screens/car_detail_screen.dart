import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/models/order_model.dart';
import '../widgets/car_mileage_chart_card.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/onboarding/garage_first_car_tutorial_provider.dart';
import '../../../../core/onboarding/garage_tutorial_target.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/widgets/garage_car_photo_image.dart';
import 'car_photo_detail_screen.dart';
import 'add_car_screen.dart';
import '../widgets/transfer_car_sheet.dart';

/// Полная карточка автомобиля (гараж). Фото: тап — просмотр / смена в полноэкранном режиме.
class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  static Car? _findCar(List<Car> cars, String id) {
    for (final c in cars) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _confirmDeleteCar(BuildContext context, WidgetRef ref, Car car) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text('Удалить автомобиль?', style: TextStyle(color: context.palette.textPrimary)),
        content: Text(
          'Карточка «${car.displayName}» исчезнет из гаража и не будет снова подставляться из истории заказов. Записи о заказах в приложении останутся. Локальные напоминания ТО и документы по этому авто будут очищены.',
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: TextStyle(color: context.palette.error)),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(carsProvider.notifier).deleteCar(car.id);
    if (!context.mounted) return;
    if (ok) {
      final list = ref.read(carsProvider).valueOrNull ?? [];
      final wasSelected = ref.read(selectedCarIdProvider) == car.id;
      if (wasSelected) {
        if (list.isEmpty) {
          await ref.read(selectedCarIdProvider.notifier).set(null);
        } else {
          await ref.read(selectedCarIdProvider.notifier).set(list.first.id);
        }
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Автомобиль удалён')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось удалить')));
    }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).valueOrNull ?? const <Car>[];
    final car = _findCar(cars, carId);
    if (car == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: Center(
          child: Text('Автомобиль не найден', style: TextStyle(color: context.palette.textSecondary)),
        ),
      );
    }

    final docs = ref.watch(carDocumentsProvider).where((d) => d.carId == car.id).toList();
    final ordersAsync = ref.watch(ordersProvider);
    final mileagePoints = buildMileagePoints(car, ordersAsync.valueOrNull ?? const <Order>[]);
    final photo = car.photoUrl?.trim() ?? '';
    final readOnly = car.isFormerOwnerReadonly;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        title: Text('Карточка автомобиля', style: TextStyle(color: context.palette.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (readOnly) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.palette.nestedBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Вы передали этот автомобиль',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Карточка доступна только для просмотра. Чтобы убрать её из гаража, нажмите «Забыть автомобиль».',
                    style: TextStyle(fontSize: 13, height: 1.35, color: context.palette.textSecondary),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await ref.read(carsProvider.notifier).forgetFormerCar(car.id);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Автомобиль скрыт из гаража')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Не удалось выполнить действие')),
                        );
                      }
                    },
                    child: const Text('Забыть автомобиль'),
                  ),
                ],
              ),
            ),
          ],
          if (!readOnly && car.hasManualReferencePending) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.palette.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.palette.warning.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Нужно уточнить марку, модель или поколение',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Если разработчики отклонили заявку или данные не совпали со справочником — укажите их заново. '
                    'После сохранения при необходимости уйдёт новая заявка на проверку.',
                    style: TextStyle(fontSize: 13, height: 1.35, color: context.palette.textSecondary),
                  ),
                  SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AddCarScreen(editCarId: car.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_road_rounded, size: 20),
                    label: const Text('Указать марку, модель и поколение'),
                  ),
                ],
              ),
            ),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => CarPhotoDetailScreen(carId: car.id)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.palette.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.palette.border),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.palette.nestedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.palette.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: photo.isEmpty
                          ? Icon(
                              Icons.directions_car_rounded,
                              size: 52,
                              color: context.palette.textTertiary.withValues(alpha: 0.35),
                            )
                          : GarageCarPhotoImage(photoUrl: photo),
                    ),
                    SizedBox(height: 12),
                    Text(
                      readOnly
                          ? 'Фото (только просмотр)'
                          : (photo.isEmpty ? 'Нажмите, чтобы добавить фото' : 'Нажмите, чтобы открыть фото'),
                      style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    if (!readOnly) ...[
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: photo.isEmpty
                                  ? null
                                  : () async {
                                      final ok = await ref.read(carsProvider.notifier).updateCarPhoto(car.id, null);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? 'Фото удалено' : 'Не удалось удалить фото'),
                                          backgroundColor: ok ? context.palette.success : context.palette.error,
                                        ),
                                      );
                                    },
                              icon: Icon(Icons.delete_outline_rounded, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Удалить',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(color: photo.isEmpty ? context.palette.textTertiary : context.palette.error),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.palette.error,
                                side: BorderSide(color: photo.isEmpty ? context.palette.border : context.palette.error),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => _pickNewPhoto(context, ref, car),
                              icon: Icon(Icons.photo_library_outlined, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  'Изменить картинку',
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 14),
          _InfoBlock(
            title: 'Основная информация',
            rows: [
              _InfoRow('Марка и модель', car.displayName),
              _InfoRow('Год', '${car.year}'),
              _InfoRow('Пробег', Formatters.mileage(car.mileage)),
              _InfoRow(
                'VIN',
                (car.vin == null || car.vin!.isEmpty) ? '—' : car.vin!,
                copyText: (car.vin != null && car.vin!.trim().isNotEmpty) ? car.vin!.trim() : null,
              ),
              _InfoRow(
                'Госномер',
                (car.plateNumber == null || car.plateNumber!.isEmpty) ? '—' : car.plateNumber!,
                copyText: (car.plateNumber != null && car.plateNumber!.trim().isNotEmpty)
                    ? car.plateNumber!.trim()
                    : null,
              ),
            ],
            editMarqueFooter: !readOnly
                ? () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AddCarScreen(editCarId: car.id),
                      ),
                    );
                  }
                : null,
          ),
          if (mileagePoints.isNotEmpty) ...[
            SizedBox(height: 14),
            CarMileageChartCard(car: car, points: mileagePoints),
          ],
          SizedBox(height: 12),
          GarageTutorialTarget(
            highlightStep: GarageFirstCarTutorialStep.documentsInfo,
            matchCarId: car.id,
            child: _InfoBlock(
              title: 'Документы',
              rows: docs.isEmpty
                  ? const [_InfoRow('Данные', 'Документы не добавлены')]
                  : docs.map((d) => _InfoRow(d.type, d.detail)).toList(),
            ),
          ),
          SizedBox(height: 16),
          if (!readOnly)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.swap_horiz_rounded, color: context.palette.primary),
              title: Text(
                'Передача другому владельцу',
                style: TextStyle(fontWeight: FontWeight.w600, color: context.palette.textPrimary),
              ),
              subtitle: Text(
                'Запрос по номеру телефона: новый владелец подтвердит получение в приложении.',
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary, height: 1.3),
              ),
              onTap: () => showCarTransferSheet(context, ref, car),
            ),
          if (!readOnly) SizedBox(height: 12),
          if (!readOnly)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeleteCar(context, ref, car),
              icon: Icon(Icons.delete_outline_rounded, color: context.palette.error),
              label: Text(
                'Удалить автомобиль',
                style: TextStyle(color: context.palette.error, fontWeight: FontWeight.w600),
              ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.error,
                  side: BorderSide(color: context.palette.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.rows, this.editMarqueFooter});

  final String title;
  final List<_InfoRow> rows;
  final VoidCallback? editMarqueFooter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
          ),
          SizedBox(height: 12),
          ...rows.map((r) => _InfoFieldRow(data: r)),
          if (editMarqueFooter != null) ...[
            SizedBox(height: 4),
            TextButton(
              onPressed: editMarqueFooter,
              child: Text(
                'Изменить марку, модель или поколение',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.palette.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoFieldRow extends StatelessWidget {
  const _InfoFieldRow({required this.data});

  final _InfoRow data;

  void _copy(BuildContext context) {
    if (data.copyText == null) return;
    Clipboard.setData(ClipboardData(text: data.copyText!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(data.label == 'VIN' ? 'VIN скопирован' : 'Номер скопирован'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.nestedBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  data.label,
                  style: TextStyle(fontSize: 13, height: 1.3, color: context.palette.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  data.value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    letterSpacing: data.label == 'VIN' || data.label == 'Госномер' ? 0.2 : 0,
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (data.copyText != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Скопировать',
                  onPressed: () => _copy(context),
                  icon: Icon(
                    Icons.copy_all_rounded,
                    size: 20,
                    color: context.palette.primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.copyText});
  final String label;
  final String value;
  final String? copyText;
}
