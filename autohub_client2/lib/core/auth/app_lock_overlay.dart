import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_colors.dart';
import 'app_lock_provider.dart';

/// Полноэкранная блокировка поверх основного UI при уходе в фон (см. [AppLockNotifier]).
class AppLockOverlay extends ConsumerStatefulWidget {
  const AppLockOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    final ok = await ref.read(pinVaultProvider).verify(pin);
    if (!mounted) return;
    if (ok) {
      _pinController.clear();
      setState(() => _error = null);
      ref.read(appLockProvider.notifier).unlock();
    } else {
      setState(() => _error = 'Неверный PIN');
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _tryBiometric() async {
    final settings = ref.read(securitySettingsProvider);
    if (!settings.biometricEnabled) return;
    final la = ref.read(localAuthProvider);
    try {
      final ok = await la.authenticate(
        localizedReason: 'Разблокируйте AutoHub',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!mounted) return;
      if (ok) {
        _pinController.clear();
        setState(() => _error = null);
        ref.read(appLockProvider.notifier).unlock();
      }
    } on PlatformException {
      if (mounted) setState(() => _error = 'Биометрия недоступна');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider);
    final showBio = ref.watch(securitySettingsProvider).biometricEnabled;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(ignoring: locked, child: widget.child),
        if (locked)
          Material(
            color: AppColors.background,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    const Text(
                      'Приложение заблокировано',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Введите PIN-код или используйте биометрию',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 6,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'PIN',
                        errorText: _error,
                        filled: true,
                        fillColor: AppColors.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _tryPin(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _tryPin,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF0D0D0D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Разблокировать', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (showBio) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _tryBiometric,
                        icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
                        label: const Text('Биометрия', style: TextStyle(color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
