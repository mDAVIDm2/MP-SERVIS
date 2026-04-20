import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../core/settings/locale_provider.dart';
import '../../../../core/settings/theme_mode_provider.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/app_lock_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/garage_car_photo_image.dart';
import '../../../../shared/models/car_document_model.dart' show CarDocument, kCarDocumentTypes;
import '../../../../shared/models/car_model.dart' show Car;
import '../../../../shared/models/order_model.dart' show Order;
import '../../../../shared/models/profile_note_model.dart';
import '../../../garage/presentation/screens/add_car_screen.dart';
import '../../../garage/presentation/screens/car_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'analytics_screen.dart';
import 'notes_screen.dart';
import 'settings_notifications_screen.dart';
import 'security_screen.dart';
import 'faq_screen.dart';
import 'about_screen.dart';
import 'map_settings_screen.dart';
import 'maintenance_reminders_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';

/// По строке срока («до 15 марта 2026») возвращает статус и цвет для ОСАГО/техосмотра.
(String, Color)? _documentStatusFromExpiry(String expiry) {
  final match = RegExp(r'до\s+(\d{1,2})\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\s+(\d{4})').firstMatch(expiry.trim());
  if (match == null) return null;
  const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  final day = int.tryParse(match.group(1) ?? '') ?? 0;
  final month = months.indexWhere((m) => m == match.group(2)) + 1;
  final year = int.tryParse(match.group(3) ?? '') ?? 0;
  if (month < 1 || day < 1 || day > 31) return null;
  DateTime expiryDate;
  try {
    expiryDate = DateTime(year, month, day);
  } catch (_) {
    return null;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expiryOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
  if (expiryOnly.isBefore(today)) {
    return ('Истек', SemanticColors.error);
  }
  final daysLeft = expiryOnly.difference(today).inDays;
  if (daysLeft <= 20) {
    return ('Истекает', SemanticColors.warning);
  }
  return ('Активен', SemanticColors.success);
}


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(L10nScope.of(context).profileTitle, style: AppTextStyles.screenTitle(context.palette)),
                ),
              ),
            ),
            _buildProfileHeader(context, ref),
            SizedBox(height: 20),
            _buildCarsSection(context, ref),
            SizedBox(height: 20),
            _buildDocumentsSection(context, ref),
            SizedBox(height: 20),
            _buildAnalyticsPreview(context, ref),
            SizedBox(height: 20),
            _buildNotesSection(context, ref),
            SizedBox(height: 20),
            _buildSettingsSection(context, ref),
            SizedBox(height: 16),
            _buildSupportSection(context, ref),
            SizedBox(height: 16),
            _buildLogoutSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = user?.displayName ?? L10nScope.of(context).guest;
    final phone = user?.accountLabel ?? '—';
    final initials = user?.initials ?? '?';
    final rawAvatar = user?.avatarUrl?.trim() ?? '';
    final avatarResolved = rawAvatar.isNotEmpty ? AppConfig.resolveProfileAvatarUrl(rawAvatar) : '';
    final token = ref.watch(authProvider).accessToken;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.palette.nestedBg,
                border: Border.all(color: context.palette.primary, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarResolved.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarResolved,
                      cacheKey: avatarResolved,
                      fit: BoxFit.cover,
                      httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : null,
                      placeholder: (_, __) => Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: context.palette.primary,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: context.palette.primary,
                        ),
                      ),
                    ),
            ),
            SizedBox(height: 16),
            Text(name, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
            )),
            SizedBox(height: 4),
            Text(phone, style: TextStyle(
              fontSize: 14, color: context.palette.textSecondary,
            )),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              child: Text(L10nScope.of(context).editProfile, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: context.palette.primary,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarsSection(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCarIdProvider);
    final activeId = selectedId ?? (cars.isNotEmpty ? cars.first.id : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L10nScope.of(context).myCars, style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
              )),
              TextButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddCarScreen())),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('+ Добавить', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: context.palette.primary,
                )),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        _ProfileMyCarsStrip(
          cars: cars,
          activeId: activeId,
          onSelectCar: (id) {
            ref.read(selectedCarIdProvider.notifier).set(id);
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => CarDetailScreen(carId: id)),
            );
          },
          onAddCar: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddCarScreen())),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCarIdProvider);
    final carId = selectedId ?? (cars.isNotEmpty ? cars.first.id : null);
    final allDocs = ref.watch(carDocumentsProvider);
    final docs = carId != null ? allDocs.where((d) => d.carId == carId).toList() : <CarDocument>[];
    String? carName;
    Car? selectedCar;
    if (carId != null) {
      final idx = cars.indexWhere((c) => c.id == carId);
      if (idx >= 0) {
        carName = '${cars[idx].brand} ${cars[idx].model}';
        selectedCar = cars[idx];
      }
    }
    final hasCarVin = selectedCar?.vin != null && selectedCar!.vin!.isNotEmpty;
    final isEmpty = docs.isEmpty && !hasCarVin;
    return _SectionGroup(
      title: carName != null ? 'Документы · $carName' : 'Документы',
      children: isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cars.isEmpty ? 'Добавьте автомобиль, чтобы привязать документы' : 'Нет документов для выбранного авто',
                      style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                    ),
                    if (carId != null) ...[
                      SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAddDocumentDialog(context, ref, carId),
                        icon: Icon(Icons.add_rounded, size: 18),
                        label: Text('Добавить документ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.palette.primary,
                          side: BorderSide(color: context.palette.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ]
          : [
              if (hasCarVin)
                _DocumentCard(
                  icon: '🔢',
                  type: 'VIN',
                  detail: selectedCar.vin ?? '',
                  status: 'Указан в профиле авто',
                  expiry: null,
                  statusColor: context.palette.success,
                  onTap: () {},
                ),
              ...docs.map((d) {
                final isOsagoOrInspection = d.type == 'ОСАГО' || d.type == 'Техосмотр';
                final resolved = isOsagoOrInspection && d.expiry != null ? _documentStatusFromExpiry(d.expiry!) : null;
                final displayStatus = resolved?.$1 ?? d.status;
                final displayColor = resolved?.$2 ?? d.statusColor;
                return _DocumentCard(
                  icon: '📄',
                  type: d.type,
                  detail: d.detail,
                  status: displayStatus,
                  expiry: d.expiry,
                  statusColor: displayColor,
                  onTap: () => _openDocumentDetail(context, ref, d),
                );
              }),
              if (carId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddDocumentDialog(context, ref, carId),
                    icon: Icon(Icons.add_rounded, size: 18),
                    label: Text('Добавить документ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.primary,
                      side: BorderSide(color: context.palette.primary),
                    ),
                  ),
                ),
            ],
    );
  }

  void _showAddDocumentDialog(BuildContext context, WidgetRef ref, String carId) {
    String selectedType = kCarDocumentTypes.first;
    final detailController = TextEditingController();
    final expiryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.palette.cardBg,
          title: Text('Добавить документ', style: TextStyle(color: context.palette.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тип', style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  dropdownColor: context.palette.cardBg,
                  items: kCarDocumentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v ?? selectedType),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: detailController,
                  decoration: InputDecoration(
                    labelText: selectedType == 'VIN' ? 'VIN (17 символов)' : 'Номер / данные',
                    hintText: selectedType == 'ОСАГО' ? 'XXX 1234567890' : (selectedType == 'VIN' ? 'WBA...' : ''),
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: context.palette.textSecondary),
                  ),
                  style: TextStyle(color: context.palette.textPrimary),
                  maxLines: selectedType == 'VIN' ? 1 : 2,
                ),
                if (selectedType == 'ОСАГО' || selectedType == 'Техосмотр') ...[
                  SizedBox(height: 12),
                  TextField(
                    controller: expiryController,
                    decoration: InputDecoration(
                      labelText: 'Срок действия (например: до 15 марта 2026)',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: context.palette.textSecondary),
                    ),
                    style: TextStyle(color: context.palette.textPrimary),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена')),
            FilledButton(
              onPressed: () {
                final detail = detailController.text.trim();
                if (detail.isEmpty) return;
                final doc = CarDocument(
                  carId: carId,
                  type: selectedType,
                  detail: detail,
                  expiry: expiryController.text.trim().isEmpty ? null : expiryController.text.trim(),
                  status: 'Активен',
                  statusColor: context.palette.success,
                );
                ref.read(carDocumentsProvider.notifier).addDocument(doc);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: context.palette.primary, foregroundColor: context.palette.onAccent),
              child: Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocumentDetail(BuildContext context, WidgetRef ref, CarDocument doc) {
    final isOsagoOrInspection = doc.type == 'ОСАГО' || doc.type == 'Техосмотр';
    final resolved = isOsagoOrInspection && doc.expiry != null ? _documentStatusFromExpiry(doc.expiry!) : null;
    final displayStatus = resolved?.$1 ?? doc.status;
    final displayColor = resolved?.$2 ?? doc.statusColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.type, style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
              )),
              SizedBox(height: 12),
              Text(doc.detail, style: TextStyle(
                fontSize: 16, color: context.palette.textSecondary,
              )),
              if (doc.expiry != null) ...[
                SizedBox(height: 8),
                Text(doc.expiry!, style: TextStyle(
                  fontSize: 14, color: context.palette.textSecondary,
                )),
              ],
              if (displayStatus != null && displayColor != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(displayStatus, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: displayColor,
                    )),
                  ],
                ),
              ],
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showEditDocumentDialog(ctx, ref, doc, () => Navigator.pop(ctx)),
                  icon: Icon(Icons.edit_rounded, size: 20),
                  label: Text('Редактировать'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.primary,
                    side: BorderSide(color: context.palette.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDocumentDialog(
    BuildContext context,
    WidgetRef ref,
    CarDocument doc,
    VoidCallback onSaved,
  ) {
    final detailController = TextEditingController(text: doc.detail);
    final statusController = TextEditingController(text: doc.status ?? '');
    final expiryController = TextEditingController(text: doc.expiry ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text('Редактировать ${doc.type}', style: TextStyle(color: context.palette.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Тип документа', style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
              SizedBox(height: 4),
              Text(doc.type, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
              SizedBox(height: 16),
              TextField(
                controller: detailController,
                decoration: InputDecoration(
                  labelText: 'Данные (номер полиса, описание и т.д.)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: context.palette.textSecondary),
                ),
                style: TextStyle(color: context.palette.textPrimary),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              TextField(
                controller: statusController,
                decoration: InputDecoration(
                  labelText: 'Статус (например: Активен)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: context.palette.textSecondary),
                ),
                style: TextStyle(color: context.palette.textPrimary),
              ),
              SizedBox(height: 12),
              TextField(
                controller: expiryController,
                decoration: InputDecoration(
                  labelText: 'Срок (например: до 15 марта 2026)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: context.palette.textSecondary),
                ),
                style: TextStyle(color: context.palette.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: context.palette.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final detail = detailController.text.trim();
              if (detail.isEmpty) return;
              final status = statusController.text.trim();
              final expiry = expiryController.text.trim();
              final updated = CarDocument(
                carId: doc.carId,
                type: doc.type,
                detail: detail,
                status: status.isEmpty ? null : status,
                expiry: expiry.isEmpty ? null : expiry,
                statusColor: status.isNotEmpty ? context.palette.success : doc.statusColor,
              );
              ref.read(carDocumentsProvider.notifier).updateDocument(updated);
              Navigator.pop(ctx);
              onSaved();
            },
            style: FilledButton.styleFrom(backgroundColor: context.palette.primary, foregroundColor: context.palette.onAccent),
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPreview(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCarIdProvider);
    final carId = selectedId ?? (cars.isNotEmpty ? cars.first.id : null);
    Car? car;
    if (carId != null) {
      final idx = cars.indexWhere((c) => c.id == carId);
      if (idx >= 0) car = cars[idx];
    }
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];
    final c = car;
    final carOrders = c != null ? orders.where((o) => o.carId == c.id).toList() : <Order>[];
    final totalSpent = carOrders.fold(0, (sum, o) => sum + o.totalKopecks);
    final avgCheck = carOrders.isNotEmpty ? totalSpent ~/ carOrders.length : 0;
    final l10n = L10nScope.of(context);
    final carLabel = car != null ? '${car.brand} ${car.model}' : l10n.carShortLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: context.palette.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.analyticsPreviewTitle, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.palette.nestedBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(carLabel, style: TextStyle(fontSize: 12, color: context.palette.textPrimary)),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: context.palette.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.analyticsPreviewTotalSpend, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                      SizedBox(height: 4),
                      Text(Formatters.money(totalSpent), style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: context.palette.textPrimary, fontFamily: 'monospace',
                      )),
                    ],
                  )),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.analyticsPreviewAvgCheck, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                      SizedBox(height: 4),
                      Text(Formatters.money(avgCheck), style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: context.palette.textPrimary, fontFamily: 'monospace',
                      )),
                    ],
                  )),
                ],
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [0.4, 0.6, 0.3, 0.8, 0.5, 0.7, 0.9, 0.4, 0.6, 0.5, 0.3, 0.7].map((h) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 60 * h,
                          decoration: BoxDecoration(
                            color: context.palette.primary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.analyticsPreviewSeeMore,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.palette.primary,
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

  Widget _buildNotesSection(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCarIdProvider);
    final carId = selectedId ?? (cars.isNotEmpty ? cars.first.id : null);
    final allNotes = ref.watch(profileNotesProvider);
    final notes = carId != null ? allNotes.where((n) => n.carId == carId).toList() : <ProfileNote>[];
    String? carName;
    if (carId != null) {
      final idx = cars.indexWhere((c) => c.id == carId);
      if (idx >= 0) carName = '${cars[idx].brand} ${cars[idx].model}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                carName != null ? 'Заметки · $carName' : 'Заметки',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    cars.isEmpty ? 'Добавьте автомобиль для заметок' : 'Нет заметок для выбранного авто',
                    style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                  ),
                )
              else
                Column(
                  children: [
                    ...notes.take(3).map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NoteCard(
                            title: n.title,
                            body: n.body,
                            date: '${n.date.day}.${n.date.month.toString().padLeft(2, '0')}',
                          ),
                        )),
                  ],
                ),
              SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotesScreen(selectedCarId: carId)),
                  ),
                  child: Text(
                    'Все заметки',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.palette.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    final mapProvider = ref.watch(mapProviderSettingProvider);
    final filterByCar = ref.watch(filterByCarSettingProvider);
    ref.watch(localeProvider);
    final currentLocale = ref.read(localeProvider.notifier).currentAppLocale;
    final themeMode = ref.watch(themeModeProvider);
    final l10n = L10nScope.of(context);
    final localeLabel = currentLocale == AppLocale.ru ? l10n.languageRussian : l10n.languageEnglish;
    final themeLabel = switch (themeMode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
    return _SectionGroup(title: l10n.settings, children: [
      _SettingsSwitchRow(
        icon: Icons.directions_car_rounded,
        label: l10n.sortByCar,
        subtitle: l10n.sortByCarSubtitle,
        value: filterByCar,
        onChanged: (v) => ref.read(filterByCarSettingProvider.notifier).set(v),
      ),
      _SettingsRow(icon: Icons.map_rounded, label: l10n.maps, trailing: mapProvider.shortName,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MapSettingsScreen()))),
      _SettingsRow(icon: Icons.notifications_outlined, label: l10n.notifications,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SettingsNotificationsScreen()))),
      _SettingsRow(icon: Icons.alarm_rounded, label: l10n.maintenanceReminders,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MaintenanceRemindersScreen()))),
      _SettingsRow(icon: Icons.straighten_rounded, label: l10n.units,
        onTap: () => _showSnack(context, l10n.unitsSetting)),
      _SettingsRow(
        icon: Icons.palette_rounded,
        label: l10n.theme,
        trailing: themeLabel,
        onTap: () => _showThemeSheet(context, ref),
      ),
      _SettingsRow(icon: Icons.language_rounded, label: l10n.language, trailing: localeLabel,
        onTap: () => _showLanguageSheet(context, ref)),
      _SettingsRow(icon: Icons.lock_outline_rounded, label: l10n.security,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SecurityScreen()))),
    ]);
  }

  Widget _buildSupportSection(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    return _SectionGroup(title: l10n.support, children: [
      _SettingsRow(icon: Icons.help_outline_rounded, label: l10n.faq,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const FaqScreen()))),
      _SettingsRow(icon: Icons.chat_bubble_outline_rounded, label: l10n.writeSupport,
        onTap: () async {
          final user = ref.read(authProvider).user;
          if (user == null) {
            _showSnack(context, 'Войдите в аккаунт, чтобы написать в поддержку');
            return;
          }
          final repo = ref.read(chatRepositoryProvider);
          final r = await repo.openSupportChat();
          if (!context.mounted) return;
          r.when(
            success: (chat) {
              ref.invalidate(chatsProvider);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
              );
            },
            failure: (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: context.palette.error),
              );
            },
          );
        }),
      _SettingsRow(icon: Icons.star_outline_rounded, label: l10n.rateApp,
        onTap: () => _showSnack(context, l10n.rateRedirect)),
      _SettingsRow(icon: Icons.info_outline_rounded, label: l10n.about,
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AboutScreen()))),
    ]);
  }

  Widget _buildLogoutSection(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    return _SectionGroup(title: l10n.account, children: [
      _SettingsRow(
        icon: Icons.logout_rounded,
        label: l10n.logout,
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.palette.cardBg,
              title: Text(l10n.logoutConfirmTitle, style: TextStyle(color: context.palette.textPrimary)),
              content: Text(
                l10n.logoutConfirmMessage,
                style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel, style: TextStyle(color: context.palette.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.logoutButton, style: TextStyle(color: context.palette.error)),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            ref.read(appLockProvider.notifier).unlock();
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.logoutDone), backgroundColor: context.palette.success),
              );
            }
          }
        },
      ),
    ]);
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.palette.info, duration: const Duration(seconds: 1)));
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    final current = ref.read(themeModeProvider);
    const modes = [ThemeMode.dark, ThemeMode.light, ThemeMode.system];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.theme,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...modes.map((mode) {
                final title = switch (mode) {
                  ThemeMode.light => l10n.themeLight,
                  ThemeMode.dark => l10n.themeDark,
                  ThemeMode.system => l10n.themeSystem,
                };
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  trailing: current == mode
                      ? Icon(Icons.check_circle_rounded, color: context.palette.primary, size: 24)
                      : null,
                  onTap: () async {
                    await ref.read(themeModeProvider.notifier).setMode(mode);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    final msg = switch (mode) {
                      ThemeMode.light => l10n.themeSetLight,
                      ThemeMode.dark => l10n.themeSetDark,
                      ThemeMode.system => l10n.themeSetSystem,
                    };
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: context.palette.success,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    final notifier = ref.read(localeProvider.notifier);
    final current = notifier.currentAppLocale;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.language,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              ...AppLocale.values.map((loc) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  loc == AppLocale.ru ? l10n.languageRussian : l10n.languageEnglish,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.palette.textPrimary,
                  ),
                ),
                trailing: current == loc
                    ? Icon(Icons.check_circle_rounded, color: context.palette.primary, size: 24)
                    : null,
                onTap: () async {
                  await notifier.setLocale(loc);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc == AppLocale.ru ? l10n.languageSetRu : l10n.languageSetEn),
                        backgroundColor: context.palette.success,
                      ),
                    );
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStripGaragePhoto extends ConsumerWidget {
  const _ProfileStripGaragePhoto({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return GarageCarPhotoImage(
      photoUrl: photoUrl,
      fit: BoxFit.cover,
    );
  }
}

class _ProfileMyCarsStrip extends StatefulWidget {
  const _ProfileMyCarsStrip({
    required this.cars,
    required this.activeId,
    required this.onSelectCar,
    required this.onAddCar,
  });

  final List<Car> cars;
  final String? activeId;
  final void Function(String carId) onSelectCar;
  final VoidCallback onAddCar;

  @override
  State<_ProfileMyCarsStrip> createState() => _ProfileMyCarsStripState();
}

class _ProfileMyCarsStripState extends State<_ProfileMyCarsStrip> {
  String? _lastCenteredId;

  Widget _profileStripCarPhoto(String? photoUrl) {
    final raw = (photoUrl ?? '').trim();
    if (raw.isEmpty) {
      return ColoredBox(
        color: context.palette.nestedBg,
        child: Center(
          child: Icon(
            Icons.directions_car_rounded,
            size: 28,
            color: context.palette.textTertiary.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    return _ProfileStripGaragePhoto(photoUrl: raw);
  }

  @override
  Widget build(BuildContext context) {
    final activeId = widget.activeId;
    if (activeId != null && activeId != _lastCenteredId) {
      _lastCenteredId = activeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        scrollWidgetToViewportCenter(GlobalObjectKey(activeId).currentContext);
      });
    } else if (activeId != _lastCenteredId) {
      _lastCenteredId = activeId;
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.cars.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (_, i) {
          if (i == widget.cars.length) {
            return GestureDetector(
              onTap: widget.onAddCar,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: context.palette.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 28, color: context.palette.primary),
                    SizedBox(height: 6),
                    Text(L10nScope.of(context).add, style: TextStyle(fontSize: 12, color: context.palette.primary)),
                  ],
                ),
              ),
            );
          }
          final car = widget.cars[i];
          final isActive = car.id == activeId;
          return GestureDetector(
            key: GlobalObjectKey(car.id),
            onTap: () => widget.onSelectCar(car.id),
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? context.palette.primary.withValues(alpha: 0.08) : context.palette.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? context.palette.primary : context.palette.border,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 100,
                      height: 50,
                      child: _profileStripCarPhoto(car.photoUrl),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${car.brand} ${car.model}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (car.plateNumber != null)
                    Text(car.plateNumber!, style: TextStyle(fontSize: 11, color: context.palette.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
          )),
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.palette.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.palette.textSecondary),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, color: context.palette.textPrimary)),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.palette.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: context.palette.textSecondary),
            SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: context.palette.textPrimary))),
            if (trailing != null)
              Text(trailing!, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String icon, type, detail;
  final String? status, expiry;
  final Color? statusColor;
  final VoidCallback? onTap;
  const _DocumentCard({required this.icon, required this.type, required this.detail,
    this.status, this.statusColor, this.expiry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 24)),
        SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
            SizedBox(height: 2),
            Text(detail, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
            if (expiry != null) ...[
              SizedBox(height: 2),
              Text(expiry!, style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
            ],
            if (status != null && statusColor != null) ...[
              SizedBox(height: 4),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: statusColor, shape: BoxShape.circle)),
                SizedBox(width: 6),
                Text(status!, style: TextStyle(fontSize: 12, color: statusColor)),
              ]),
            ],
          ],
        )),
        Icon(Icons.chevron_right_rounded, size: 20, color: context.palette.textTertiary),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.palette.border, width: 0.5)),
        ),
        child: child,
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String title, body, date;
  const _NoteCard({required this.title, required this.body, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(date, style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
          ]),
          SizedBox(height: 6),
          Text(body, style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
