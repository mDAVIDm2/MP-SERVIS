import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/constants/labels_ru.dart';
import '../../../core/theme/app_colors.dart';

class OrganizationDetailScreen extends ConsumerStatefulWidget {
  const OrganizationDetailScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<OrganizationDetailScreen> createState() => _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState extends ConsumerState<OrganizationDetailScreen> {
  bool _editing = false;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _workingHoursController;
  late TextEditingController _timezoneController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _workingHoursController = TextEditingController();
    _timezoneController = TextEditingController();
    _latController = TextEditingController();
    _lonController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _workingHoursController.dispose();
    _timezoneController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _fillControllers(Map<String, dynamic> org) {
    _nameController.text = org['name'] as String? ?? '';
    _addressController.text = org['address'] as String? ?? '';
    _phoneController.text = org['phone'] as String? ?? '';
    _workingHoursController.text = org['working_hours'] as String? ?? '';
    _timezoneController.text = org['timezone'] as String? ?? 'Europe/Moscow';
    final lat = org['latitude'];
    final lon = org['longitude'];
    _latController.text = lat != null ? lat.toString() : '';
    _lonController.text = lon != null ? lon.toString() : '';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(organizationDetailProvider(widget.organizationId));
    final orgName = async.valueOrNull?['name'] as String?;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(orgName != null && orgName.isNotEmpty ? orgName : 'Организация', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/organizations'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(organizationDetailProvider(widget.organizationId));
            },
            tooltip: 'Обновить',
          ),
          if (!_editing)
            TextButton.icon(
              onPressed: () {
                final org = async.valueOrNull;
                if (org != null) {
                  _fillControllers(org);
                  setState(() => _editing = true);
                }
              },
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Редактировать'),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Отмена')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _save(context),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
        ],
      ),
      body: async.when(
        data: (org) {
          if (org == null) {
            return const Center(child: Text('Организация не найдена', style: TextStyle(color: AppColors.textSecondary)));
          }
          if (_editing) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _EditForm(
                nameController: _nameController,
                addressController: _addressController,
                phoneController: _phoneController,
                workingHoursController: _workingHoursController,
                timezoneController: _timezoneController,
                latController: _latController,
                lonController: _lonController,
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard(org: org),
                const SizedBox(height: 20),
                _SubscriptionCard(org: org, organizationId: widget.organizationId),
                const SizedBox(height: 20),
                _StaffCard(orgId: widget.organizationId, staff: org['staff']),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final workingHours = _workingHoursController.text.trim();
    final timezone = _timezoneController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    final ok = await ref.read(internalApiProvider).updateOrganization(widget.organizationId, {
      'name': name.isEmpty ? null : name,
      'address': address.isEmpty ? null : address,
      'phone': phone.isEmpty ? null : phone,
      'working_hours': workingHours.isEmpty ? null : workingHours,
      'timezone': timezone.isEmpty ? 'Europe/Moscow' : timezone,
      'latitude': lat,
      'longitude': lon,
    });
    if (context.mounted) {
      ref.invalidate(organizationDetailProvider(widget.organizationId));
      ref.invalidate(organizationsProvider);
      setState(() => _editing = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Изменения сохранены')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сохранения'), backgroundColor: AppColors.danger));
      }
    }
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.nameController,
    required this.addressController,
    required this.phoneController,
    required this.workingHoursController,
    required this.timezoneController,
    required this.latController,
    required this.lonController,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController workingHoursController;
  final TextEditingController timezoneController;
  final TextEditingController latController;
  final TextEditingController lonController;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Адрес', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: workingHoursController,
              decoration: const InputDecoration(
                labelText: 'Режим работы',
                hintText: 'Пн–Пт 9:00–19:00, Сб 10:00–16:00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timezoneController,
              decoration: const InputDecoration(
                labelText: 'Часовой пояс (IANA)',
                hintText: 'Europe/Moscow',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: const InputDecoration(labelText: 'Широта', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: lonController,
                    decoration: const InputDecoration(labelText: 'Долгота', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.org});

  final Map<String, dynamic> org;

  @override
  Widget build(BuildContext context) {
    final name = org['name'] as String? ?? '—';
    final address = org['address'] as String? ?? '—';
    final phone = org['phone'] as String? ?? '—';
    final workingHours = org['working_hours'] as String? ?? '—';
    final timezone = org['timezone'] as String? ?? '—';
    final lat = org['latitude'];
    final lon = org['longitude'];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.business_rounded, size: 32, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _RowLabel(label: 'Адрес', value: address),
            _RowLabel(label: 'Телефон', value: phone),
            _RowLabel(label: 'Режим работы', value: workingHours),
            _RowLabel(label: 'Часовой пояс', value: timezone),
            if (lat != null || lon != null)
              _RowLabel(label: 'Координаты', value: '${lat ?? "—"}, ${lon ?? "—"}'),
          ],
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

/// Эффективные лимиты в API: snake_case (актуальный бэкенд) или camelCase (старый ответ).
dynamic _subscriptionUsageLimit(Map<String, dynamic> limits, String snake, String camel) {
  if (limits.containsKey(snake)) return limits[snake];
  return limits[camel];
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.org, required this.organizationId});

  final Map<String, dynamic> org;
  final String organizationId;

  static String _lim(dynamic v) {
    if (v == null) return '∞';
    if (v is num) return v.toString();
    return '$v';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = org['subscription'];
    if (sub == null || sub is! Map) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Нет данных о подписке', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final isActive = sub['is_active'] == true;
    final status = sub['status'] as String? ?? '—';
    final start = sub['start_date'] as String? ?? '—';
    final end = sub['end_date'] as String? ?? '—';
    final planKey = sub['plan_key'] as String? ?? '—';
    final hasOverride = sub['limits_override'] != null && (sub['limits_override'] is Map) && (sub['limits_override'] as Map).isNotEmpty;

    final usage = org['subscription_usage'];
    Map<String, dynamic>? lim;
    Map<String, dynamic>? planLim;
    dynamic ordUsed;
    dynamic staffActive;
    if (usage is Map<String, dynamic>) {
      lim = usage['limits'] is Map ? Map<String, dynamic>.from(usage['limits'] as Map) : null;
      planLim = usage['plan_limits'] is Map ? Map<String, dynamic>.from(usage['plan_limits'] as Map) : null;
      ordUsed = usage['confirmed_orders_this_month'];
      staffActive = usage['active_staff'];
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Подписка', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                if (hasOverride)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: const Text('Свои лимиты', style: TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFE0E7FF),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => _LimitsOverrideDialog(
                        organizationId: organizationId,
                        planKey: planKey,
                        subscriptionUsage: usage is Map<String, dynamic> ? usage : null,
                      ),
                    );
                    if (context.mounted) {
                      ref.invalidate(organizationDetailProvider(organizationId));
                      ref.invalidate(subscriptionsProvider);
                    }
                  },
                  child: const Text('Лимиты'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RowLabel(label: 'Тариф', value: planKey),
            _RowLabel(label: 'Статус', value: LabelsRu.subscriptionStatus(status)),
            _RowLabel(label: 'Активна', value: isActive ? 'Да' : 'Нет'),
            _RowLabel(label: 'Начало', value: start.length > 10 ? start.substring(0, 10) : start),
            _RowLabel(label: 'Окончание', value: end.length > 10 ? end.substring(0, 10) : end),
            if (lim != null) ...[
              const Divider(height: 24),
              Text(
                'Эффективные лимиты (тариф + переопределение)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _RowLabel(
                label: 'Сотрудники (акт.)',
                value: '${_lim(staffActive)} / ${_lim(_subscriptionUsageLimit(lim, 'max_active_staff', 'maxActiveStaff'))}',
              ),
              _RowLabel(
                label: 'Записей / мес (исп.)',
                value:
                    '${_lim(ordUsed)} / ${_lim(_subscriptionUsageLimit(lim, 'max_confirmed_orders_per_month', 'maxConfirmedOrdersPerMonth'))}',
              ),
              _RowLabel(
                label: 'Фото на заказ',
                value: _lim(_subscriptionUsageLimit(lim, 'max_order_media_attachments', 'maxOrderMediaAttachments')),
              ),
              _RowLabel(
                label: 'Фото в сообщении чата',
                value: _lim(_subscriptionUsageLimit(lim, 'max_chat_images_per_message', 'maxChatImagesPerMessage')),
              ),
              if (planLim != null) ...[
                const SizedBox(height: 8),
                Text(
                  'База тарифа',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.9)),
                ),
                _RowLabel(
                  label: 'Сотр. / заказы / фото',
                  value:
                      '${_lim(_subscriptionUsageLimit(planLim, 'max_active_staff', 'maxActiveStaff'))} · ${_lim(_subscriptionUsageLimit(planLim, 'max_confirmed_orders_per_month', 'maxConfirmedOrdersPerMonth'))} · ${_lim(_subscriptionUsageLimit(planLim, 'max_order_media_attachments', 'maxOrderMediaAttachments'))} / ${_lim(_subscriptionUsageLimit(planLim, 'max_chat_images_per_message', 'maxChatImagesPerMessage'))}',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LimitsOverrideDialog extends ConsumerStatefulWidget {
  const _LimitsOverrideDialog({
    required this.organizationId,
    required this.planKey,
    this.subscriptionUsage,
  });

  final String organizationId;
  final String planKey;
  final Map<String, dynamic>? subscriptionUsage;

  @override
  ConsumerState<_LimitsOverrideDialog> createState() => _LimitsOverrideDialogState();
}

class _LimitsOverrideDialogState extends ConsumerState<_LimitsOverrideDialog> {
  late final TextEditingController _staff;
  late final TextEditingController _orders;
  late final TextEditingController _orderPhotos;
  late final TextEditingController _chatImages;
  bool _resetStaff = false;
  bool _resetOrders = false;
  bool _resetOrderPhotos = false;
  bool _resetChatImages = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _staff = TextEditingController();
    _orders = TextEditingController();
    _orderPhotos = TextEditingController();
    _chatImages = TextEditingController();
  }

  @override
  void dispose() {
    _staff.dispose();
    _orders.dispose();
    _orderPhotos.dispose();
    _chatImages.dispose();
    super.dispose();
  }

  Future<void> _save({required bool clearAll}) async {
    setState(() => _saving = true);
    try {
      final api = ref.read(internalApiProvider);
      if (clearAll) {
        final res = await api.patchOrganizationSubscription(widget.organizationId, {'limits_override': null});
        if (!mounted) return;
        if (res != null && res['ok'] == true) {
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось сбросить')));
        }
        return;
      }
      final patch = <String, dynamic>{};
      void put(String snake, TextEditingController c, bool reset) {
        if (reset) {
          patch[snake] = null;
          return;
        }
        final t = c.text.trim();
        if (t.isEmpty) return;
        final n = int.tryParse(t);
        if (n == null || n < 0) {
          throw Exception('Введите целое число ≥ 0 для «$snake» или оставьте пустым.');
        }
        patch[snake] = n;
      }
      put('max_active_staff', _staff, _resetStaff);
      put('max_confirmed_orders_per_month', _orders, _resetOrders);
      put('max_order_media_attachments', _orderPhotos, _resetOrderPhotos);
      put('max_chat_images_per_message', _chatImages, _resetChatImages);
      if (patch.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final res = await api.patchOrganizationSubscription(widget.organizationId, {'limits_override': patch});
      if (!mounted) return;
      if (res != null && res['ok'] == true) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не сохранено')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.subscriptionUsage;
    final lim = u != null && u['limits'] is Map ? Map<String, dynamic>.from(u['limits'] as Map) : <String, dynamic>{};
    String ev(Map<String, dynamic> m, String snake, String camel) {
      final v = _subscriptionUsageLimit(m, snake, camel);
      return v == null ? '∞' : '$v';
    }

    final hint =
        'Сейчас (эффективно): сотр. ${ev(lim, 'max_active_staff', 'maxActiveStaff')}, '
        'зак./мес ${ev(lim, 'max_confirmed_orders_per_month', 'maxConfirmedOrdersPerMonth')}, '
        'влож. к заказу ${ev(lim, 'max_order_media_attachments', 'maxOrderMediaAttachments')}, '
        'фото в сообщ. ${ev(lim, 'max_chat_images_per_message', 'maxChatImagesPerMessage')}. '
        'Пустое поле — не менять. «К тарифу» — убрать своё значение и взять лимит тарифа. '
        'Число — индивидуальный лимит для организации (заменяет значение тарифа по этому полю).';

    return AlertDialog(
      title: Text('Лимиты · ${widget.planKey}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              _LimitField(
                label: 'Макс. активных сотрудников',
                controller: _staff,
                reset: _resetStaff,
                onResetChanged: (v) => setState(() => _resetStaff = v),
              ),
              _LimitField(
                label: 'Макс. подтверждённых записей / мес',
                controller: _orders,
                reset: _resetOrders,
                onResetChanged: (v) => setState(() => _resetOrders = v),
              ),
              _LimitField(
                label: 'Макс. вложений к заказу',
                controller: _orderPhotos,
                reset: _resetOrderPhotos,
                onResetChanged: (v) => setState(() => _resetOrderPhotos = v),
              ),
              _LimitField(
                label: 'Макс. фото в сообщении чата',
                controller: _chatImages,
                reset: _resetChatImages,
                onResetChanged: (v) => setState(() => _resetChatImages = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _saving ? null : () => _save(clearAll: true),
          child: const Text('Сбросить все', style: TextStyle(color: AppColors.danger)),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(clearAll: false),
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _LimitField extends StatelessWidget {
  const _LimitField({
    required this.label,
    required this.controller,
    required this.reset,
    required this.onResetChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool reset;
  final void Function(bool) onResetChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !reset,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'не менять',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('К тарифу', style: TextStyle(fontSize: 11)),
                selected: reset,
                onSelected: onResetChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.orgId, required this.staff});

  final String orgId;
  final dynamic staff;

  @override
  Widget build(BuildContext context) {
    final list = staff is List ? staff as List<dynamic> : <dynamic>[];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Сотрудники', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Chip(label: Text('${list.length}', style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Text('Нет сотрудников', style: TextStyle(color: AppColors.textSecondary))
            else
              ...list.map<Widget>((s) {
                final m = s is Map ? s as Map<String, dynamic> : <String, dynamic>{};
                final name = m['name'] as String? ?? '—';
                final role = LabelsRu.staffRole(m['role'] as String?);
                final phone = m['phone'] as String? ?? '';
                final active = m['is_active'] != false;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(name, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$role${phone.isNotEmpty ? ' · $phone' : ''}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                  trailing: Chip(
                    label: Text(active ? 'Активен' : 'Неактивен', style: const TextStyle(fontSize: 11)),
                    backgroundColor: active ? const Color(0xFFDCFCE7) : AppColors.border,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
