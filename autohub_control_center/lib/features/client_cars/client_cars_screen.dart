import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_url_resolver.dart';
import '../../shared/widgets/cc_auth_network_image.dart';
import '../sections/section_scaffold.dart';
import 'client_car_detail_view.dart';

/// Авто из заказов клиентов (car_id + телефон в БД). Десктоп: список + панель карточки как в Business.
class ClientCarsScreen extends ConsumerStatefulWidget {
  const ClientCarsScreen({super.key});

  @override
  ConsumerState<ClientCarsScreen> createState() => _ClientCarsScreenState();
}

class _ClientCarsScreenState extends ConsumerState<ClientCarsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _selPhone;
  String? _selCarId;
  Map<String, dynamic>? _selRow;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    if (_query.isEmpty) return items;
    return items.where((e) {
      final blob = [
        e['car_info'],
        e['client_phone'],
        e['client_name'],
        e['car_id'],
      ].whereType<Object>().map((x) => x.toString().toLowerCase()).join(' ');
      return blob.contains(_query);
    }).toList();
  }

  void _select(Map<String, dynamic> e) {
    final phone = '${e['client_phone'] ?? ''}';
    final carId = '${e['car_id'] ?? ''}';
    setState(() {
      _selPhone = phone;
      _selCarId = carId;
      _selRow = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientCarsProvider);
    return SectionScaffold(
      expandBody: true,
      title: 'Авто клиентов',
      child: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Нет автомобилей в гараже клиентов и в заказах',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            );
          }
          final filtered = _filter(items);
          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1024;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _searchBar(),
                    const SizedBox(height: 12),
                    Expanded(child: _carList(filtered, wide: false, context: context)),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _searchBar(),
                        const SizedBox(height: 12),
                        Expanded(child: _carList(filtered, wide: true, context: context)),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _selPhone != null && _selCarId != null
                        ? ClientCarDetailView(
                            clientPhone: _selPhone!,
                            carId: _selCarId!,
                            showBack: false,
                            previewCarInfo: _selRow?['car_info']?.toString(),
                            previewClientName: _selRow?['client_name']?.toString(),
                            previewOrdersCount: _selRow?['orders_count']?.toString(),
                            previewLastAt: _formatDt(_selRow?['last_order_at']),
                            onAfterHardDeleteSuccess: () => setState(() {
                              _selPhone = null;
                              _selCarId = null;
                              _selRow = null;
                            }),
                          )
                        : _emptyDetail(),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _search,
      decoration: InputDecoration(
        hintText: 'Поиск: авто, телефон, клиент, ID…',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _carList(List<Map<String, dynamic>> filtered, {required bool wide, required BuildContext context}) {
    if (filtered.isEmpty) {
      return const Center(child: Text('Ничего не найдено', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = filtered[i];
        final phone = '${e['client_phone'] ?? ''}';
        final carId = '${e['car_id'] ?? ''}';
        final selected = wide && _selPhone == phone && _selCarId == carId;
        return _CarListCard(
          row: e,
          selected: selected,
          onTap: () {
            if (wide) {
              _select(e);
            } else {
              context.push(
                '/app/client-cars/history?phone=${Uri.encodeComponent(phone)}&car_id=${Uri.encodeComponent(carId)}',
              );
            }
          },
        );
      },
    );
  }

  Widget _emptyDetail() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.45)),
          const SizedBox(height: 16),
          Text(
            'Выберите автомобиль слева',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 8),
          Text(
            'Откроется карточка с характеристиками и историей заказов',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _CarListCard extends StatelessWidget {
  const _CarListCard({required this.row, required this.onTap, this.selected = false});

  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final carInfo = row['car_info']?.toString() ?? '—';
    final name = row['client_name']?.toString() ?? '—';
    final phone = row['client_phone']?.toString() ?? '';
    final count = row['orders_count'] ?? 0;
    final last = _formatDt(row['last_order_at']);
    final rawPhoto = row['car_photo_url']?.toString();
    final thumbUrl = internalClientCarPhotoImageUrl(rawPhoto);
    final thumbPlaceholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 26),
    );

    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              if (!selected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbUrl != null)
                CcAuthNetworkImage(
                  url: thumbUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  placeholder: thumbPlaceholder,
                )
              else
                thumbPlaceholder,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carInfo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    if (phone.isNotEmpty)
                      Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(Icons.receipt_long_rounded, '$count заказ.'),
                        _chip(Icons.event_rounded, last),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

String _formatDt(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return DateFormat('dd.MM.yyyy HH:mm').format(d.toLocal());
}
