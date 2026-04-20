import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';

/// Аватар пользователя: сеть с Bearer или инициалы.
class UserProfileAvatar extends ConsumerWidget {
  const UserProfileAvatar({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final token = ref.watch(authProvider).accessToken;
    if (user == null) {
      return CircleAvatar(radius: radius, backgroundColor: AppColors.cardBg);
    }
    final url = AppConfig.resolveApiMediaUrl(user.avatarUrl);
    final d = radius * 2;
    if (url != null && url.isNotEmpty && token != null && token.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          key: ValueKey<String>(url),
          width: d,
          height: d,
          fit: BoxFit.cover,
          headers: {'Authorization': 'Bearer $token'},
          errorBuilder: (_, _, _) => _fallback(user.initials, d),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: d,
              height: d,
              child: Center(
                child: SizedBox(
                  width: radius * 0.65,
                  height: radius * 0.65,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.3),
      child: Text(
        user.initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _fallback(String initials, double d) {
    return Container(
      width: d,
      height: d,
      color: AppColors.primary.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: d * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
