import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/models/organization_model.dart';
import '../../../../shared/models/organization_business_kind.dart';
import 'map_picker_screen.dart';

class OrganizationSettingsScreen extends ConsumerStatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  ConsumerState<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends ConsumerState<OrganizationSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _hoursController;
  bool _initialized = false;
  bool _uploadingPhoto = false;
  double? _latitude;
  double? _longitude;
  String _businessKindCode = OrganizationBusinessKindCodes.sto;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _hoursController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(String? orgId) async {
    if (orgId == null || orgId.isEmpty || _uploadingPhoto) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
    if (xFile == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    final file = File(xFile.path);
    final result = await ref.read(organizationRepositoryProvider.notifier).addPhoto(orgId, file);
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото добавлено'), backgroundColor: AppColors.cardBg),
      ),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  Widget _buildPhotosSection(OrganizationInfo org) {
    final orgId = ref.read(authProvider).user?.organizationId;
    final photos = org.photoUrls.where((u) => u.isNotEmpty).toList();
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...photos.map((url) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: AppColors.cardBg,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
                ),
              ),
            ),
          )),
          GestureDetector(
            onTap: _uploadingPhoto ? null : () => _pickAndUploadPhoto(orgId),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.5)),
              ),
              child: _uploadingPhoto
                  ? const Center(child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ))
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.textSecondary),
                          SizedBox(height: 4),
                          Text('Добавить', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(organizationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Организация'),
        actions: [
          TextButton(
            onPressed: orgAsync.valueOrNull == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final currentOrg = orgAsync.valueOrNull;
                    final org = (currentOrg ?? const OrganizationInfo()).copyWith(
                      name: _nameController.text.trim(),
                      address: _addressController.text.trim(),
                      phone: _phoneController.text.trim(),
                      workingHours: _hoursController.text.trim(),
                      businessKind: _businessKindCode,
                      latitude: _latitude,
                      longitude: _longitude,
                    );
                    final result = await ref.read(organizationRepositoryProvider.notifier).update(org);
                    if (!context.mounted) return;
                    result.when(
                      success: (_) => messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Сохранено'),
                          backgroundColor: AppColors.cardBg,
                        ),
                      ),
                      failure: (e) => messenger.showSnackBar(
                        SnackBar(
                          content: Text(e.message),
                          backgroundColor: AppColors.error,
                        ),
                      ),
                    );
                  },
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: orgAsync.when(
        data: (org) {
          if (!_initialized) {
            _initialized = true;
            _nameController.text = org.name;
            _addressController.text = org.address;
            _phoneController.text = org.phone;
            _hoursController.text = org.workingHours;
            _latitude = org.latitude;
            _longitude = org.longitude;
            _businessKindCode = org.businessKind;
          }
          return RefreshIndicator(
            onRefresh: () async {
              final orgId = ref.read(authProvider).user?.organizationId;
              await ref.read(organizationRepositoryProvider.notifier).load(orgId);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
              const Text(
                'Фотографии автосервиса',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Отображаются в верхней части карточки точки у клиентов',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildPhotosSection(org),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Мой автосервис',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: OrganizationBusinessKindCodes.options.any((o) => o.$1 == _businessKindCode)
                    ? _businessKindCode
                    : OrganizationBusinessKindCodes.sto,
                decoration: const InputDecoration(
                  labelText: 'Тип организации',
                  helperText: 'Клиенты увидят корректную подпись в чате (например «Чат с мойкой»)',
                ),
                items: OrganizationBusinessKindCodes.options
                    .map((e) => DropdownMenuItem<String>(value: e.$1, child: Text(e.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _businessKindCode = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  hintText: 'г. Москва, ул. Примерная, 1',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+7 (999) 123-45-67',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              const Text(
                'Точка на карте',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Укажите местоположение точки для отображения на карте у клиентов',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _latitude != null && _longitude != null
                          ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                          : 'Не указана',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<dynamic>(
                        MaterialPageRoute(
                          builder: (context) => MapPickerScreen(
                            initialLat: _latitude,
                            initialLng: _longitude,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      if (result == null) {
                        setState(() {
                          _latitude = null;
                          _longitude = null;
                        });
                      } else if (result is LatLng) {
                        setState(() {
                          _latitude = (result as LatLng).latitude;
                          _longitude = (result as LatLng).longitude;
                        });
                      }
                    },
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text('Указать на карте'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hoursController,
                decoration: const InputDecoration(
                  labelText: 'Часы работы',
                  hintText: 'Пн–Пт 9:00–19:00',
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final role = ref.watch(authProvider).user?.role;
                  if (role != BusinessRole.owner && role != BusinessRole.solo) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final name = await showDialog<String>(
                          context: context,
                          builder: (ctx) => const _NewOrganizationDialog(),
                        );
                        if (name == null || name.isEmpty || !context.mounted) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final r = await ref.read(authProvider.notifier).createAdditionalOrganization(name: name);
                        if (!context.mounted) return;
                        r.when(
                          success: (_) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Организация создана'), backgroundColor: AppColors.cardBg),
                            );
                            final newOrgId = ref.read(authProvider).user?.organizationId;
                            ref.read(organizationRepositoryProvider.notifier).load(newOrgId);
                          },
                          failure: (e) => messenger.showSnackBar(
                            SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Добавить организацию'),
                    ),
                  );
                },
              ),
            ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}

class _NewOrganizationDialog extends StatefulWidget {
  const _NewOrganizationDialog();

  @override
  State<_NewOrganizationDialog> createState() => _NewOrganizationDialogState();
}

class _NewOrganizationDialogState extends State<_NewOrganizationDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая организация'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Название',
          hintText: 'Например, Сервис на Юге',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final t = _controller.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, t);
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
