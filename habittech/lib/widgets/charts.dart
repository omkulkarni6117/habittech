import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// One bar. [value] is in the same units as the chart's `maxValue`; a null
/// value means "no data" and draws an empty track.
class BarDatum {
  const BarDatum({
    required this.label,
    this.value,
    this.valueText,
    this.highlight = false,
  });

  final String label;
  final double? value;
  final String? valueText;
  final bool highlight;
}

/// Simple responsive bar chart with optional goal line.
class BarChartView extends StatelessWidget {
  const BarChartView({
    super.key,
    required this.data,
    this.maxValue = 1,
    this.height = 150,
    this.goal,
    this.goalLabel,
    required this.semanticsSummary,
  });

  final List<BarDatum> data;
  final double maxValue;
  final double height;
  final double? goal;
  final String? goalLabel;
  final String semanticsSummary;

  static const double _valueLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final barArea = height - _valueLabelHeight;
    final duration = motionDuration(context, 450);

    Widget bar(BarDatum d) {
      final v = d.value;
      final target =
          v == null ? 0.0 : (v / maxValue).clamp(0.0, 1.0).toDouble();
      final color = v == null
          ? c.border
          : (d.highlight ? c.primaryStrong : c.primary);
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: _valueLabelHeight,
              child: Center(
                child: Text(
                  v == null ? '-' : (d.valueText ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 10.5, color: c.textSecondary),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: target),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, f, _) => Container(
                height: math.max(f * barArea, 4.0),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final goalValue = goal;
    return Semantics(
      label: semanticsSummary,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final d in data) bar(d)],
                  ),
                  if (goalValue != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom:
                          (goalValue / maxValue).clamp(0.0, 1.0).toDouble() *
                              barArea,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: c.warning,
                            ),
                          ),
                          if (goalLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                goalLabel!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final d in data)
                  Expanded(
                    child: Text(
                      d.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: d.highlight ? c.text : c.textSecondary,
                        fontWeight:
                            d.highlight ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TrendPoint {
  const TrendPoint({required this.label, this.value});
  final String label;

  /// 0..1, or null when there is no data for the point.
  final double? value;
}

/// Line chart for values between 0 and 1 (shown as percentages).
class LineChartView extends StatelessWidget {
  const LineChartView({
    super.key,
    required this.points,
    this.height = 150,
    required this.semanticsSummary,
  });

  final List<TrendPoint> points;
  final double height;
  final String semanticsSummary;

  static const double _axisWidth = 36;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      label: semanticsSummary,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _LinePainter(
                  points: points,
                  axisWidth: _axisWidth,
                  line: c.primaryStrong,
                  grid: c.border,
                  text: c.textSecondary,
                  dotFill: c.primaryStrong,
                  dotRing: c.card,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: _axisWidth),
              child: Row(
                children: [
                  for (final p in points)
                    Expanded(
                      child: Text(
                        p.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.axisWidth,
    required this.line,
    required this.grid,
    required this.text,
    required this.dotFill,
    required this.dotRing,
  });

  final List<TrendPoint> points;
  final double axisWidth;
  final Color line;
  final Color grid;
  final Color text;
  final Color dotFill;
  final Color dotRing;

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 8.0;
    const bottomPad = 6.0;
    final plotHeight = size.height - topPad - bottomPad;
    final plotWidth = size.width - axisWidth;
    if (plotHeight <= 0 || plotWidth <= 0 || points.isEmpty) return;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (final level in const [0.0, 0.5, 1.0]) {
      final y = topPad + (1 - level) * plotHeight;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${(level * 100).round()}%',
          style: TextStyle(fontSize: 10, color: text),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final slot = plotWidth / points.length;
    Offset? pointAt(int i) {
      final v = points[i].value;
      if (v == null) return null;
      final clamped = v.clamp(0.0, 1.0).toDouble();
      return Offset(
        axisWidth + (i + 0.5) * slot,
        topPad + (1 - clamped) * plotHeight,
      );
    }

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw each unbroken run of data as its own path.
    Path? run;
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (p == null) {
        if (run != null) canvas.drawPath(run, linePaint);
        run = null;
        continue;
      }
      if (run == null) {
        run = Path()..moveTo(p.dx, p.dy);
      } else {
        run.lineTo(p.dx, p.dy);
      }
    }
    if (run != null) canvas.drawPath(run, linePaint);

    final ring = Paint()..color = dotRing;
    final fill = Paint()..color = dotFill;
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (p == null) continue;
      canvas.drawCircle(p, 6, ring);
      canvas.drawCircle(p, 4, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points ||
      old.line != line ||
      old.grid != grid ||
      old.text != text;
}

/// GitHub-style calendar heatmap. `weeks[w][row]` is a 0..1 completion rate
/// or null (nothing scheduled / future); rows follow the week-start setting.
class HeatmapView extends StatelessWidget {
  const HeatmapView({
    super.key,
    required this.weeks,
    required this.rowLabels,
    required this.semanticsSummary,
  });

  final List<List<double?>> weeks;
  final List<String> rowLabels;
  final String semanticsSummary;

  static Color levelColor(HabitColors c, double v) {
    if (v <= 0) return c.primarySoft;
    return Color.lerp(c.primarySoft, c.primaryStrong, 0.3 + 0.7 * v)!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    const labelWidth = 20.0;
    const gap = 3.0;
    return Semantics(
      label: semanticsSummary,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final n = weeks.isEmpty ? 1 : weeks.length;
            final cell = math.max(
              6.0,
              math.min(26.0, (constraints.maxWidth - labelWidth - gap * n) / n),
            );
            Widget swatch(double v) => Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: levelColor(c, v),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        for (final label in rowLabels)
                          SizedBox(
                            width: labelWidth,
                            height: cell + gap,
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                    fontSize: 10, color: c.textSecondary),
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final week in weeks)
                      Column(
                        children: [
                          for (final v in week)
                            Container(
                              width: cell,
                              height: cell,
                              margin: const EdgeInsets.only(left: gap, bottom: gap),
                              decoration: BoxDecoration(
                                color: v == null
                                    ? Colors.transparent
                                    : levelColor(c, v),
                                borderRadius: BorderRadius.circular(cell * 0.25),
                                border: v == null
                                    ? Border.all(color: c.border)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Less',
                        style:
                            TextStyle(fontSize: 11, color: c.textSecondary)),
                    const SizedBox(width: 4),
                    swatch(0),
                    swatch(0.25),
                    swatch(0.5),
                    swatch(0.75),
                    swatch(1),
                    const SizedBox(width: 4),
                    Text('More',
                        style:
                            TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
