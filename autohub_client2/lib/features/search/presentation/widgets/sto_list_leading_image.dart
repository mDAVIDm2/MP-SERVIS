import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/sto_model.dart';

/// Как на карте: логотип или первая фотография организации.
String? stoPreviewImageUrl(STO sto) {
  final logo = sto.logoUrl?.trim();
  if (logo != null && logo.isNotEmpty) return logo;
  for (final u in sto.photoUrls) {
    final t = u.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

class StoListLeadingImage extends StatelessWidget {
  const StoListLeadingImage({
    super.key,
    required this.sto,
    this.size = 80,
    this.borderRadius = 12,
  });

  final STO sto;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = stoPreviewImageUrl(sto);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: context.palette.nestedBg,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size * 0.3,
                    height: size * 0.3,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    _StoListImagePlaceholder(sto: sto, size: size, borderRadius: borderRadius),
              )
            : _StoListImagePlaceholder(sto: sto, size: size, borderRadius: borderRadius),
      ),
    );
  }
}

class _StoListImagePlaceholder extends StatelessWidget {
  const _StoListImagePlaceholder({
    required this.sto,
    required this.size,
    this.borderRadius = 12,
  });

  final STO sto;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final letter = sto.name.isNotEmpty ? sto.name[0] : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.palette.nestedBg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: math.min(28, size * 0.35),
            fontWeight: FontWeight.w700,
            color: context.palette.primary,
          ),
        ),
      ),
    );
  }
}
