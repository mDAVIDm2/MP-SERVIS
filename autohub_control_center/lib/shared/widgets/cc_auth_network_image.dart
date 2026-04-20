import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';

/// Сетевое изображение с заголовком Authorization (internal JWT) — аватар пользователя и фото авто (internal/...).
class CcAuthNetworkImage extends ConsumerWidget {
  const CcAuthNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authProvider).accessToken;
    final headers = token != null && token.isNotEmpty ? {'Authorization': 'Bearer $token'} : null;
    final child = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      headers: headers,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => placeholder ?? _defaultPlaceholder(width, height),
      loadingBuilder: (context, w, ev) {
        if (ev == null) return w;
        return placeholder ?? _defaultPlaceholder(width, height);
      },
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  static Widget _defaultPlaceholder(double? w, double? h) {
    return Container(
      width: w,
      height: h,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.person_outline, color: Colors.black38),
    );
  }
}
