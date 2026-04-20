import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/widgets/garage_car_photo_image.dart';

String? resolveCarPhotoRawForOrder(Order order, Car car) {
  final o = order.carPhotoUrl?.trim();
  if (o != null && o.isNotEmpty) return o;
  final c = car.photoUrl?.trim();
  return (c != null && c.isNotEmpty) ? c : null;
}

String? resolveOrganizationLogoUrl(STO? sto) {
  final u = sto?.logoUrl?.trim();
  return (u != null && u.isNotEmpty) ? u : null;
}

class OrderCarAvatar extends StatelessWidget {
  const OrderCarAvatar({
    super.key,
    required this.rawPhoto,
    required this.size,
    required this.borderRadius,
  });

  final String? rawPhoto;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: GarageCarPhotoImage(photoUrl: rawPhoto, fit: BoxFit.cover),
      ),
    );
  }
}

class OrderOrganizationAvatar extends StatelessWidget {
  const OrderOrganizationAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.size,
    this.borderRadius,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final u = imageUrl?.trim();
    final r = borderRadius ?? BorderRadius.circular(size * 0.2);
    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        width: size,
        height: size,
        child: u != null && u.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: u,
                fit: BoxFit.cover,
                placeholder: (_, __) => _fallback(context),
                errorWidget: (_, __, ___) => _fallback(context),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final t = name.trim();
    final letter = t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
