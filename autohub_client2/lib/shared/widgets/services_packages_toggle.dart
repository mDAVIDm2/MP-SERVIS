import 'package:flutter/material.dart';
import '../../core/theme/client_palette.dart';

/// Переключатель «Список услуг» / «Комплексы»: весь блок — одна кнопка, ползунок едет в сторону выбранного режима.
class ServicesPackagesToggle extends StatelessWidget {
  const ServicesPackagesToggle({
    super.key,
    required this.showPackages,
    required this.onToggle,
  });

  final bool showPackages;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final half = (w - 4) / 2;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.palette.nestedBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.palette.border),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: showPackages ? half : 0,
                    top: 0,
                    bottom: 0,
                    width: half,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.palette.primary,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: context.palette.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'Услуги',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: !showPackages
                                  ? context.palette.onAccent
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Комплексы',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: showPackages
                                  ? context.palette.onAccent
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
