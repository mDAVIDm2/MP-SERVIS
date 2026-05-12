import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/sto_amenity_catalog.dart';

/// Удобства СТО: в свёрнутом виде — «основные» (комната ожидания, чай/кофе), иначе первые позиции; по кнопке — полный список.
class StoCardAmenitiesSection extends StatefulWidget {
  const StoCardAmenitiesSection({super.key, required this.sto});

  final STO sto;

  @override
  State<StoCardAmenitiesSection> createState() => _StoCardAmenitiesSectionState();
}

class _StoCardAmenitiesSectionState extends State<StoCardAmenitiesSection> {
  bool _expanded = false;

  List<String> get _orderedIds {
    final set = widget.sto.amenityIds.toSet();
    final out = <String>[];
    for (final a in StoAmenityCatalog.all) {
      if (set.contains(a.id)) out.add(a.id);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedIds;
    if (ordered.isEmpty) {
      return const SizedBox.shrink();
    }
    final p = context.palette;

    final primaryInStock =
        StoAmenityCatalog.primaryIds.where(ordered.contains).toList();
    final collapsedChips = primaryInStock.isNotEmpty
        ? primaryInStock
        : ordered.take(3).toList();
    final restCount = ordered.length - collapsedChips.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.maps_home_work_outlined,
                    size: 18,
                    color: p.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in collapsedChips)
                          _AmenityChip(
                            label: StoAmenityCatalog.byId[id]!.label,
                            compact: true,
                          ),
                        if (!_expanded && restCount > 0)
                          Text(
                            '+$restCount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Все',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.textSecondary,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: p.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: p.nestedBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in ordered)
                    _AmenityChip(
                      label: StoAmenityCatalog.byId[id]!.label,
                      compact: false,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 12 : 13,
          height: 1.2,
          color: p.textPrimary,
        ),
      ),
    );
  }
}
