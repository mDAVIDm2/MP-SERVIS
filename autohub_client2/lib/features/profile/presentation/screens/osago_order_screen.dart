import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/partner/partner_app_config.dart';
import '../../../../core/partner/partner_orders_api.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/car_model.dart';

final partnerOrdersApiProvider = Provider<PartnerOrdersApi>((ref) => PartnerOrdersApi());

/// Оформление ОСАГО через партнёрский API: ФИО, телефон, email, госномер (редактируемые).
class OsagoOrderScreen extends ConsumerStatefulWidget {
  const OsagoOrderScreen({super.key});

  @override
  ConsumerState<OsagoOrderScreen> createState() => _OsagoOrderScreenState();
}

class _OsagoOrderScreenState extends ConsumerState<OsagoOrderScreen> {
  late final TextEditingController _fioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _plateController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final cars = ref.read(carsProvider).valueOrNull ?? [];
    final selId = ref.read(selectedCarIdProvider);
    Car? car;
    if (selId != null) {
      for (final c in cars) {
        if (c.id == selId) {
          car = c;
          break;
        }
      }
    }
    car ??= cars.isNotEmpty ? cars.first : null;

    final name = user?.name.trim() ?? '';
    final surname = user?.surname?.trim() ?? '';
    final fio = [name, surname].where((s) => s.isNotEmpty).join(' ').trim();

    _fioController = TextEditingController(text: fio);
    _phoneController = TextEditingController(text: _normalizePhoneDisplay(user?.phone));
    _emailController = TextEditingController(text: user?.email?.trim() ?? '');
    _plateController = TextEditingController(text: car?.plateNumber?.trim() ?? '');
  }

  static String _normalizePhoneDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('7')) {
      return '+7 (${d.substring(1, 4)}) ${d.substring(4, 7)}-${d.substring(7, 9)}-${d.substring(9, 11)}';
    }
    if (d.length == 10) {
      return '+7 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6, 8)}-${d.substring(8, 10)}';
    }
    return raw.trim();
  }

  @override
  void dispose() {
    _fioController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  String _digitsPhone(String s) => s.replaceAll(RegExp(r'\D'), '');

  bool _looksLikeEmail(String s) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());
  }

  Future<void> _submit() async {
    final fio = _fioController.text.trim();
    final phone = _digitsPhone(_phoneController.text);
    final email = _emailController.text.trim();
    final plate = _plateController.text.trim().replaceAll(RegExp(r'\s'), '');

    if (fio.length < 3) {
      _toast('Введите ФИО полностью');
      return;
    }
    if (phone.length < 10) {
      _toast('Введите корректный номер телефона');
      return;
    }
    if (!_looksLikeEmail(email)) {
      _toast('Введите корректный email');
      return;
    }
    if (plate.length < 4) {
      _toast('Введите госномер автомобиля');
      return;
    }

    if (!PartnerAppConfig.canSubmitOsago) {
      _toast(
        'Партнёрский API не настроен: задайте при сборке '
        'PARTNER_API_TOKEN и PARTNER_OSAGO_PRODUCT_ID (см. PartnerAppConfig).',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(partnerOrdersApiProvider);
      var phoneNorm = phone;
      if (phoneNorm.length == 11 && phoneNorm.startsWith('8')) {
        phoneNorm = '7${phoneNorm.substring(1)}';
      }
      final String phoneE164;
      if (phoneNorm.length == 11 && phoneNorm.startsWith('7')) {
        phoneE164 = '+$phoneNorm';
      } else if (phoneNorm.length == 10) {
        phoneE164 = '+7$phoneNorm';
      } else {
        phoneE164 = '+$phoneNorm';
      }

      final body = <String, dynamic>{
        'products': [PartnerAppConfig.osagoProductId],
        PartnerAppConfig.fieldFio: fio,
        PartnerAppConfig.fieldPhone: phoneE164,
        PartnerAppConfig.fieldEmail: email,
        PartnerAppConfig.fieldPlate: plate,
      };

      final res = await api.createOrder(body);
      if (!mounted) return;
      await _showResultDialog(context, res);
    } catch (e) {
      if (!mounted) return;
      _toast(ref.read(partnerOrdersApiProvider).describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.palette.error),
    );
  }

  Future<void> _showResultDialog(BuildContext context, Map<String, dynamic> res) async {
    String? trackingUrl;
    String? state;
    final data = res['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      final m = Map<String, dynamic>.from(data.first as Map);
      trackingUrl = m['tracking_url'] as String?;
      state = m['state'] as String?;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text(
          'Заявка отправлена',
          style: TextStyle(color: context.palette.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state != null)
                Text('Статус: $state', style: TextStyle(color: context.palette.textSecondary, fontSize: 14)),
              if (trackingUrl != null && trackingUrl.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  'Для продолжения оформления перейдите по ссылке партнёра:',
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
                ),
                SizedBox(height: 8),
                SelectableText(
                  trackingUrl,
                  style: TextStyle(color: context.palette.primary, fontSize: 13),
                ),
              ] else
                Text(
                  'Заявка принята. При необходимости статус можно уточнить у поддержки.',
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) Navigator.of(context).pop();
            },
            child: Text('Закрыть', style: TextStyle(color: context.palette.textSecondary)),
          ),
          if (trackingUrl != null && trackingUrl.isNotEmpty)
            FilledButton(
              onPressed: () async {
                final rawUrl = trackingUrl!;
                final u = Uri.tryParse(rawUrl);
                if (u != null && await canLaunchUrl(u)) {
                  await launchUrl(u, mode: LaunchMode.externalApplication);
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.palette.primary,
                foregroundColor: context.palette.onAccent,
              ),
              child: Text('Открыть ссылку'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfgNote = !PartnerAppConfig.canSubmitOsago;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        title: Text('Оформить ОСАГО', style: TextStyle(color: context.palette.textPrimary)),
        iconTheme: IconThemeData(color: context.palette.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (cfgNote)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.warning.withValues(alpha: 0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Для отправки заявок укажите в сборке приложения PARTNER_API_TOKEN и '
                    'PARTNER_OSAGO_PRODUCT_ID (числовой id продукта ОСАГО в кабинете партнёра).',
                    style: TextStyle(fontSize: 13, color: context.palette.textPrimary, height: 1.35),
                  ),
                ),
              ),
            ),
          Text(
            'Данные подставлены из профиля и выбранного в гараже автомобиля. Проверьте и при необходимости измените.',
            style: TextStyle(fontSize: 14, color: context.palette.textSecondary, height: 1.4),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _fioController,
            decoration: InputDecoration(
              labelText: 'ФИО',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: context.palette.textSecondary),
            ),
            style: TextStyle(color: context.palette.textPrimary),
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Телефон',
              hintText: '+7 …',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: context.palette.textSecondary),
            ),
            style: TextStyle(color: context.palette.textPrimary),
          ),
          SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: context.palette.textSecondary),
            ),
            style: TextStyle(color: context.palette.textPrimary),
          ),
          SizedBox(height: 14),
          TextField(
            controller: _plateController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Госномер',
              hintText: 'А123ВС 77',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: context.palette.textSecondary),
            ),
            style: TextStyle(color: context.palette.textPrimary),
          ),
          SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.onAccent),
                  )
                : Icon(Icons.send_rounded, size: 22),
            label: Text(_submitting ? 'Отправка…' : 'Отправить заявку'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.primary,
              foregroundColor: context.palette.onAccent,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
