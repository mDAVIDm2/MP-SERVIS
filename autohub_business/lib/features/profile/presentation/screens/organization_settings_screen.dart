import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/models/organization_model.dart';
import '../../../../shared/models/organization_hours_exception.dart';
import '../../../../shared/models/organization_business_kind.dart';
import '../../../../shared/models/organization_working_hours_week.dart';
import 'map_picker_screen.dart';
import '../widgets/create_organization_flow.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../shared/models/sto_amenity_catalog.dart';

class OrganizationSettingsScreen extends ConsumerStatefulWidget {
  const OrganizationSettingsScreen({
    super.key,
    this.desktopChrome = false,
    this.desktopEmbedInWorkspace = false,
  });

  /// Светлая центрированная вёрстка для вкладки «Мой сервис» на desktop.
  final bool desktopChrome;

  /// В единой карточке [OrganizationDesktopWorkspace]: без AppBar и без вложенной узкой колонки.
  final bool desktopEmbedInWorkspace;

  @override
  ConsumerState<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends ConsumerState<OrganizationSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late final PageController _photoPageController;
  /// Пн…вс, длина 7.
  List<OrganizationDayHours> _week =
      List.from(OrganizationWorkingHoursWeek.defaultTemplate().days);
  /// Разовые выходные / сокращённые дни.
  List<OrganizationHoursException> _exceptions = [];
  bool _initialized = false;
  bool _uploadingPhoto = false;
  bool _deletingPhoto = false;
  int _photoIndex = 0;
  double? _latitude;
  double? _longitude;
  String _businessKindCode = OrganizationBusinessKindCodes.sto;
  late final TextEditingController _publicDescriptionController;
  /// Синхронизация «О сервисе» с [settingsRepositoryProvider] (без затирания ввода).
  bool _publicDescSynced = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _publicDescriptionController = TextEditingController();
    _photoPageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _publicDescriptionController.dispose();
    super.dispose();
  }

  void _syncPublicDescriptionFromSettings(String text) {
    if (_publicDescSynced && _publicDescriptionController.text == text) {
      return;
    }
    _publicDescriptionController.text = text;
    _publicDescSynced = true;
  }

  Future<void> _pickAndUploadPhoto(String? orgId) async {
    if (orgId == null || orgId.isEmpty || _uploadingPhoto) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (xFile == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    final bytes = await xFile.readAsBytes();
    final name = xFile.name.trim().isNotEmpty ? xFile.name.trim() : 'service_photo.jpg';
    final result = await ref.read(organizationRepositoryProvider.notifier).addPhotoBytes(orgId, bytes, name);
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

  List<String> _rawPhotoUrls(OrganizationInfo org) {
    return org.photoUrls.where((u) => u.isNotEmpty).toList();
  }

  String _displayPhotoUrl(String raw) => AppConfig.resolveApiMediaUrl(raw) ?? raw;

  TimeOfDay _toTimeOfDay(String hm) {
    final p = hm.split(':');
    if (p.length != 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 9,
      minute: int.tryParse(p[1]) ?? 0,
    );
  }

  String _fromTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatHmForLabel(String hm) {
    final p = hm.split(':');
    if (p.length != 2) return hm;
    final h = int.tryParse(p[0]) ?? 0;
    return '$h:${p[1]}';
  }

  Future<void> _pickTime(BuildContext context, int dayIndex, bool isOpen) async {
    final d = _week[dayIndex];
    final initial = isOpen ? _toTimeOfDay(d.open) : _toTimeOfDay(d.close);
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (t == null || !mounted) return;
    final s = _fromTimeOfDay(t);
    setState(() {
      if (isOpen) {
        _week[dayIndex] = d.copyWith(open: s);
      } else {
        _week[dayIndex] = d.copyWith(close: s);
      }
    });
  }

  Widget _timeChip(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    required bool desktop,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        foregroundColor: desktop ? AppColorsDesktop.textPrimary : null,
        side: BorderSide(
          color: desktop ? AppColorsDesktop.border : AppColors.border,
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildWeekDayRow(
    BuildContext context, {
    required int i,
    required bool canEdit,
    required bool desktop,
  }) {
    final day = _week[i];
    final label = OrganizationWorkingHoursWeek.dayLabels[i];
    final textSec = desktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: desktop ? 118 : 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: desktop ? 14 : 13,
                color: desktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          if (canEdit) ...[
            Transform.scale(
              scale: 0.88,
              child: Switch(
                value: !day.closed,
                onChanged: (v) {
                  setState(() {
                    if (v) {
                      _week[i] = day.copyWith(
                        closed: false,
                        open: '09:00',
                        close: '19:00',
                      );
                    } else {
                      _week[i] = const OrganizationDayHours(
                        open: '00:00',
                        close: '00:00',
                        closed: true,
                      );
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (!day.closed) ...[
            if (canEdit)
              _timeChip(
                context,
                label: _formatHmForLabel(day.open),
                onTap: () => _pickTime(context, i, true),
                desktop: desktop,
              )
            else
              Text(
                _formatHmForLabel(day.open),
                style: TextStyle(fontSize: 14, color: textSec),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('—', style: TextStyle(color: textSec, fontSize: 14)),
            ),
            if (canEdit)
              _timeChip(
                context,
                label: _formatHmForLabel(day.close),
                onTap: () => _pickTime(context, i, false),
                desktop: desktop,
              )
            else
              Text(
                _formatHmForLabel(day.close),
                style: TextStyle(fontSize: 14, color: textSec),
              ),
          ] else
            Text(
              'Выходной',
              style: TextStyle(
                fontSize: 14,
                color: textSec,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursExceptionsSection(
    BuildContext context,
    bool canEdit,
    bool desktop,
    bool embed,
  ) {
    final subStyle = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: desktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment:
          desktop && !embed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(height: desktop ? 20 : 16),
        Text(
          'Исключения из графика',
          textAlign: desktop && !embed ? TextAlign.center : TextAlign.start,
          style: desktop
              ? DesktopDesignSystem.sectionTitle.copyWith(fontSize: embed ? 15 : 17)
              : const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          'Разовый выходной или особые часы в выбранную дату (основной график не меняется)',
          textAlign: desktop && !embed ? TextAlign.center : TextAlign.start,
          style: subStyle,
        ),
        SizedBox(height: desktop ? 12 : 10),
        if (_exceptions.isEmpty)
          Text(
            'Нет исключений',
            style: subStyle,
          ),
        ..._exceptions.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: desktop ? AppColorsDesktop.nestedBg : AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                title: Text(e.date, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  e.closed ? 'Выходной' : '${e.open ?? ''} – ${e.close ?? ''}',
                ),
                trailing: canEdit
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _exceptions = _exceptions.where((x) => x.date != e.date).toList();
                          });
                        },
                      )
                    : null,
              ),
            ),
          );
        }),
        if (canEdit)
          Align(
            alignment: desktop && !embed ? Alignment.center : Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openAddWorkingHoursException(context),
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Добавить исключение'),
            ),
          ),
      ],
    );
  }

  Future<void> _openAddWorkingHoursException(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    final ds =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (_exceptions.any((e) => e.date == ds)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('На эту дату уже есть исключение')),
      );
      return;
    }
    var closed = false;
    var openT = const TimeOfDay(hour: 9, minute: 0);
    var closeT = const TimeOfDay(hour: 19, minute: 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          int hm(TimeOfDay t) => t.hour * 60 + t.minute;
          return AlertDialog(
            title: Text('Исключение $ds'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: const Text('Выходной (не работаем)'),
                    value: closed,
                    onChanged: (v) => setSt(() => closed = v),
                  ),
                  if (!closed) ...[
                    ListTile(
                      title: const Text('Начало'),
                      subtitle: Text(_fromTimeOfDay(openT)),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: openT,
                          builder: (c, child) => MediaQuery(
                            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                        if (t != null) setSt(() => openT = t);
                      },
                    ),
                    ListTile(
                      title: const Text('Окончание'),
                      subtitle: Text(_fromTimeOfDay(closeT)),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: closeT,
                          builder: (c, child) => MediaQuery(
                            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                        if (t != null) setSt(() => closeT = t);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                onPressed: () {
                  if (!closed && hm(closeT) <= hm(openT)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Время «до» должно быть позже «с»')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      final next = closed
          ? OrganizationHoursException(date: ds, closed: true)
          : OrganizationHoursException(
              date: ds,
              open: _fromTimeOfDay(openT),
              close: _fromTimeOfDay(closeT),
            );
      _exceptions = [..._exceptions, next]..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _saveOrganizationData(BuildContext context) async {
    final d = widget.desktopChrome;
    final messenger = ScaffoldMessenger.of(context);
    final currentOrg = ref.read(organizationProvider).valueOrNull;
    final authUser = ref.read(authProvider).user;
    final orgIdForSave = authUser?.effectiveOrganizationId;
    final canEditOrg = authUser?.effectiveCanManageOrgSettings ?? false;
    if (!canEditOrg ||
        currentOrg == null ||
        orgIdForSave == null ||
        orgIdForSave.isEmpty) {
      return;
    }
    ref.read(settingsRepositoryProvider.notifier).setPublicDescription(_publicDescriptionController.text);
    final org = currentOrg.copyWith(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      workingHoursWeek: OrganizationWorkingHoursWeek(List.from(_week)),
      workingHoursExceptions: List.from(_exceptions),
      businessKind: _businessKindCode,
      latitude: _latitude,
      longitude: _longitude,
    );
    final result = await ref.read(organizationRepositoryProvider.notifier).update(org);
    if (!context.mounted) return;
    result.when(
      success: (_) => messenger.showSnackBar(
        SnackBar(
          content: const Text('Сохранено'),
          backgroundColor: d ? AppColorsDesktop.nestedBg : AppColors.cardBg,
          behavior: SnackBarBehavior.floating,
        ),
      ),
      failure: (e) => messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: d ? AppColorsDesktop.error : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  Future<void> _confirmAndDeletePhoto(String? orgId, String rawUrl) async {
    if (orgId == null || orgId.isEmpty || _deletingPhoto || _uploadingPhoto) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Снимок пропадёт из карточки точки у клиентов.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _deletingPhoto = true);
    final result = await ref.read(organizationRepositoryProvider.notifier).deletePhoto(orgId, rawUrl);
    if (!mounted) return;
    setState(() => _deletingPhoto = false);
    result.when(
      success: (_) {
        final org = ref.read(organizationRepositoryProvider).valueOrNull;
        final n = org != null ? _rawPhotoUrls(org).length : 0;
        if (!mounted) return;
        setState(() {
          if (n == 0) {
            _photoIndex = 0;
          } else if (_photoIndex >= n) {
            _photoIndex = n - 1;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (n > 0 && _photoPageController.hasClients) {
            _photoPageController.jumpToPage(_photoIndex.clamp(0, n - 1));
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото удалено'), backgroundColor: AppColors.cardBg),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  Widget _buildPhotosCarouselDesktop(OrganizationInfo org, {required bool canEdit}) {
    final orgId = ref.read(authProvider).user?.organizationId;
    final raws = _rawPhotoUrls(org);
    final errBg = AppColorsDesktop.nestedBg.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 268,
          child: PageView.builder(
            controller: _photoPageController,
            itemCount: raws.isEmpty ? 1 : raws.length,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (context, i) {
              if (raws.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: errBg,
                      alignment: Alignment.center,
                      child: Text(
                        'Добавьте фотографии — они покажутся в карточке точки у клиентов',
                        textAlign: TextAlign.center,
                        style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.4),
                      ),
                    ),
                  ),
                );
              }
              final raw = raws[i];
              final url = _displayPhotoUrl(raw);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: errBg,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, color: AppColorsDesktop.textTertiary, size: 40),
                        ),
                      ),
                      if (canEdit)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              tooltip: 'Удалить фото',
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                              onPressed: _uploadingPhoto || _deletingPhoto
                                  ? null
                                  : () => _confirmAndDeletePhoto(orgId, raw),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (raws.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              raws.length,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _photoIndex == i ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _photoIndex == i ? AppColorsDesktop.primary : AppColorsDesktop.border,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: !canEdit || _uploadingPhoto || _deletingPhoto ? null : () => _pickAndUploadPhoto(orgId),
            icon: _uploadingPhoto
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColorsDesktop.primary),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: Text(_uploadingPhoto ? 'Загрузка…' : 'Добавить фото'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColorsDesktop.primary,
              side: BorderSide(color: AppColorsDesktop.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(OrganizationInfo org, {required bool canEdit}) {
    if (widget.desktopChrome) return _buildPhotosCarouselDesktop(org, canEdit: canEdit);
    final orgId = ref.read(authProvider).user?.organizationId;
    final raws = _rawPhotoUrls(org);
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...raws.map((raw) {
            final url = _displayPhotoUrl(raw);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
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
                    if (canEdit)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _uploadingPhoto || _deletingPhoto ? null : () => _confirmAndDeletePhoto(orgId, raw),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (canEdit)
          GestureDetector(
            onTap: _uploadingPhoto || _deletingPhoto ? null : () => _pickAndUploadPhoto(orgId),
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

  Widget _buildSoloWithoutOrganizationScaffold(BuildContext context, bool d) {
    final bg = d ? AppColorsDesktop.background : AppColors.background;
    final textPri = d ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSec = d ? AppColorsDesktop.textSecondary : AppColors.textSecondary;

    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: d ? 520 : 400),
        child: Padding(
          padding: EdgeInsets.all(d ? 32 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: d ? 72 : 64,
                color: d ? AppColorsDesktop.primary.withValues(alpha: 0.85) : AppColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 24),
              Text(
                'Организация ещё не создана',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: d ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Создайте точку — ей присвоится ID, вы сможете указать адрес и отметить её на карте для клиентов, затем настроить услуги и расписание.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: d ? 15 : 14, height: 1.45, color: textSec),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => createOrganizationWithOptionalSoloOnboarding(context, ref, desktopChrome: d),
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Создать организацию'),
                style: FilledButton.styleFrom(
                  backgroundColor: d ? AppColorsDesktop.primary : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: d ? 16 : 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final scaffold = Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        centerTitle: d,
        title: Text(d ? 'Данные организации' : 'Организация'),
        backgroundColor: d ? AppColorsDesktop.surface : null,
        foregroundColor: d ? AppColorsDesktop.textPrimary : null,
        surfaceTintColor: d ? Colors.transparent : null,
        elevation: d ? 0 : null,
      ),
      body: body,
    );
    return d ? themeDesktopLight(child: scaffold) : scaffold;
  }

  Widget _clientFacingCardSection({
    required WidgetRef ref,
    required bool d,
    required bool embed,
    required bool canEdit,
    required SettingsState settings,
  }) {
    _syncPublicDescriptionFromSettings(settings.publicDescription);
    final titleStyle = d
        ? DesktopDesignSystem.sectionTitle.copyWith(fontSize: embed ? 15 : 17)
        : const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          );
    final subStyle = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: d ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
    );
    final boxBg = d ? AppColorsDesktop.nestedBg : AppColors.nestedBg;
    final boxBorder = d ? AppColorsDesktop.border : AppColors.border;
    final switchTileBg = d ? AppColorsDesktop.surface : AppColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d ? 28 : 24),
        Text(
          'Как вас видят в приложении клиента',
          textAlign: d && !embed ? TextAlign.center : TextAlign.start,
          style: titleStyle,
        ),
        const SizedBox(height: 4),
        Text(
          'Удобства на сервере сохраняются сразу. Текст «О сервисе» — вместе с кнопкой «Сохранить».',
          textAlign: d && !embed ? TextAlign.center : TextAlign.start,
          style: subStyle,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: boxBorder),
            boxShadow: d
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_cafe_outlined,
                    size: 20,
                    color: d ? AppColorsDesktop.primary : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Удобства',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: d ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Что отмечено — увидят клиенты в карточке сервиса (иконки и подписи).',
                style: subStyle,
              ),
              const SizedBox(height: 8),
              ...StoAmenityCatalog.all.map((a) {
                final selected = settings.amenityIds.contains(a.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Material(
                    color: switchTileBg,
                    borderRadius: BorderRadius.circular(10),
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      dense: true,
                      value: selected,
                      onChanged: canEdit
                          ? (v) {
                              ref.read(settingsRepositoryProvider.notifier).toggleAmenity(a.id);
                            }
                          : null,
                      title: Text(
                        a.label,
                        style: TextStyle(
                          fontSize: 15,
                          color: d ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: d ? AppColorsDesktop.primary : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'О сервисе',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: d ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Короткое описание: у клиентов сначала видны первые строки, полный текст — по кнопке «ещё».',
                style: subStyle,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _publicDescriptionController,
                readOnly: !canEdit,
                minLines: 4,
                maxLines: 10,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: d ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Опыт, оборудование, гарантия — что важно клиентам',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: d ? AppColorsDesktop.surface : AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: boxBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: d ? AppColorsDesktop.primary : AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final d = widget.desktopChrome;
    final soloWithoutOrg = authUser != null &&
        authUser.role == BusinessRole.solo &&
        authUser.effectiveOrganizationId == null;

    if (soloWithoutOrg) {
      return _buildSoloWithoutOrganizationScaffold(context, d);
    }

    final orgAsync = ref.watch(organizationProvider);
    final orgIdForSave = authUser?.effectiveOrganizationId;
    final canEditOrg = authUser?.effectiveCanManageOrgSettings ?? false;
    final embed = d && widget.desktopEmbedInWorkspace;

    final body = orgAsync.when(
        data: (org) {
          if (!_initialized) {
            _initialized = true;
            _nameController.text = org.name;
            _addressController.text = org.address;
            _phoneController.text = org.phone;
            _week = List.from(
              (org.workingHoursWeek ?? OrganizationWorkingHoursWeek.defaultTemplate()).days,
            );
            _exceptions = List.from(org.workingHoursExceptions ?? const []);
            _latitude = org.latitude;
            _longitude = org.longitude;
            _businessKindCode = org.businessKind;
          }
          final listChildren = <Widget>[
              if (embed && canEditOrg)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: orgAsync.valueOrNull == null ||
                              orgIdForSave == null ||
                              orgIdForSave.isEmpty
                          ? null
                          : () => _saveOrganizationData(context),
                      child: Text(
                        'Сохранить',
                        style: TextStyle(
                          color: AppColorsDesktop.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!canEditOrg)
                Padding(
                  padding: EdgeInsets.only(bottom: d ? 16 : 12),
                  child: Text(
                    'Изменение данных организации недоступно для вашей роли.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: d ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),
              if (d && !embed) ...[
                const SizedBox(height: 8),
                Text(
                  'Фотографии точки',
                  textAlign: TextAlign.center,
                  style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  'Листайте галерею — фото показываются клиентам в карточке сервиса',
                  textAlign: TextAlign.center,
                  style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45),
                ),
                const SizedBox(height: 20),
              ],
              if (d && embed) ...[
                Text(
                  'Фотографии точки',
                  style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Показываются клиентам в карточке сервиса',
                  style: DesktopDesignSystem.bodySecondary.copyWith(fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
              ],
              if (!d) ...[
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
              ],
              _buildPhotosSection(org, canEdit: canEditOrg),
              SizedBox(height: d ? 32 : 24),
              TextField(
                controller: _nameController,
                readOnly: !canEditOrg,
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
                onChanged: canEditOrg
                    ? (v) {
                        if (v == null) return;
                        setState(() => _businessKindCode = v);
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                readOnly: !canEditOrg,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  hintText: 'г. Москва, ул. Примерная, 1',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                readOnly: !canEditOrg,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+7 (999) 123-45-67',
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: d ? 28 : 20),
              Text(
                'Точка на карте',
                textAlign: d && !embed ? TextAlign.center : TextAlign.start,
                style: d
                    ? DesktopDesignSystem.sectionTitle.copyWith(fontSize: embed ? 15 : 17)
                    : const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                'Укажите местоположение точки для отображения на карте у клиентов',
                textAlign: d && !embed ? TextAlign.center : TextAlign.start,
                style: d
                    ? DesktopDesignSystem.bodySecondary.copyWith(
                        height: 1.45,
                        fontSize: embed ? 12 : null,
                      )
                    : const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (d)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _latitude != null && _longitude != null
                          ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                          : 'Не указана',
                      textAlign: embed ? TextAlign.start : TextAlign.center,
                      style: DesktopDesignSystem.body.copyWith(
                        color: AppColorsDesktop.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: embed ? 13 : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: embed ? Alignment.centerLeft : Alignment.center,
                      child: FilledButton.icon(
                        onPressed: !canEditOrg
                            ? null
                            : () async {
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
                    ),
                  ],
                )
              else
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
                      onPressed: !canEditOrg
                          ? null
                          : () async {
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
              Text(
                'График работы',
                textAlign: d && !embed ? TextAlign.center : TextAlign.start,
                style: d
                    ? DesktopDesignSystem.sectionTitle.copyWith(fontSize: embed ? 15 : 17)
                    : const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                'Время с и до по каждому дню; у клиентов показывается сегодня и полный график',
                textAlign: d && !embed ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: d ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: d ? 12 : 10),
              ...List.generate(
                7,
                (i) => _buildWeekDayRow(
                  context,
                  i: i,
                  canEdit: canEditOrg,
                  desktop: d,
                ),
              ),
              _buildWorkingHoursExceptionsSection(context, canEditOrg, d, embed),
              Consumer(
                builder: (context, ref, _) {
                  final st = ref.watch(settingsRepositoryProvider);
                  return _clientFacingCardSection(
                    ref: ref,
                    d: d,
                    embed: embed,
                    canEdit: canEditOrg,
                    settings: st,
                  );
                },
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
                      onPressed: () => createOrganizationWithOptionalSoloOnboarding(context, ref, desktopChrome: d),
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Добавить организацию'),
                    ),
                  );
                },
              ),
            ];
          final listView = ListView(
              padding: d
                  ? (embed
                      ? const EdgeInsets.fromLTRB(16, 8, 16, 28)
                      : const EdgeInsets.fromLTRB(24, 20, 24, 28))
                  : const EdgeInsets.all(16),
              children: listChildren,
            );
          return RefreshIndicator(
            color: d ? AppColorsDesktop.primary : AppColors.primary,
            onRefresh: () async {
              final orgId = ref.read(authProvider).user?.effectiveOrganizationId;
              await ref.read(organizationRepositoryProvider.notifier).load(orgId);
            },
            child: d
                ? (embed
                    ? listView
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColorsDesktop.surface,
                                borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
                                border: Border.all(color: AppColorsDesktop.border),
                                boxShadow: DesktopDesignSystem.shadowCard,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
                                child: listView,
                              ),
                            ),
                          ),
                        ),
                      ))
                : listView,
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: d ? AppColorsDesktop.primary : AppColors.primary,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'Ошибка: $e',
            style: TextStyle(color: d ? AppColorsDesktop.error : AppColors.error),
          ),
        ),
    );

    if (embed) {
      return themeDesktopLight(child: body);
    }

    final scaffold = Scaffold(
      backgroundColor: d ? AppColorsDesktop.background : AppColors.background,
      appBar: AppBar(
        centerTitle: d,
        title: Text(d ? 'Данные организации' : 'Организация'),
        backgroundColor: d ? AppColorsDesktop.surface : null,
        foregroundColor: d ? AppColorsDesktop.textPrimary : null,
        surfaceTintColor: d ? Colors.transparent : null,
        elevation: d ? 0 : null,
        actions: [
          TextButton(
            onPressed: !canEditOrg ||
                    orgAsync.valueOrNull == null ||
                    orgIdForSave == null ||
                    orgIdForSave.isEmpty
                ? null
                : () => _saveOrganizationData(context),
            child: Text(
              'Сохранить',
              style: TextStyle(
                color: d ? AppColorsDesktop.primary : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
    if (d) return themeDesktopLight(child: scaffold);
    return scaffold;
  }
}
