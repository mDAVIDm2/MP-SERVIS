import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/app_lock_provider.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/settings/locale_provider.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/main_shell.dart';

bool _isPhoneValidForRegister(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return false;
  if (d.length == 11 && d.startsWith('8')) return true;
  if (d.length == 11 && d.startsWith('7')) return true;
  if (d.length == 10) return true;
  return false;
}

// ─── Welcome Screen ───
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 24),
                // Logo
                Container(
                  width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 32, spreadRadius: 4),
                  ],
                ),
                child: const Center(child: Text('AH', style: TextStyle(
                  fontSize: 48, fontWeight: FontWeight.w800, color: Color(0xFF0D0D0D),
                  letterSpacing: -1,
                ))),
              ),
              const SizedBox(height: 32),
              const Text('AutoHub', style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                letterSpacing: -0.5,
              )),
              const SizedBox(height: 8),
              const Text('Управляйте автосервисом\nв одном приложении', style: TextStyle(
                fontSize: 16, color: AppColors.textSecondary, height: 1.4,
              ), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              // Features
              const _FeatureRow(icon: Icons.directions_car_rounded, text: 'Гараж с историей обслуживания'),
              const SizedBox(height: 16),
              const _FeatureRow(icon: Icons.search_rounded, text: 'Поиск проверенных автосервисов'),
              const SizedBox(height: 16),
              const _FeatureRow(icon: Icons.chat_rounded, text: 'Чат с мастером в реальном времени'),
              const SizedBox(height: 16),
              const _FeatureRow(icon: Icons.notifications_rounded, text: 'Напоминания о ТО'),
              const SizedBox(height: 32),
              // CTA
              GoldButton(
                text: 'Начать',
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmailInputScreen())),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const MainShell())),
                child: const Text('Пропустить', style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary,
                )),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(
          fontSize: 15, color: AppColors.textPrimary,
        ))),
      ],
    );
  }
}

// ─── Email (вход по коду на почту) ───
class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isValid => _emailRe.hasMatch(_controller.text.trim());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_isValid || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final email = _controller.text.trim().toLowerCase();
    final result = await ref.read(authProvider.notifier).sendLoginCode(email);
    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (send) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SmsCodeScreen(
                  email: email,
                  challengeId: send.challengeId,
                  resendAfterSec: send.resendAfter,
                ),
          ),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('Ваш email', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 8),
            const Text(
              'Отправим одноразовый код на почту. Телефон при желании можно указать на следующем шаге — он сохранится без подтверждения по SMS.',
              style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: TextStyle(color: AppColors.textPlaceholder, fontSize: 18),
                  border: InputBorder.none,
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Spacer(),
            GoldButton(
              text: _loading ? 'Отправка...' : 'Получить код',
              onPressed: _isValid && !_loading ? _sendCode : null,
            ),
            const SizedBox(height: 16),
            const Center(child: Text(
              'Нажимая «Получить код», вы принимаете\nпользовательское соглашение',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Код из письма ───
class SmsCodeScreen extends ConsumerStatefulWidget {
  final String email;
  final String challengeId;
  final int resendAfterSec;

  const SmsCodeScreen({
    super.key,
    required this.email,
    required this.challengeId,
    this.resendAfterSec = 60,
  });

  @override
  ConsumerState<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends ConsumerState<SmsCodeScreen> {
  static const int _digits = 6;

  final List<TextEditingController> _controllers = List.generate(_digits, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_digits, (_) => FocusNode());
  final _phoneOpt = TextEditingController();
  final _nameOpt = TextEditingController();
  bool _isVerifying = false;
  bool _resendBusy = false;
  String? _profileError;
  late String _challengeId;
  late int _resendSeconds;
  Timer? _resendTimer;

  String get _code => _controllers.map((c) => c.text).join();

  bool get _profileComplete =>
      _nameOpt.text.trim().length >= 2 && _isPhoneValidForRegister(_phoneOpt.text);

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _startTimer(initial: widget.resendAfterSec.clamp(1, 600), rebuild: false);
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneOpt.dispose();
    _nameOpt.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer({required int initial, bool rebuild = true}) {
    _resendTimer?.cancel();
    _resendSeconds = initial;
    if (rebuild && mounted) setState(() {});
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (_isVerifying || _code.length != _digits) return;
    FocusScope.of(context).unfocus();
    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await ref.read(authProvider.notifier).verifyEmailCode(
            widget.email,
            _challengeId,
            _code,
            phoneUnverified: _phoneOpt.text.trim().isEmpty ? null : _phoneOpt.text.trim(),
            name: _nameOpt.text.trim().isEmpty ? null : _nameOpt.text.trim(),
          );
      if (!mounted) return;
      setState(() => _isVerifying = false);
      result.when(
        success: (user) {
          if (!mounted) return;
          // После установки токена в ApiClient — принудительно перезапросить заказы и чаты (иначе может остаться 401).
          ref.invalidate(ordersProvider);
          ref.invalidate(chatsProvider);
          // Дальнейший сценарий (PIN → имя → MainShell) ведёт [PostAuthShell] после смены MaterialApp.
        },
        failure: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Нет связи с сервером. Проверьте Wi‑Fi и что бэкенд запущен (порт 3000).',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resend() async {
    if (_resendBusy || _resendSeconds > 0) return;
    setState(() => _resendBusy = true);
    final r = await ref.read(authProvider.notifier).sendLoginCode(widget.email);
    if (!mounted) return;
    setState(() => _resendBusy = false);
    r.when(
      success: (send) {
        setState(() => _challengeId = send.challengeId);
        for (final c in _controllers) c.clear();
        _startTimer(initial: send.resendAfter.clamp(1, 600), rebuild: true);
        _focusNodes[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Код отправлен повторно'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _digits - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_code.length == _digits) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isVerifying || _code.length != _digits) return;
        if (!_profileComplete) {
          setState(() => _profileError = 'Сначала укажите имя и телефон');
          return;
        }
        _verify();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(32, 0, 32, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('Код из письма', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 8),
            Text(
              'Отправлен на ${widget.email}. Имя и телефон обязательны для нового аккаунта. Затем введите 6 цифр из письма.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Имя *', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameOpt,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) {
                setState(() {
                  _profileError = null;
                });
              },
              decoration: InputDecoration(
                hintText: 'Как к вам обращаться',
                hintStyle: TextStyle(color: AppColors.textPlaceholder.withValues(alpha: 0.7)),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Телефон * (без SMS-подтверждения)', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneOpt,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) {
                setState(() {
                  _profileError = null;
                });
              },
              decoration: InputDecoration(
                hintText: '+7 … или 8 …',
                hintStyle: TextStyle(color: AppColors.textPlaceholder.withValues(alpha: 0.7)),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            if (_profileError != null) ...[
              const SizedBox(height: 10),
              Text(_profileError!, style: const TextStyle(fontSize: 13, color: AppColors.error, height: 1.3)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_digits, (i) => Container(
                width: 47,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _focusNodes[i].hasFocus ? AppColors.primary : AppColors.border,
                    width: _focusNodes[i].hasFocus ? 2 : 1,
                  ),
                ),
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '', border: InputBorder.none,
                  ),
                  onChanged: (v) => _onDigitChanged(i, v),
                ),
              )),
            ),
            const SizedBox(height: 24),
            GoldButton(
              text: _isVerifying ? 'Проверка...' : 'Подтвердить',
              onPressed: (_isVerifying || _code.length != _digits) ? null : () => _verify(),
            ),
            const SizedBox(height: 16),
            if (_isVerifying)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Повторно через $_resendSeconds с',
                        style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
                      )
                    : TextButton(
                        onPressed: _resendBusy ? null : _resend,
                        child: _resendBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Text('Отправить повторно'),
                      ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Имя и телефон до PIN, если после входа они пустые в профиле ───
class MandatoryProfileBasicsScreen extends ConsumerStatefulWidget {
  const MandatoryProfileBasicsScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<MandatoryProfileBasicsScreen> createState() => _MandatoryProfileBasicsScreenState();
}

class _MandatoryProfileBasicsScreenState extends ConsumerState<MandatoryProfileBasicsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final u = ref.read(authProvider).user;
    if (u != null) {
      if (u.name.trim().isNotEmpty) _name.text = u.name;
      if (u.phone != null && u.phone!.trim().isNotEmpty) _phone.text = u.phone!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _ok => _name.text.trim().length >= 2 && _isPhoneValidForRegister(_phone.text);

  Future<void> _submit() async {
    if (!_ok || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.patch(
        ApiEndpoints.profile,
        data: {'name': _name.text.trim(), 'phone': _phone.text.trim()},
      );
      final map = res.data;
      if (map is Map<String, dynamic>) {
        ref.read(authProvider.notifier).applyServerProfileFields(
              name: map['name'] as String?,
              phone: map['phone'] as String?,
            );
      }
      if (!mounted) return;
      widget.onComplete();
    } on DioException catch (e) {
      String msg = 'Не удалось сохранить. Проверьте данные.';
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        msg = data['message'] as String;
      }
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(32, 8, 32, 32 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Заполните профиль',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Имя и телефон нужны для записи в сервисы и связи с мастером.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 24),
            const Text('Имя *', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'Как к вам обращаться',
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Телефон *', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 6),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: '+7 …',
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error, height: 1.3)),
            ],
            const SizedBox(height: 28),
            GoldButton(
              text: _busy ? 'Сохранение...' : 'Продолжить',
              onPressed: (_ok && !_busy) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Обязательный PIN после первого входа по коду ───
class MandatoryPinSetupScreen extends ConsumerStatefulWidget {
  const MandatoryPinSetupScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  ConsumerState<MandatoryPinSetupScreen> createState() => _MandatoryPinSetupScreenState();
}

class _MandatoryPinSetupScreenState extends ConsumerState<MandatoryPinSetupScreen> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    return a.length >= 4 && a.length <= 8 && a == b && !_busy;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final pin = _pin1.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(pinVaultProvider).setPin(pin);
      await ref.read(securitySettingsProvider).setPinEnabled(true);
      final la = ref.read(localAuthProvider);
      if (await la.canCheckBiometrics && mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            title: const Text('Биометрия', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'Включить разблокировку по отпечатку или Face ID?',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Не сейчас')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF0D0D0D),
                ),
                child: const Text('Включить'),
              ),
            ],
          ),
        );
        if (enable == true && mounted) {
          try {
            final ok = await la.authenticate(
              localizedReason: 'Подтвердите для включения биометрии',
              options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
            );
            if (ok && mounted) {
              await ref.read(securitySettingsProvider).setBiometricEnabled(true);
            }
          } on PlatformException {
            /* ignore */
          }
        }
      }
      await widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(32, 8, 32, 32 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Задайте PIN-код',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Он нужен для входа в приложение на этом устройстве. Сервер его не знает — только вы.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            const Text('PIN (4–8 цифр)', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _pinField(_pin1, autofocus: true),
            const SizedBox(height: 16),
            const Text('Повторите PIN', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _pinField(_pin2),
            const SizedBox(height: 32),
            GoldButton(
              text: _busy ? 'Сохранение...' : 'Продолжить',
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinField(TextEditingController c, {bool autofocus = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: c,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 8,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 4,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintText: '••••',
          hintStyle: TextStyle(color: AppColors.textPlaceholder),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}

// ─── Name Input Screen ───
class NameInputScreen extends ConsumerStatefulWidget {
  const NameInputScreen({super.key, this.onFinished});

  /// Если задан — после сохранения имени не делаем push MainShell (используется из [PostAuthShell]).
  final VoidCallback? onFinished;

  @override
  ConsumerState<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends ConsumerState<NameInputScreen> {
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isValid => _nameController.text.trim().isNotEmpty && !_isSubmitting;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    await ref.read(authProvider.notifier).updateProfile(
      name: name,
      surname: surname.isEmpty ? null : surname,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    final locale = ref.read(localeProvider) ?? const Locale('ru');
    final l10n = AppL10n(locale);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => L10nScope(l10n: l10n, child: const MainShell()),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(32, 24, 32, 32 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Как вас зовут?', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 8),
            const Text('Имя будет видно мастерам в автосервисах', style: TextStyle(
              fontSize: 14, color: AppColors.textSecondary,
            )),
            const SizedBox(height: 32),
            _buildField('Имя *', _nameController, autofocus: true),
            const SizedBox(height: 16),
            _buildField('Фамилия', _surnameController),
            const SizedBox(height: 32),
            GoldButton(
              text: _isSubmitting ? '...' : 'Готово',
              onPressed: _isValid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool autofocus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 18, color: AppColors.textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
