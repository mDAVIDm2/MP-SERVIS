import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/client_palette.dart';
import 'garage_first_car_tutorial_provider.dart';

/// Подсветка блока во время сценария «первая машина».
class GarageTutorialTarget extends ConsumerWidget {
  const GarageTutorialTarget({
    super.key,
    required this.highlightStep,
    required this.child,
    /// Если задано, подсветка только при совпадении с машиной сценария (например карточка авто).
    this.matchCarId,
  });

  final GarageFirstCarTutorialStep highlightStep;
  final Widget child;
  final String? matchCarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(garageFirstCarTutorialProvider);
    var on = st.active && st.step == highlightStep;
    if (on && matchCarId != null && st.carId != matchCarId) on = false;
    if (!on) return child;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.gold1, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.palette.gold1.withValues(alpha: 0.28),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
