import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../shared/models/order_model.dart';

/// Экран «Фото по заказу»: просмотр и добавление фото (через API).
class OrderPhotosScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderPhotosScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderPhotosScreen> createState() => _OrderPhotosScreenState();
}

class _OrderPhotosScreenState extends ConsumerState<OrderPhotosScreen> {
  List<OrderPhoto> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(orderApiServiceProvider);
    final result = await api.getOrderPhotos(widget.orderId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.dataOrNull != null) {
        _photos = result.dataOrNull!;
        _error = null;
      } else {
        _error = result.errorOrNull?.message ?? 'Не удалось загрузить список';
      }
    });
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
    if (xFile == null || !mounted) return;
    setState(() => _uploading = true);
    final bytes = await xFile.readAsBytes();
    final api = ref.read(orderApiServiceProvider);
    final result = await api.uploadOrderPhoto(widget.orderId, bytes, xFile.name);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result.dataOrNull != null) {
      await _loadPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото добавлено'), backgroundColor: AppColors.cardBg),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorOrNull?.message ?? 'Не удалось загрузить фото'),
            backgroundColor: AppColors.cardBg,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Фото по заказу')),
        body: const Center(
          child: Text('Заказ не найден', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Фото по заказу'),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _addPhoto,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadPhotos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : _photos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(order.carInfo, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                          const SizedBox(height: 32),
                          const Text(
                            'Фотографии по заказу (до/после работ)',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _addPhoto,
                            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                            label: const Text('Добавить фото'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPhotos,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.orderNumber, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(order.carInfo, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final photo = _photos[index];
                                  return _PhotoTile(orderId: widget.orderId, photoId: photo.id);
                                },
                                childCount: _photos.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  final String orderId;
  final String photoId;

  const _PhotoTile({required this.orderId, required this.photoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBytes = ref.watch(orderPhotoBytesProvider((orderId, photoId)));
    return asyncBytes.when(
      data: (Uint8List? bytes) {
        if (bytes == null || bytes.isEmpty) {
          return Container(
            color: AppColors.cardBg,
            child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary, size: 48)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      },
      loading: () => Container(
        color: AppColors.cardBg,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      ),
      error: (_, __) => Container(
        color: AppColors.cardBg,
        child: const Center(child: Icon(Icons.error_outline, color: AppColors.textTertiary)),
      ),
    );
  }
}
