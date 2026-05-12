import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

/// Точка графика пробега.
class MileageChartPoint {
  MileageChartPoint({
    required this.date,
    required this.km,
    this.order,
    this.isManualGarageOnly = false,
    this.isYearZeroOrigin = false,
  });

  final DateTime date;
  final int km;
  final Order? order;
  final bool isManualGarageOnly;
  /// Точка «год выпуска · 0 км» (1 янв. года выпуска).
  final bool isYearZeroOrigin;
}

List<MileageChartPoint> buildMileagePoints(Car car, List<Order> orders) {
  final forCar = orders.where((o) => o.carId == car.id).toList();
  final pts = <MileageChartPoint>[];

  for (final o in forCar) {
    final km = o.odometerAtCompletion ?? o.mileage;
    if (km == null || km <= 0) continue;
    final finished = o.status == OrderStatus.done || o.status == OrderStatus.completed;
    if (!finished) continue;
    final t = o.updatedAt ?? o.plannedEndTime ?? o.plannedStartTime ?? o.dateTime;
    pts.add(MileageChartPoint(date: t, km: km, order: o));
  }

  pts.sort((a, b) => a.date.compareTo(b.date));

  final year = car.year > 1900 ? car.year : DateTime.now().year;
  final manufactureJan1 = DateTime(year, 1, 1);
  final hasOrigin =
      pts.any((p) => p.date.year == manufactureJan1.year && p.date.month == 1 && p.date.day == 1 && p.km == 0);
  if (!hasOrigin) {
    pts.insert(
      0,
      MileageChartPoint(
        date: manufactureJan1,
        km: 0,
        isYearZeroOrigin: true,
      ),
    );
    pts.sort((a, b) => a.date.compareTo(b.date));
  }

  if (pts.isNotEmpty && car.mileage > 0) {
    final last = pts.last;
    if (car.mileage != last.km) {
      pts.add(
        MileageChartPoint(
          date: DateTime.now(),
          km: car.mileage,
          isManualGarageOnly: true,
        ),
      );
    }
  } else if (pts.isEmpty && car.mileage > 0) {
    pts.add(
      MileageChartPoint(
        date: DateTime.now(),
        km: car.mileage,
        isManualGarageOnly: true,
      ),
    );
  }

  pts.sort((a, b) => a.date.compareTo(b.date));
  return pts;
}

/// График пробега: ось X от 1 янв. года выпуска до последней точки; линия между точками.
class CarMileageChartCard extends StatelessWidget {
  const CarMileageChartCard({super.key, required this.car, required this.points});

  final Car car;
  final List<MileageChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final year = car.year > 1900 ? car.year : DateTime.now().year;
    final domainStart = DateTime(year, 1, 1);
    var domainEnd = points.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
    if (!domainEnd.isAfter(domainStart)) {
      domainEnd = domainStart.add(const Duration(days: 1));
    }
    var dataEnd = domainEnd.isBefore(domainStart) ? domainStart.add(const Duration(days: 1)) : domainEnd;
    // Минимум ~3 года по оси X, иначе подписи годов (2024, 2026) накладываются.
    final minXEnd = DateTime(domainStart.year + 3, 1, 1);
    var chartXEnd = dataEnd.isBefore(minXEnd) ? minXEnd : dataEnd;

    final minKm = points.map((p) => p.km).reduce(math.min);
    final maxKm = points.map((p) => p.km).reduce(math.max);
    final span = maxKm - minKm;
    final padKm = span == 0 ? math.max(50, (maxKm * 0.02).round()) : math.max(1, (span * 0.08).round());
    var yMin = (minKm - padKm).clamp(0, 1 << 30).toDouble();
    var yMax = (maxKm + padKm).toDouble();
    if (yMax <= yMin) yMax = yMin + 100;

    double xOf(DateTime d) => d.millisecondsSinceEpoch.toDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(xOf(points[i].date), points[i].km.toDouble()),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Пробег по времени',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'С $year г. по данным до ${Formatters.dateShortYearRu(dataEnd)} · тап по точке — подробности',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.palette.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: xOf(domainStart),
                maxX: xOf(chartXEnd),
                minY: yMin,
                maxY: yMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, ((yMax - yMin) / 4).roundToDouble()),
                  getDrawingHorizontalLine: (v) => FlLine(color: context.palette.border.withValues(alpha: 0.5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, m) => Text(
                        '${v.round()}',
                        style: TextStyle(fontSize: 10, color: context.palette.textTertiary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: math.max(1, (xOf(chartXEnd) - xOf(domainStart)) / 4),
                      getTitlesWidget: (v, m) {
                        final d = DateTime.fromMillisecondsSinceEpoch(v.round());
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.year}',
                            style: TextStyle(fontSize: 10, color: context.palette.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    maxContentWidth: 240,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touched) {
                      return touched.map((t) {
                        final i = t.spotIndex;
                        if (i < 0 || i >= points.length) return null;
                        final p = points[i];
                        // Две строки: встроенный tooltip узкий (maxContentWidth) —
                        // одна длинная строка ломала «213 200» на «213» / «200 км».
                        final String label;
                        if (p.isYearZeroOrigin) {
                          label = 'Точка отсчёта (год выпуска)\n0 км';
                        } else if (p.order != null) {
                          label = 'Заказ №${p.order!.orderNumber}\n${Formatters.mileage(p.km)}';
                        } else {
                          label = 'Текущий пробег\n${Formatters.mileage(p.km)}';
                        }
                        return LineTooltipItem(
                          label,
                          TextStyle(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (bar, indexes) => indexes.map((i) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: context.palette.primary, strokeWidth: 2),
                      FlDotData(
                        show: true,
                        getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                          radius: 5,
                          color: context.palette.primary,
                          strokeWidth: 2,
                          strokeColor: context.palette.cardBg,
                        ),
                      ),
                    );
                  }).toList(),
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions || response == null || response.lineBarSpots == null) return;
                    if (event is! FlTapUpEvent) return;
                    final i = response.lineBarSpots!.first.spotIndex;
                    if (i < 0 || i >= points.length) return;
                    final p = points[i];
                    if (p.order != null) {
                      pushCupertino(context, OrderDetailScreen(order: p.order!));
                    } else if (p.isYearZeroOrigin) {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.palette.cardBg,
                          title: Text('Пробег', style: TextStyle(color: context.palette.textPrimary)),
                          content: Text(
                            'Условная точка отсчёта: год выпуска ($year), пробег 0 км.',
                            style: TextStyle(color: context.palette.textSecondary),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                          ],
                        ),
                      );
                    } else {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.palette.cardBg,
                          title: Text('Пробег', style: TextStyle(color: context.palette.textPrimary)),
                          content: Text(
                            'Текущее значение в гараже: ${Formatters.mileage(p.km)} (${Formatters.dateShortYearRu(p.date)}).',
                            style: TextStyle(color: context.palette.textSecondary),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                          ],
                        ),
                      );
                    }
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.32,
                    preventCurveOverShooting: true,
                    color: context.palette.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, bar, i) => FlDotCirclePainter(
                        radius: 4,
                        color: context.palette.primary,
                        strokeWidth: 1.5,
                        strokeColor: context.palette.cardBg,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          context.palette.primary.withValues(alpha: 0.22),
                          context.palette.primary.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
