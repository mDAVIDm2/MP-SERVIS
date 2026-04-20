import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order_model.dart';

class StatsRow extends StatelessWidget {
  final int activeCount;
  final int monthTotal;
  final OrderStatus? lastStatus;

  const StatsRow({
    super.key,
    required this.activeCount,
    required this.monthTotal,
    this.lastStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatBlock(
          value: '$activeCount',
          suffix: ' ${_orderWord(activeCount)}',
          label: 'активных',
        )),
        SizedBox(width: 8),
        Expanded(child: _StatBlock(
          value: Formatters.money(monthTotal),
          label: 'за месяц',
        )),
        SizedBox(width: 8),
        Expanded(child: _StatBlock(
          value: lastStatus?.label ?? '—',
          label: 'последний',
          dotColor: lastStatus?.color,
          isSmallValue: true,
        )),
      ],
    );
  }

  String _orderWord(int n) {
    final lastTwo = n % 100;
    final lastOne = n % 10;
    if (lastTwo >= 11 && lastTwo <= 19) return 'заказов';
    if (lastOne == 1) return 'заказ';
    if (lastOne >= 2 && lastOne <= 4) return 'заказа';
    return 'заказов';
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String? suffix;
  final String label;
  final Color? dotColor;
  final bool isSmallValue;

  const _StatBlock({
    required this.value,
    this.suffix,
    required this.label,
    this.dotColor,
    this.isSmallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dotColor != null)
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: isSmallValue
                        ? TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary)
                        : AppTextStyles.numberLarge(context.palette),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: suffix,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: context.palette.textSecondary),
                    ),
                ],
              ),
            ),
          SizedBox(height: 4),
          Text(label, style: AppTextStyles.small(context.palette)),
        ],
      ),
    );
  }
}
