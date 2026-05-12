import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_launcher/map_launcher.dart';

import '../settings/preferred_directions_map_provider.dart';
import '../theme/client_palette.dart';

bool _drivingRouteFlowInProgress = false;

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

Future<Position?> tryCurrentUserPositionForRoute() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  } catch (_) {
    return null;
  }
}

/// Маршрут до точки: установленное приложение карт из [preferredDirectionsMapProvider] или выбор с сохранением.
Future<void> launchDrivingRoute(
  BuildContext context,
  WidgetRef ref, {
  required double destLat,
  required double destLng,
  required String destinationTitle,
  Position? userPosition,
}) async {
  if (_drivingRouteFlowInProgress) {
    return;
  }
  _drivingRouteFlowInProgress = true;
  try {
  final available = await MapLauncher.installedMaps;
  if (available.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет установленных карт для маршрута'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final originCoords = userPosition != null ? Coords(userPosition.latitude, userPosition.longitude) : null;
  final destination = Coords(destLat, destLng);

  final preferredType = ref.read(preferredDirectionsMapProvider);
  if (preferredType != null && preferredType.isNotEmpty) {
    final preferred = available.where((m) => m.mapType.name == preferredType).firstOrNull;
    if (preferred != null) {
      try {
        await preferred.showDirections(
          destination: destination,
          destinationTitle: destinationTitle,
          origin: originCoords,
          originTitle: 'Моё местоположение',
        );
        return;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть карты'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
  }

  if (available.length == 1) {
    await ref.read(preferredDirectionsMapProvider.notifier).set(available.first.mapType.name);
    try {
      await available.first.showDirections(
        destination: destination,
        destinationTitle: destinationTitle,
        origin: originCoords,
        originTitle: 'Моё местоположение',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть карты'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return;
  }

  if (!context.mounted) return;
  final chosen = await showModalBottomSheet<AvailableMap>(
    context: context,
    backgroundColor: context.palette.cardBg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Выберите навигатор',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          ...available.map(
            (map) => ListTile(
              leading: Icon(Icons.map_rounded, color: context.palette.primary, size: 28),
              title: Text(
                directionsMapDisplayName(map),
                style: TextStyle(color: context.palette.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, map),
            ),
          ),
        ],
      ),
    ),
  );
  if (chosen == null) return;
  await ref.read(preferredDirectionsMapProvider.notifier).set(chosen.mapType.name);
  try {
    await chosen.showDirections(
      destination: destination,
      destinationTitle: destinationTitle,
      origin: originCoords,
      originTitle: 'Моё местоположение',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть карты'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  } finally {
    _drivingRouteFlowInProgress = false;
  }
}
