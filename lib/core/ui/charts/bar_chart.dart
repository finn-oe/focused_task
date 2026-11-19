import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/ui/charts/chart_tooltip.dart';

/// One bar of a [BarChart].
class ChartBar {
  const ChartBar({required this.value, required this.label, this.tooltip, this.highlighted = false});

  /// Height of the bar in the chart's unit (e.g. minutes). Negative values are drawn as zero.
  final double value;

  /// Short axis label below the bar (e.g. "Mo", "17", "Jan"). Labels are thinned out when they don't fit.
  final String label;

  /// Shown above the chart when the bar is tapped (e.g. "Tue, Nov 17: 01:30"); also the bar's semantics label.
  final String? tooltip;

  /// Drawn in an accent colour, e.g. today.
  final bool highlighted;
}

/// A simple, dependency-free bar chart in theme colours. No animations, so tests need no settling.
///
/// Tapping a bar shows its [ChartBar.tooltip] above the chart. [referenceValue] draws a dashed line, e.g. a daily goal.
class BarChart extends StatefulWidget {
  const BarChart({super.key, required this.bars, this.height = 160, this.referenceValue, this.maxValue, this.semanticsLabel});

  final List<ChartBar> bars;

  /// Height of the bar area (labels and tooltip come on top).
  final double height;

  /// Optional dashed horizontal line (same unit as the bars).
  final double? referenceValue;

  /// Top of the scale; defaults to the largest value (or [referenceValue], if higher).
  final double? maxValue;

  /// Summary for screen readers, e.g. "Focus time per day".
  final String? semanticsLabel;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _selected;

  @override
  void didUpdateWidget(BarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.bars.length) _selected = null;
  }

  void _select(Offset position, double width) {
    if (widget.bars.isEmpty) return;
    final index = (position.dx / width * widget.bars.length).floor().clamp(0, widget.bars.length - 1);
    setState(() => _selected = _selected == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(color: colors.onSurfaceVariant);
    final selected = _selected == null ? null : widget.bars[_selected!];

    return Semantics(
      label: widget.semanticsLabel,
      // The values, for screen readers that can't see the painting.
      value: widget.bars.map((bar) => bar.tooltip).nonNulls.join(', '),
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartTooltip(text: selected?.tooltip),
          LayoutBuilder(
            builder: (context, constraints) {
              final labelHeight = (labelStyle.fontSize ?? 11) * (labelStyle.height ?? 1.4) + 6;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _select(details.localPosition, constraints.maxWidth),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height + labelHeight),
                  painter: _BarChartPainter(
                    bars: widget.bars,
                    selected: _selected,
                    barArea: widget.height,
                    referenceValue: widget.referenceValue,
                    maxValue: widget.maxValue,
                    barColor: colors.primary,
                    highlightColor: colors.tertiary,
                    selectedColor: colors.secondary,
                    trackColor: colors.surfaceContainerHighest,
                    lineColor: colors.outline,
                    labelStyle: labelStyle,
                    textDirection: Directionality.of(context),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.bars,
    required this.selected,
    required this.barArea,
    required this.referenceValue,
    required this.maxValue,
    required this.barColor,
    required this.highlightColor,
    required this.selectedColor,
    required this.trackColor,
    required this.lineColor,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<ChartBar> bars;
  final int? selected;
  final double barArea;
  final double? referenceValue;
  final double? maxValue;
  final Color barColor;
  final Color highlightColor;
  final Color selectedColor;
  final Color trackColor;
  final Color lineColor;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final slot = size.width / bars.length;
    final barWidth = math.max(2.0, math.min(slot * 0.7, 40.0));
    final top = math.max(maxValue ?? 0, math.max(referenceValue ?? 0, bars.fold(0.0, (max, bar) => math.max(max, bar.value))));

    final track = Paint()..color = trackColor;
    canvas.drawRect(Rect.fromLTWH(0, barArea - 1, size.width, 1), track);

    for (var index = 0; index < bars.length; index++) {
      final bar = bars[index];
      final height = top <= 0 ? 0.0 : (math.max(0.0, bar.value) / top) * barArea;
      if (height <= 0) continue;
      final left = slot * index + (slot - barWidth) / 2;
      final color = index == selected ? selectedColor : (bar.highlighted ? highlightColor : barColor);
      final radius = Radius.circular(math.min(4, barWidth / 2));
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(left, barArea - height, barWidth, height), topLeft: radius, topRight: radius), Paint()..color = color);
    }

    final reference = referenceValue;
    if (reference != null && top > 0) {
      final y = barArea - reference / top * barArea;
      final dash = Paint()
        ..color = lineColor
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
      }
    }

    _paintLabels(canvas, slot);
  }

  void _paintLabels(Canvas canvas, double slot) {
    final painters = [
      for (final bar in bars)
        TextPainter(
          text: TextSpan(text: bar.label, style: labelStyle),
          textDirection: textDirection,
          maxLines: 1,
        )..layout(),
    ];
    final widest = painters.fold(0.0, (max, painter) => math.max(max, painter.width));
    // Thin out labels that would overlap: every n-th label, keeping the first.
    final step = math.max(1, ((widest + 6) / slot).ceil());
    for (var index = 0; index < painters.length; index += step) {
      final painter = painters[index];
      final x = (slot * index + slot / 2 - painter.width / 2).clamp(0.0, math.max(0.0, slot * bars.length - painter.width)).toDouble();
      painter.paint(canvas, Offset(x, barArea + 4));
    }
    for (final painter in painters) {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.selected != selected ||
        oldDelegate.barArea != barArea ||
        oldDelegate.referenceValue != referenceValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.barColor != barColor ||
        oldDelegate.labelStyle != labelStyle;
  }
}
