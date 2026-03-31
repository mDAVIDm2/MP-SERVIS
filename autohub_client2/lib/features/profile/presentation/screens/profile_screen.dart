import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../core/settings/locale_provider.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/app_lock_provider.dart';
import '../../../../shared/models/car_document_model.dart' show CarDocument, kCarDocumentTypes;
import '../../../../shared/models/car_model.dart' show Car;
import '../../../../shared/models/order_model.dart' show Order;
import '../../../../shared/models/profile_note_model.dart';
import '../../../garage/presentation/screens/add_car_screen.dart';
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
    return ('Истек', AppColors.error);
  }
  final daysLeft = expiryOnly.difference(today).inDays;
  if (daysLeft <= 20) {
    return ('Истекает', AppColors.warning);
  }
  return ('Активен', AppColors.success);
}


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  child: Text(L10nScope.of(context).profileTitle, style: AppTextStyles.screenTitle),
                ),
              ),
            ),
            _buildProfileHeader(context, ref),
            const SizedBox(height: 20),
            _buildCarsSection(context, ref),
            const SizedBox(height: 20),
            _buildDocumentsSection(context, ref),
            const SizedBox(height: 20),
            _buildAnalyticsPreview(context, ref),
            const SizedBox(height: 20),
            _buildNotesSection(context, ref),
            const SizedBox(height: 20),
            _buildSettingsSection(context, ref),
            const SizedBox(height: 16),
            _buildSupportSection(context, ref),
            const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: AppColors.nestedBg,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Center(child: Text(initials, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary,
              ))),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 4),
            Text(phone, style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary,
            )),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              child: Text(L10nScope.of(context).editProfile, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary,
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
              Text(L10nScope.of(context).myCars, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
              )),
              TextButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddCarScreen())),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('+ Добавить', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary,
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ProfileMyCarsStrip(
          cars: cars,
          activeId: activeId,
          onSelectCar: (id) => ref.read(selectedCarIdProvider.notifier).set(id),
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
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (carId != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAddDocumentDialog(context, ref, carId),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Добавить документ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
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
                  statusColor: AppColors.success,
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
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Добавить документ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
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
          backgroundColor: AppColors.cardBg,
          title: const Text('Добавить документ', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Тип', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  dropdownColor: AppColors.cardBg,
                  items: kCarDocumentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v ?? selectedType),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailController,
                  decoration: InputDecoration(
                    labelText: selectedType == 'VIN' ? 'VIN (17 символов)' : 'Номер / данные',
                    hintText: selectedType == 'ОСАГО' ? 'XXX 1234567890' : (selectedType == 'VIN' ? 'WBA...' : ''),
                    border: const OutlineInputBorder(),
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  maxLines: selectedType == 'VIN' ? 1 : 2,
                ),
                if (selectedType == 'ОСАГО' || selectedType == 'Техосмотр') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: expiryController,
                    decoration: const InputDecoration(
                      labelText: 'Срок действия (например: до 15 марта 2026)',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
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
                  statusColor: AppColors.success,
                );
                ref.read(carDocumentsProvider.notifier).addDocument(doc);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: const Color(0xFF0D0D0D)),
              child: const Text('Добавить'),
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
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.type, style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
              const SizedBox(height: 12),
              Text(doc.detail, style: const TextStyle(
                fontSize: 16, color: AppColors.textSecondary,
              )),
              if (doc.expiry != null) ...[
                const SizedBox(height: 8),
                Text(doc.expiry!, style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary,
                )),
              ],
              if (displayStatus != null && displayColor != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(displayStatus, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: displayColor,
                    )),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showEditDocumentDialog(ctx, ref, doc, () => Navigator.pop(ctx)),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text('Редактировать'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
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
        backgroundColor: AppColors.cardBg,
        title: Text('Редактировать ${doc.type}', style: const TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Тип документа', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(doc.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: detailController,
                decoration: const InputDecoration(
                  labelText: 'Данные (номер полиса, описание и т.д.)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: statusController,
                decoration: const InputDecoration(
                  labelText: 'Статус (например: Активен)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryController,
                decoration: const InputDecoration(
                  labelText: 'Срок (например: до 15 марта 2026)',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
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
                statusColor: status.isNotEmpty ? AppColors.success : doc.statusColor,
              );
              ref.read(carDocumentsProvider.notifier).updateDocument(updated);
              Navigator.pop(ctx);
              onSaved();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: const Color(0xFF0D0D0D)),
            child: const Text('Сохранить'),
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
    final carLabel = car != null ? '${car.brand} ${car.model}' : 'Авто';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Аналитика', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.nestedBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(carLabel, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Общие расходы', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(Formatters.money(totalSpent), style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'monospace',
                      )),
                    ],
                  )),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Средний чек', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(Formatters.money(avgCheck), style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'monospace',
                      )),
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 12),
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
                            color: AppColors.primary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('Подробнее →', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary,
                )),
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
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    cars.isEmpty ? 'Добавьте автомобиль для заметок' : 'Нет заметок для выбранного авто',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotesScreen(selectedCarId: carId)),
                  ),
                  child: const Text(
                    'Все заметки',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary),
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
    final l10n = L10nScope.of(context);
    final localeLabel = currentLocale == AppLocale.ru ? l10n.languageRussian : l10n.languageEnglish;
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
      _SettingsRow(icon: Icons.palette_rounded, label: l10n.theme, trailing: l10n.themeDark,
        onTap: () => _showSnack(context, l10n.themeSetting)),
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
                SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
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
              backgroundColor: AppColors.cardBg,
              title: Text(l10n.logoutConfirmTitle, style: const TextStyle(color: AppColors.textPrimary)),
              content: Text(
                l10n.logoutConfirmMessage,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.logoutButton, style: const TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            ref.read(appLockProvider.notifier).unlock();
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.logoutDone), backgroundColor: AppColors.success),
              );
            }
          }
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          l10n.authDataNote,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ),
    ]);
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.info, duration: const Duration(seconds: 1)));
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    final notifier = ref.read(localeProvider.notifier);
    final current = notifier.currentAppLocale;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
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
                l10n.language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...AppLocale.values.map((loc) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  loc == AppLocale.ru ? l10n.languageRussian : l10n.languageEnglish,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: current == loc
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24)
                    : null,
                onTap: () async {
                  await notifier.setLocale(loc);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc == AppLocale.ru ? l10n.languageSetRu : l10n.languageSetEn),
                        backgroundColor: AppColors.success,
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
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          if (i == widget.cars.length) {
            return GestureDetector(
              onTap: widget.onAddCar,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 28, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(L10nScope.of(context).add, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
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
                color: isActive ? AppColors.primary.withValues(alpha: 0.08) : AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.nestedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 28,
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${car.brand} ${car.model}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (car.plateNumber != null)
                    Text(car.plateNumber!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
          child: Text(title, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary))),
            if (trailing != null)
              Text(trailing!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
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
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(detail, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            if (expiry != null) ...[
              const SizedBox(height: 2),
              Text(expiry!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            if (status != null && statusColor != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(status!, style: TextStyle(fontSize: 12, color: statusColor)),
              ]),
            ],
          ],
        )),
        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
