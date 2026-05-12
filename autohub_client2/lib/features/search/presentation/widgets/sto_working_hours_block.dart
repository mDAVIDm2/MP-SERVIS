import 'package:flutter/material.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../shared/models/sto_model.dart';

const _dayNames = <String>[
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

String _formatHm(String hm) {
  final p = hm.split(':');
  if (p.length != 2) return hm;
  final h = int.tryParse(p[0]) ?? 0;
  return '$h:${p[1]}';
}

String _lineForDay(StoDaySchedule d) {
  if (d.closed) return 'Выходной';
  return '${_formatHm(d.open)} – ${_formatHm(d.close)}';
}

/// Для мини-карточек списка: статус по [STO.hoursLive] с сервера либо запасной вариант по неделе.
String stoSearchCardTodayHoursLine(STO sto, AppL10n l10n) {
  final live = sto.hoursLive;
  if (live != null) {
    switch (live.state) {
      case 'open':
        return l10n.searchOpen;
      case 'open_until':
        final t = live.closeHm ?? '';
        return t.isEmpty ? l10n.searchOpen : l10n.searchOpenUntil(_formatHm(t));
      case 'closed_until_today':
        final t = live.nextOpenHm ?? '';
        return t.isEmpty ? l10n.searchClosed : l10n.searchClosedUntil(_formatHm(t));
      case 'closed_until_future':
        final t = live.nextOpenHm ?? '';
        if (t.isEmpty) return l10n.searchClosed;
        final ds = live.nextOpenDate;
        if (ds != null && ds.length >= 10) {
          final parsed = DateTime.tryParse(ds.substring(0, 10));
          if (parsed != null) {
            final today = DateTime.now();
            final today0 = DateTime(today.year, today.month, today.day);
            final open0 = DateTime(parsed.year, parsed.month, parsed.day);
            final diff = open0.difference(today0).inDays;
            if (diff <= 1) {
              return l10n.searchClosedUntil(_formatHm(t));
            }
            final dayShort =
                '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}';
            return l10n.searchClosedUntilWithDay(dayShort, _formatHm(t));
          }
        }
        return l10n.searchClosedUntil(_formatHm(t));
      case 'day_off':
        return l10n.searchDayOff;
      case 'exception_closed':
        return l10n.searchNotOperating;
      default:
        break;
    }
  }
  final w = sto.workingHoursWeek;
  if (w != null && w.length == 7) {
    final i = DateTime.now().weekday - 1;
    final d = w[i.clamp(0, 6)];
    if (d.closed) return l10n.searchDayOff;
    if (sto.isOpen) {
      return l10n.searchOpenUntil(_formatHm(d.close));
    }
    return l10n.searchClosed;
  }
  return sto.isOpen ? l10n.searchOpen : l10n.searchClosed;
}

/// «Сегодня: …» + раскрываемый график по дням; иначе строка [STO.workingHours].
class StoWorkingHoursBlock extends StatefulWidget {
  const StoWorkingHoursBlock({super.key, required this.sto});

  final STO sto;

  @override
  State<StoWorkingHoursBlock> createState() => _StoWorkingHoursBlockState();
}

class _StoWorkingHoursBlockState extends State<StoWorkingHoursBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final week = widget.sto.workingHoursWeek;
    if (week != null && week.length == 7) {
      final todayI = DateTime.now().weekday - 1;
      final safeToday = todayI.clamp(0, 6);
      final todaySched = week[safeToday];
      final p = context.palette;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18, color: p.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Сегодня: ${_lineForDay(todaySched)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'График',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: p.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 28, top: 8, right: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(7, (i) {
                    final line = _lineForDay(week[i]);
                    final isToday = i == safeToday;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday
                            ? p.primary.withValues(alpha: 0.12)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        border: isToday ? Border.all(color: p.primary.withValues(alpha: 0.35)) : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dayNames[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            line,
                            style: TextStyle(
                              fontSize: 13,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              crossFadeState:
                  _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      );
    }

    final wh = widget.sto.workingHours;
    if (wh == null || wh.isEmpty) return const SizedBox.shrink();

    return _InfoLine(icon: Icons.access_time_rounded, text: wh);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
