import '../../shared/models/car_model.dart';
import '../../shared/models/order_model.dart';

/// Собрать [Car] из снимка заказа (car_id, car_info, фото и поля с сервера).
Car? carFromOrderSnapshot(Order o) {
  final id = o.carId.trim();
  if (id.isEmpty || id == 'unknown') return null;

  final info = (o.carInfo ?? '').trim();
  var year = 0;
  var brand = '';
  var model = '';
  String? generation;

  if (info.isNotEmpty) {
    final yearMatch = RegExp(r',\s*(\d{4})\s*$').firstMatch(info);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1)!) ?? 0;
      var front = info.substring(0, yearMatch.start).trim();
      final genMatch = RegExp(r'\(([^)]+)\)\s*$').firstMatch(front);
      if (genMatch != null) {
        generation = genMatch.group(1)?.trim();
        front = front.substring(0, genMatch.start).trim();
      }
      final parts = front.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        brand = parts.first;
        model = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    } else {
      final parts = info.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        brand = parts.first;
        model = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }
  }

  if (brand.isEmpty) {
    brand = 'Автомобиль';
  }
  if (model.isEmpty) {
    model = '—';
  }

  return Car(
    id: id,
    brand: brand,
    model: model,
    generation: generation,
    year: year,
    plateNumber: o.licensePlate,
    vin: o.vin,
    mileage: o.mileage ?? 0,
    photoUrl: o.carPhotoUrl,
    mergedFromOrders: true,
  );
}
