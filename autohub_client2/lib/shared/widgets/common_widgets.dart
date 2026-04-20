import 'package:flutter/material.dart';
import '../../core/theme/client_palette.dart';
import '../../core/theme/app_design_system.dart';

export 'marquee_text.dart';

/// Премиальный статус-чип. [compact] — для карточки заказа: высота 32–36, меньше padding.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  final bool isWarning;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
    this.isWarning = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 12.0 : 12.0;
    final vPad = compact ? 6.0 : 6.0;
    final fontSize = compact ? 13.0 : 12.0;
    final dotSize = compact ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      constraints: compact ? const BoxConstraints(minHeight: 32, maxHeight: 36) : null,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        boxShadow: compact
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isWarning) ...[
            Text('⚠️ ', style: TextStyle(fontSize: fontSize - 2)),
          ] else if (showDot) ...[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: compact ? 6 : 8),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка-капсула с градиентом, бордером и внутренним бликом.
class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? overlayColor;

  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: AppDesignSystem.premiumButtonDecoration(p, isActive: isActive || overlayColor != null),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: overlayColor ?? p.gold1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16, color: overlayColor ?? p.gold1),
            ],
          ),
        ),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final bool fullWidth;

  const GoldButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.height = 56,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: p.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: p.onAccent,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.onAccent,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Заголовок секции: акцентный цвет; [compact] — меньший размер.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final bool compact;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 14),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                  color: p.gold1,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (actionText != null) ...[
            SizedBox(width: 8),
            Flexible(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      actionText!,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w500,
                        color: p.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: p.bgCard,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusStatCard),
                border: Border.all(color: p.strokeGold.withValues(alpha: 0.14), width: 1),
                boxShadow: p.cardShadow,
              ),
              child: Center(
                child: Text(icon, style: TextStyle(fontSize: 48)),
              ),
            ),
            SizedBox(height: 28),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: p.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null) ...[
              SizedBox(height: 28),
              GoldButton(
                text: buttonText!,
                onPressed: onButton,
                fullWidth: false,
                height: 50,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Премиальная stat card: градиент, тонкий акцентный бордер, тень.
class StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final String? subtitle;
  final Color? dotColor;
  final VoidCallback? onTap;

  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.subtitle,
    this.dotColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusStatCard),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: AppDesignSystem.statCardDecoration(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (dotColor != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor!.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.gold1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: p.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
