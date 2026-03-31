import 'package:flutter/material.dart';

/// Прокручивает ближайший [Scrollable] так, чтобы [context] оказался по центру видимой области.
void scrollWidgetToViewportCenter(
  BuildContext? context, {
  Duration duration = const Duration(milliseconds: 280),
  Curve curve = Curves.easeOutCubic,
}) {
  if (context == null) return;
  final renderObject = context.findRenderObject();
  if (renderObject == null || !renderObject.attached) return;
  Scrollable.ensureVisible(
    context,
    alignment: 0.5,
    duration: duration,
    curve: curve,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
}
