import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/russian_mobile_phone.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/theme_mode_provider.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/main_shell.dart';

bool _isPhoneValidForRegister(String raw) => RussianMobilePhone.isComplete(raw);

// ─── Welcome Screen ───
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
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
                SizedBox(height: 24),
                // Logo
                Container(
                  width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: context.palette.primaryGradient,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: context.palette.primary.withValues(alpha: 0.3),
                      blurRadius: 32, spreadRadius: 4),
                  ],
                ),
                child: Center(
                  child: Text(
                    'AH',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: context.palette.onAccent,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text('MP-Servis', style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
                letterSpacing: -0.5,
              )),
              SizedBox(height: 8),
              Text('Управляйте автосервисом\nв одном приложении', style: TextStyle(
                fontSize: 16, color: context.palette.textSecondary, height: 1.4,
              ), textAlign: TextAlign.center),
              SizedBox(height: 32),
              // Features
              const _FeatureRow(icon: Icons.directions_car_rounded, text: 'Гараж с историей обслуживания'),
              SizedBox(height: 16),
              const _FeatureRow(icon: Icons.search_rounded, text: 'Поиск проверенных автосервисов'),
              SizedBox(height: 16),
              const _FeatureRow(icon: Icons.chat_rounded, text: 'Чат с мастером в реальном времени'),
              SizedBox(height: 16),
              const _FeatureRow(icon: Icons.notifications_rounded, text: 'Напоминания о ТО'),
              SizedBox(height: 32),
              // CTA
              GoldButton(
                text: 'Войти или зарегистрироваться',
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmailInputScreen())),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const MainShell())),
                child: Text('Пропустить', style: TextStyle(
                  fontSize: 14, color: context.palette.textSecondary,
                )),
              ),
              SizedBox(height: 24),
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
            color: context.palette.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.palette.primary, size: 22),
        ),
        SizedBox(width: 16),
        Expanded(child: Text(text, style: TextStyle(
          fontSize: 15, color: context.palette.textPrimary,
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
        if (send.accountExists) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmsCodeScreen(
                email: email,
                challengeId: send.challengeId,
                resendAfterSec: send.resendAfter,
                accountExists: true,
                debugOtp: send.debugOtp,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterProfileScreen(
                email: email,
                challengeId: send.challengeId,
                resendAfterSec: send.resendAfter,
                debugOtp: send.debugOtp,
              ),
            ),
          );
        }
      },
      failure: (e) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: context.palette.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(backgroundColor: context.palette.background, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            Text('Ваш email', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
            )),
            SizedBox(height: 8),
            Text(
              'Если адрес уже зарегистрирован — после кода вы войдёте в аккаунт. Для нового аккаунта сначала укажите имя и телефон, затем введите код из письма — учётная запись создаётся только после подтверждения кода.',
              style: TextStyle(
                fontSize: 14, color: context.palette.textSecondary,
                height: 1.35,
              ),
            ),
            SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: TextStyle(color: context.palette.textPlaceholder, fontSize: 18),
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
            SizedBox(height: 16),
            Center(
              child: Text(
                'Нажимая «Получить код», вы принимаете\nпользовательское соглашение',
                style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Имя, телефон и тема перед вводом кода (новая регистрация) ───
class RegisterProfileScreen extends ConsumerStatefulWidget {
  const RegisterProfileScreen({
    super.key,
    required this.email,
    required this.challengeId,
    this.resendAfterSec = 60,
    this.debugOtp,
  });

  final String email;
  final String challengeId;
  final int resendAfterSec;
  final String? debugOtp;

  @override
  ConsumerState<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends ConsumerState<RegisterProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: RussianMobilePhone.prefix);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _ok => _name.text.trim().length >= 2 && _isPhoneValidForRegister(_phone.text);

  Future<void> _continue() async {
    if (!_ok) {
      setState(() => _error = 'Укажите имя (от 2 символов) и корректный телефон');
      return;
    }
    setState(() => _error = null);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SmsCodeScreen(
          email: widget.email,
          challengeId: widget.challengeId,
          resendAfterSec: widget.resendAfterSec,
          accountExists: false,
          debugOtp: widget.debugOtp,
          registerName: _name.text.trim(),
          registerPhone: RussianMobilePhone.e164OrNull(_phone.text) ?? _phone.text.trim(),
        ),
      ),
    );
  }

  ThemeMode _segmentTheme(BuildContext context) {
    final m = ref.watch(themeModeProvider);
    if (m == ThemeMode.light) return ThemeMode.light;
    if (m == ThemeMode.dark) return ThemeMode.dark;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(backgroundColor: context.palette.background, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, 0, 32, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            Text(
              'Профиль',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Код из письма вы введёте на следующем шаге. Сейчас укажите имя и телефон и выберите тему оформления — переключатель сразу меняет вид экрана.',
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary, height: 1.35),
            ),
            SizedBox(height: 8),
            Text(
              'Email для входа: ${widget.email}',
              style: TextStyle(fontSize: 13, color: context.palette.textTertiary, height: 1.3),
            ),
            SizedBox(height: 24),
            Text('Тема интерфейса', style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
            SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Светлая'),
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Тёмная'),
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
              ],
              selected: {_segmentTheme(context)},
              onSelectionChanged: (s) {
                final m = s.first;
                ref.read(themeModeProvider.notifier).setMode(m);
              },
            ),
            SizedBox(height: 24),
            Text('Имя *', style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
            SizedBox(height: 6),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: context.palette.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'Как к вам обращаться',
                hintStyle: TextStyle(color: context.palette.textPlaceholder.withValues(alpha: 0.7)),
                filled: true,
                fillColor: context.palette.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('Телефон * (без SMS-подтверждения)', style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
            SizedBox(height: 6),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [RussianMobilePhoneInputFormatter()],
              style: TextStyle(color: context.palette.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: '+7 (999) 123-45-67',
                hintStyle: TextStyle(color: context.palette.textPlaceholder.withValues(alpha: 0.7)),
                filled: true,
                fillColor: context.palette.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 10),
              Text(_error!, style: TextStyle(fontSize: 13, color: context.palette.error, height: 1.3)),
            ],
            SizedBox(height: 28),
            GoldButton(
              text: 'Далее — подтвердить email',
              onPressed: _ok ? _continue : null,
            ),
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

  /// true = аккаунт с этим email уже есть (ответ send-code) — только код, без анкеты.
  final bool accountExists;

  /// Если бэкенд с OTP_DEBUG_RETURN_CODE — показать код в UI (только для разработки).
  final String? debugOtp;

  /// Для новой регистрации: имя и телефон с предыдущего экрана (в БД попадут после верификации кода).
  final String? registerName;
  final String? registerPhone;

  const SmsCodeScreen({
    super.key,
    required this.email,
    required this.challengeId,
    this.resendAfterSec = 60,
    this.accountExists = false,
    this.debugOtp,
    this.registerName,
    this.registerPhone,
  });

  @override
  ConsumerState<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends ConsumerState<SmsCodeScreen> {
  static const int _digits = 6;

  final List<TextEditingController> _controllers = List.generate(_digits, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_digits, (_) => FocusNode());
  bool _isVerifying = false;
  bool _resendBusy = false;
  late String _challengeId;
  late int _resendSeconds;
  late bool _accountExists;
  String? _debugOtp;
  Timer? _resendTimer;

  String get _code => _controllers.map((c) => c.text).join();

  bool get _hasRegisterProfile {
    final n = widget.registerName?.trim() ?? '';
    final p = widget.registerPhone?.trim() ?? '';
    return n.length >= 2 && _isPhoneValidForRegister(p);
  }

  bool get _profileComplete => _accountExists || _hasRegisterProfile;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _accountExists = widget.accountExists;
    _debugOtp = widget.debugOtp;
    _startTimer(initial: widget.resendAfterSec.clamp(1, 600), rebuild: false);
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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
    if (!_profileComplete) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _accountExists
                ? 'Не удалось подтвердить сессию. Вернитесь назад и запросите код снова.'
                : 'Вернитесь на шаг назад и укажите имя и телефон.',
          ),
          backgroundColor: context.palette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await ref.read(authProvider.notifier).verifyEmailCode(
            widget.email,
            _challengeId,
            _code,
            phoneUnverified: _accountExists ? null : widget.registerPhone?.trim(),
            name: _accountExists ? null : widget.registerName?.trim(),
            existingAccountLogin: _accountExists,
          );
      if (!mounted) return;
      setState(() => _isVerifying = false);
      result.when(
        success: (user) {
          if (!mounted) return;
          // После установки токена в ApiClient — принудительно перезапросить заказы и чаты (иначе может остаться 401).
          ref.invalidate(ordersProvider);
          ref.invalidate(chatsProvider);
          // Дальнейший сценарий (профиль при необходимости → MainShell) ведёт [PostAuthShell] после смены MaterialApp.
        },
        failure: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: context.palette.error,
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
            content: Text(
              'Нет связи с сервером. Проверьте Wi‑Fi и что бэкенд запущен (порт в .env PORT, по умолчанию 3001).',
            ),
            backgroundColor: context.palette.error,
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
        setState(() {
          _challengeId = send.challengeId;
          _accountExists = send.accountExists;
          _debugOtp = send.debugOtp;
        });
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
            backgroundColor: context.palette.error,
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
        if (!_profileComplete) return;
        _verify();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: context.palette.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(backgroundColor: context.palette.background, elevation: 0),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(32, 0, 32, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            Text(
              _accountExists ? 'Вход в аккаунт' : 'Регистрация',
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: context.palette.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _accountExists
                  ? 'Код отправлен на email: ${widget.email}. Введите 6 цифр из письма.'
                  : 'Код отправлен на email: ${widget.email}. Учётная запись будет создана в базе после успешной проверки кода. Введите 6 цифр из письма.',
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textSecondary,
                height: 1.35,
              ),
            ),
            SizedBox(height: 24),
            if (_debugOtp != null && _debugOtp!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.primary.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Режим отладки: код $_debugOtp (включите только на своём сервере)',
                  style: TextStyle(fontSize: 13, color: context.palette.textPrimary, height: 1.35),
                ),
              ),
              SizedBox(height: 16),
            ],
            Center(
              child: Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: TextSelectionThemeData(cursorColor: context.palette.primary),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: false,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_digits, (i) => Container(
                      width: 38,
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.palette.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _focusNodes[i].hasFocus ? context.palette.primary : context.palette.border,
                          width: _focusNodes[i].hasFocus ? 2 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                          height: 1.1,
                        ),
                        cursorColor: context.palette.primary,
                        cursorHeight: 22,
                        cursorWidth: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    )),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            GoldButton(
              text: _isVerifying ? 'Проверка...' : 'Подтвердить',
              onPressed: (_isVerifying || _code.length != _digits) ? null : () => _verify(),
            ),
            SizedBox(height: 16),
            if (_isVerifying)
              Center(child: CircularProgressIndicator(color: context.palette.primary))
            else
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Повторно через $_resendSeconds с',
                        style: TextStyle(fontSize: 14, color: context.palette.textTertiary),
                      )
                    : TextButton(
                        onPressed: _resendBusy ? null : _resend,
                        child: _resendBusy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary),
                              )
                            : Text('Отправить повторно'),
                      ),
              ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Имя и телефон, если после входа они пустые в профиле ───
class MandatoryProfileBasicsScreen extends ConsumerStatefulWidget {
  const MandatoryProfileBasicsScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<MandatoryProfileBasicsScreen> createState() => _MandatoryProfileBasicsScreenState();
}

class _MandatoryProfileBasicsScreenState extends ConsumerState<MandatoryProfileBasicsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: RussianMobilePhone.prefix);
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
      if (u.phone != null && u.phone!.trim().isNotEmpty) {
        _phone.text = RussianMobilePhone.displayFromAny(u.phone);
      } else {
        _phone.text = RussianMobilePhone.prefix;
      }
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
      final phoneOut = RussianMobilePhone.e164OrNull(_phone.text) ?? _phone.text.trim();
      final res = await client.patch(
        ApiEndpoints.profile,
        data: {'name': _name.text.trim(), 'phone': phoneOut},
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
      backgroundColor: context.palette.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(32, 8, 32, 32 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Заполните профиль',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Имя и телефон нужны для записи в сервисы и связи с мастером.',
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary, height: 1.35),
            ),
            SizedBox(height: 24),
            Text('Имя *', style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
            SizedBox(height: 6),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: context.palette.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'Как к вам обращаться',
                filled: true,
                fillColor: context.palette.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('Телефон *', style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
            SizedBox(height: 6),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [RussianMobilePhoneInputFormatter()],
              style: TextStyle(color: context.palette.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: '+7 (999) 123-45-67',
                filled: true,
                fillColor: context.palette.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.palette.border),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 12),
              Text(_error!, style: TextStyle(fontSize: 13, color: context.palette.error, height: 1.3)),
            ],
            SizedBox(height: 28),
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
