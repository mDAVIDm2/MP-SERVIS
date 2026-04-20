import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/auth/auth_provider.dart';

/// Плавный переход между шагами входа (fade + лёгкий сдвиг).
PageRoute<T> buildAuthRoute<T extends Object?>(Widget page) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: page.runtimeType.toString()),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AuthPalette {
  const _AuthPalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.gradient,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final List<Color> gradient;

  static _AuthPalette desktop(BuildContext context) {
    return _AuthPalette(
      background: AppColorsDesktop.background,
      surface: AppColorsDesktop.surface,
      primary: AppColorsDesktop.primary,
      onPrimary: Colors.white,
      textPrimary: AppColorsDesktop.textPrimary,
      textSecondary: AppColorsDesktop.textSecondary,
      border: AppColorsDesktop.border,
      gradient: [
        AppColorsDesktop.background,
        AppColorsDesktop.nestedBg.withValues(alpha: 0.85),
        AppColorsDesktop.primary.withValues(alpha: 0.06),
      ],
    );
  }

  static _AuthPalette mobile() {
    return _AuthPalette(
      background: AppColors.background,
      surface: AppColors.cardBg,
      primary: AppColors.primary,
      onPrimary: const Color(0xFF0D0D0D),
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      border: AppColors.border,
      gradient: [
        AppColors.background,
        AppColors.surface,
        AppColors.primary.withValues(alpha: 0.12),
      ],
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopPlatform;
    final p = desktop ? _AuthPalette.desktop(context) : _AuthPalette.mobile();

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: p.gradient,
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 48 : 28,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: desktop ? 440 : 400),
                child: Column(
                  children: [
                    SizedBox(height: desktop ? 32 : 16),
                    ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 1.028).animate(
                        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                      ),
                      child: Hero(
                        tag: 'auth_logo',
                        child: Container(
                          width: desktop ? 108 : 96,
                          height: desktop ? 108 : 96,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(
                              desktop ? 26 : 22,
                            ),
                            border: Border.all(color: p.border),
                            boxShadow: desktop
                                ? DesktopDesignSystem.shadowCard
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              'Бизнес',
                              style: TextStyle(
                                fontSize: desktop ? 34 : 30,
                                fontWeight: FontWeight.w800,
                                color: p.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'MP-Servis Business',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: desktop ? 30 : 26,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Расписание, заказы и чаты вашего автосервиса',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: desktop ? 15 : 14,
                        height: 1.45,
                        color: p.textSecondary,
                      ),
                    ),
                    SizedBox(height: desktop ? 48 : 40),
                    SizedBox(
                      width: double.infinity,
                      height: desktop ? 50 : 52,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          buildAuthRoute(const EmailInputScreen()),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              desktop
                                  ? DesktopDesignSystem.radiusButton
                                  : 14,
                            ),
                          ),
                          elevation: desktop ? 0 : 2,
                        ),
                        child: Text(
                          'Войти',
                          style: TextStyle(
                            fontSize: desktop ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: desktop ? 24 : 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^\d]'), '');

/// Нормализация для API: только цифры, ведущая 7 для РФ.
String normalizeBusinessPhone(String input) {
  var d = _digitsOnly(input);
  if (d.startsWith('8') && d.length >= 11) {
    d = '7${d.substring(1)}';
  } else if (!d.startsWith('7') && d.length == 10) {
    d = '7$d';
  }
  return d;
}

class _RuPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = _digitsOnly(newValue.text);
    if (d.startsWith('8')) d = '7${d.substring(1)}';
    if (d.length > 11) d = d.substring(0, 11);
    if (d.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    if (!d.startsWith('7')) d = '7$d';

    final buf = StringBuffer('+7 ');
    final rest = d.substring(1);
    if (rest.isNotEmpty) {
      buf.write('(');
      buf.write(rest.substring(0, rest.length.clamp(0, 3)));
      if (rest.length >= 3) buf.write(') ');
      if (rest.length > 3) {
        buf.write(rest.substring(3, rest.length.clamp(3, 6)));
      }
      if (rest.length > 6) {
        buf.write('-');
        buf.write(rest.substring(6, rest.length.clamp(6, 8)));
      }
      if (rest.length > 8) {
        buf.write('-');
        buf.write(rest.substring(8, rest.length.clamp(8, 10)));
      }
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

bool _isValidEmailFormat(String input) {
  final s = input.trim();
  if (s.length < 5 || s.length > 254) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
}

String _maskedEmailForUi(String email) {
  final e = email.trim();
  final at = e.indexOf('@');
  if (at <= 1) return e;
  return '${e[0]}•••${e.substring(at)}';
}

/// Опциональный телефон без верификации: в API уходит только при полной нормализации (11 цифр).
String? _optionalPhoneUnverified(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final n = normalizeBusinessPhone(t);
  return n.length >= 11 ? n : null;
}

class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _isValidEmailFormat(_controller.text);

  Future<void> _requestCode() async {
    if (!_isValid || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final email = _controller.text.trim().toLowerCase();
    final result = await ref.read(authProvider.notifier).sendLoginCode(email);
    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (send) {
        Navigator.of(context).push(
          buildAuthRoute(EmailOtpVerifyScreen(
            email: email,
            challengeId: send.challengeId,
            resendAfterSec: send.resendAfter,
            accountExists: send.accountExists,
          )),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopPlatform;
    final p = desktop ? _AuthPalette.desktop(context) : _AuthPalette.mobile();

    return Scaffold(
      backgroundColor: p.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: p.gradient,
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: desktop ? 48 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: desktop ? 440 : 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
                        tooltip: 'Назад',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Электронная почта',
                      style: TextStyle(
                        fontSize: desktop ? 24 : 22,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Отправим одноразовый код на email (6 цифр). При AUTH_OTP_DELIVERY=console код смотрите в логах бэкенда.',
                      style: TextStyle(
                        fontSize: desktop ? 14 : 13,
                        height: 1.4,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Material(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(
                        desktop ? DesktopDesignSystem.radiusCard : 16,
                      ),
                      elevation: desktop ? 0 : 0,
                      shadowColor: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            desktop ? DesktopDesignSystem.radiusCard : 16,
                          ),
                          border: Border.all(color: p.border),
                          boxShadow: desktop ? DesktopDesignSystem.shadowCard : null,
                        ),
                        padding: const EdgeInsets.all(20),
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: p.textPrimary,
                            letterSpacing: 0.2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'you@example.com',
                            hintStyle: TextStyle(
                              color: p.textSecondary.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _requestCode(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: desktop ? 50 : 52,
                      child: FilledButton(
                        onPressed: _isValid && !_loading ? _requestCode : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                          disabledBackgroundColor: p.primary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              desktop
                                  ? DesktopDesignSystem.radiusButton
                                  : 14,
                            ),
                          ),
                        ),
                        child: _loading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: p.onPrimary,
                                ),
                              )
                            : const Text(
                                'Получить код',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailOtpVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  final String challengeId;
  final int resendAfterSec;
  /// Уже есть пользователь с этим email — только код, без имени и телефона.
  final bool accountExists;

  const EmailOtpVerifyScreen({
    super.key,
    required this.email,
    required this.challengeId,
    this.resendAfterSec = 60,
    this.accountExists = false,
  });

  @override
  ConsumerState<EmailOtpVerifyScreen> createState() => _EmailOtpVerifyScreenState();
}

class _EmailOtpVerifyScreenState extends ConsumerState<EmailOtpVerifyScreen> {
  final _codeController = TextEditingController();
  final _nameOpt = TextEditingController();
  final _phoneOpt = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _resendBusy = false;
  late String _challengeId;
  late int _resendSeconds;
  /// Актуально после повторной отправки кода (флаг с сервера может измениться).
  late bool _accountExists;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _accountExists = widget.accountExists;
    if (!_accountExists) {
      _phoneOpt.text = '+7 ';
    }
    _startResendCountdown(widget.resendAfterSec.clamp(1, 600), rebuild: false);
  }

  void _startResendCountdown(int sec, {bool rebuild = true}) {
    _timer?.cancel();
    _resendSeconds = sec;
    if (rebuild && mounted) setState(() {});
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _nameOpt.dispose();
    _phoneOpt.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (code.length != 6) {
      setState(() => _error = 'Введите 6 цифр');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final result = await ref.read(authProvider.notifier).verifyEmailCode(
          widget.email,
          _challengeId,
          code,
          phoneUnverified: _accountExists ? null : _optionalPhoneUnverified(_phoneOpt.text),
          name: _accountExists ? null : (_nameOpt.text.trim().isEmpty ? null : _nameOpt.text.trim()),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (user) {
        if (user.hasMultipleOrganizations) {
          context.go('/select-organization');
        } else {
          context.go('/app');
        }
      },
      failure: (e) => setState(() => _error = e.message),
    );
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _resendBusy) return;
    setState(() => _resendBusy = true);
    final result = await ref.read(authProvider.notifier).sendLoginCode(widget.email);
    if (!mounted) return;
    setState(() => _resendBusy = false);
    result.when(
      success: (send) {
        setState(() {
          _challengeId = send.challengeId;
          _accountExists = send.accountExists;
        });
        _codeController.clear();
        _startResendCountdown(send.resendAfter.clamp(1, 600), rebuild: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Код отправлен повторно'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopPlatform;
    final p = desktop ? _AuthPalette.desktop(context) : _AuthPalette.mobile();
    final masked = _maskedEmailForUi(widget.email);

    return Scaffold(
      backgroundColor: p.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: p.gradient,
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: desktop ? 48 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: desktop ? 440 : 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
                        tooltip: 'Назад',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _accountExists ? 'Вход в аккаунт' : 'Регистрация',
                      style: TextStyle(
                        fontSize: desktop ? 24 : 22,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _accountExists
                          ? 'Введите 6 цифр из письма для $masked. Дополнительные данные не нужны.'
                          : 'Введите 6 цифр для $masked. При первой регистрации можно указать имя и телефон — номер сохранится без подтверждения.',
                      style: TextStyle(
                        fontSize: desktop ? 14 : 13,
                        height: 1.4,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Material(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(
                        desktop ? DesktopDesignSystem.radiusCard : 16,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            desktop ? DesktopDesignSystem.radiusCard : 16,
                          ),
                          border: Border.all(color: p.border),
                          boxShadow: desktop ? DesktopDesignSystem.shadowCard : null,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                            color: p.textPrimary,
                            height: 1.2,
                          ),
                          cursorColor: p.primary,
                          cursorHeight: 26,
                          cursorWidth: 2,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              letterSpacing: 6,
                              color: p.textSecondary.withValues(alpha: 0.35),
                            ),
                            errorText: _error,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _verify(),
                        ),
                      ),
                    ),
                    if (!_accountExists) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Имя (необязательно)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameOpt,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 16, color: p.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Как к вам обращаться',
                          hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: 0.55)),
                          filled: true,
                          fillColor: p.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(desktop ? DesktopDesignSystem.radiusCard : 14),
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(desktop ? DesktopDesignSystem.radiusCard : 14),
                            borderSide: BorderSide(color: p.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Телефон (необязательно, без подтверждения)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneOpt,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 16, color: p.textPrimary),
                        inputFormatters: [_RuPhoneInputFormatter()],
                        decoration: InputDecoration(
                          hintText: '+7 (999) 123-45-67',
                          hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: 0.55)),
                          filled: true,
                          fillColor: p.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(desktop ? DesktopDesignSystem.radiusCard : 14),
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(desktop ? DesktopDesignSystem.radiusCard : 14),
                            borderSide: BorderSide(color: p.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: _resendSeconds > 0
                          ? Text(
                              'Повторно через $_resendSeconds с',
                              style: TextStyle(fontSize: 13, color: p.textSecondary),
                            )
                          : TextButton(
                              onPressed: _resendBusy ? null : _resend,
                              child: _resendBusy
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: p.primary,
                                      ),
                                    )
                                  : Text(
                                      'Отправить код снова',
                                      style: TextStyle(
                                        color: p.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: desktop ? 50 : 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _verify,
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              desktop
                                  ? DesktopDesignSystem.radiusButton
                                  : 14,
                            ),
                          ),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: p.onPrimary,
                                ),
                              )
                            : const Text(
                                'Войти',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
