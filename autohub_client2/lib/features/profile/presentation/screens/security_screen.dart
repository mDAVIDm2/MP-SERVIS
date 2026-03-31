import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/auth/app_lock_provider.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/security_settings.dart';
import '../../../../core/theme/app_colors.dart';
import 'active_sessions_screen.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _loaded = false;
  bool _pinEnabled = false;
  bool _biometric = false;
  LockRequestMode _lockRequestMode = LockRequestMode.appOpen;
  bool _pinDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final s = ref.read(securitySettingsProvider);
    setState(() {
      _pinEnabled = s.pinEnabled;
      _biometric = s.biometricEnabled;
      _lockRequestMode = s.lockRequestMode;
    });
  }

  Future<String?> _askPin({required String title, int minLen = 4}) async {
    if (!mounted || _pinDialogOpen) return null;
    _pinDialogOpen = true;
    final c = TextEditingController();
    try {
      final pin = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Только цифры',
              hintStyle: TextStyle(color: AppColors.textTertiary),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!ctx.mounted) return;
                await Navigator.of(ctx, rootNavigator: true).maybePop();
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final t = c.text.trim();
                if (t.length >= minLen) {
                  if (!ctx.mounted) return;
                  await Navigator.of(ctx, rootNavigator: true).maybePop(t);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: const Color(0xFF0D0D0D)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return pin;
    } catch (_) {
      return null;
    } finally {
      c.dispose();
      _pinDialogOpen = false;
    }
  }

  Future<void> _setNewPinFlow() async {
    final a = await _askPin(title: 'Придумайте PIN (4–8 цифр)', minLen: 4);
    if (a == null || !mounted) return;
    final b = await _askPin(title: 'Повторите PIN', minLen: 4);
    if (b == null || !mounted) return;
    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN не совпадают'), backgroundColor: AppColors.error),
      );
      return;
    }
    try {
      await ref.read(pinVaultProvider).setPin(a);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    await ref.read(securitySettingsProvider).setPinEnabled(true);
    if (mounted) {
      setState(() => _pinEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN сохранён'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _onPinToggle(bool v) async {
    final settings = ref.read(securitySettingsProvider);
    final vault = ref.read(pinVaultProvider);

    if (v) {
      final has = await vault.hasPin();
      if (!has) {
        await _setNewPinFlow();
        return;
      }
      await settings.setPinEnabled(true);
      if (mounted) setState(() => _pinEnabled = true);
      return;
    }

    final cur = await _askPin(title: 'Введите PIN для отключения');
    if (cur == null || !mounted) return;
    final verified = await vault.verify(cur);
    if (!mounted) return;
    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный PIN'), backgroundColor: AppColors.error),
      );
      return;
    }
    await vault.clear();
    await settings.setPinEnabled(false);
    await settings.setBiometricEnabled(false);
    ref.read(appLockProvider.notifier).unlock();
    if (mounted) {
      setState(() {
        _pinEnabled = false;
        _biometric = false;
      });
    }
  }

  Future<void> _onBiometricToggle(bool v) async {
    final settings = ref.read(securitySettingsProvider);
    final vault = ref.read(pinVaultProvider);
    if (v && (!_pinEnabled || !await vault.hasPin())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала включите PIN-код'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }
    if (v) {
      final la = ref.read(localAuthProvider);
      final supported = await la.isDeviceSupported();
      final can = await la.canCheckBiometrics;
      if (!mounted) return;
      if (!supported || !can) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Биометрия недоступна на этом устройстве'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }
    await settings.setBiometricEnabled(v);
    if (mounted) setState(() => _biometric = v);
  }

  Future<void> _changePin() async {
    try {
      final vault = ref.read(pinVaultProvider);
      if (!await vault.hasPin()) {
        await _setNewPinFlow();
        return;
      }
      final old = await _askPin(title: 'Текущий PIN');
      if (old == null || !mounted) return;
      final oldVerified = await vault.verify(old);
      if (!mounted) return;
      if (!oldVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный PIN'), backgroundColor: AppColors.error),
        );
        return;
      }
      final a = await _askPin(title: 'Новый PIN', minLen: 4);
      if (a == null || !mounted) return;
      final b = await _askPin(title: 'Повторите новый PIN', minLen: 4);
      if (b == null || !mounted) return;
      if (a != b) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN не совпадают'), backgroundColor: AppColors.error),
        );
        return;
      }
      await vault.setPin(a);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN обновлён'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка смены PIN: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _lockModeLabel(LockRequestMode mode) {
    switch (mode) {
      case LockRequestMode.appOpen:
        return 'При открытии приложения';
      case LockRequestMode.authorization:
        return 'При авторизации';
    }
  }

  Future<void> _pickLockRequestMode() async {
    const opts = [LockRequestMode.appOpen, LockRequestMode.authorization];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Когда запрашивать PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            ...opts.map((mode) {
              return RadioListTile<LockRequestMode>(
                value: mode,
                groupValue: _lockRequestMode,
                activeColor: AppColors.primary,
                title: Text(
                  _lockModeLabel(mode),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(securitySettingsProvider).setLockRequestMode(v);
                  if (!mounted) return;
                  setState(() => _lockRequestMode = v);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccountConfirmed() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    try {
      await ref.read(apiClientProvider).delete(ApiEndpoints.profileDelete);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = 'Не удалось удалить аккаунт. Попробуйте позже.';
      if (data is Map && data['message'] is String) {
        msg = data['message'] as String;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await ref.read(authProvider.notifier).logout();
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить аккаунт?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Аккаунт и данные на сервере будут удалены. Заказы в сервисах могут сохраниться у организаций. Это действие нельзя отменить.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: _deleteAccountConfirmed,
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Безопасность', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SwitchRow(
                  label: 'PIN-код',
                  subtitle: 'Блокировка при возврате из фона',
                  value: _pinEnabled,
                  onChanged: _onPinToggle,
                ),
                _SwitchRow(
                  label: 'Биометрия',
                  subtitle: 'Face ID / отпечаток для разблокировки',
                  value: _biometric,
                  onChanged: _onBiometricToggle,
                ),
                _ActionRow(
                  icon: Icons.timer_outlined,
                  label: 'Запрос PIN',
                  subtitle: _lockModeLabel(_lockRequestMode),
                  onTap: _pickLockRequestMode,
                ),
                _ActionRow(
                  icon: Icons.key_rounded,
                  label: 'Сменить PIN-код',
                  onTap: _changePin,
                ),
                _ActionRow(
                  icon: Icons.password_rounded,
                  label: 'Активные сессии',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()),
                  ),
                ),
                _ActionRow(
                  icon: Icons.delete_forever_rounded,
                  label: 'Удалить аккаунт',
                  isDestructive: true,
                  onTap: () => _showDeleteDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

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
            Icon(icon, size: 22, color: isDestructive ? AppColors.error : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDestructive ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
