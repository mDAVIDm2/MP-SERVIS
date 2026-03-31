import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sections/section_scaffold.dart';
import 'client_car_detail_view.dart';

/// Полноэкранная карточка авто + история (маршрут из списка на узкой ширине).
class ClientCarHistoryScreen extends ConsumerWidget {
  const ClientCarHistoryScreen({super.key, required this.clientPhone, required this.carId});

  final String clientPhone;
  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionScaffold(
      expandBody: true,
      title: 'Карточка автомобиля',
      child: ClientCarDetailView(
        clientPhone: clientPhone,
        carId: carId,
        showBack: true,
      ),
    );
  }
}
