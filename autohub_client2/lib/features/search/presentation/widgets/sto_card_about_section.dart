import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';

/// Блок «О сервисе»: краткий превью-текст и раскрытие полного описания.
class StoCardAboutSection extends StatefulWidget {
  const StoCardAboutSection({
    super.key,
    required this.text,
    this.title = 'О сервисе',
  });

  final String text;
  final String title;

  @override
  State<StoCardAboutSection> createState() => _StoCardAboutSectionState();
}

class _StoCardAboutSectionState extends State<StoCardAboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.text.trim();
    if (t.isEmpty) {
      return const SizedBox.shrink();
    }
    final p = context.palette;
    final needsMore = t.length > 180 || t.contains('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: p.textTertiary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          AnimatedCrossFade(
            firstChild: Text(
              t,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: p.textSecondary,
              ),
            ),
            secondChild: SelectableText(
              t,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: p.textSecondary,
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          if (needsMore) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded ? 'Свернуть' : 'Показать полностью',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.primary,
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
