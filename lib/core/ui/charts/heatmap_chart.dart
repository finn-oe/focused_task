import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/ui/charts/chart_tooltip.dart';

/// A grid of cells shaded by value (e.g. focus time by weekday × hour), in theme colours. No animations.
///
/// [values] has one list per row, all of length [columnLabels]. Tapping a cell shows `tooltip(row, column)` above it.
class HeatmapChart extends StatefulWidget {
  const HeatmapChart({super.key, required this.rowLabels, required this.columnLabels, required this.values, this.tooltip, this.cellHeight = 18, this.semanticsLabel});

  final List<String> rowLabels;

  /// One entry per column; `null` = no label for this column (e.g. only every 6th hour is labelled).
  final List<String?> columnLabels;
  final List<List<double>> values;
  final String Function(int row, int column)? tooltip;
  final double cellHeight;
  final String? semanticsLabel;

  @override
  State<HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<HeatmapChart> {
  (int, int)? _selected;

  @override
  void didUpdateWidget(HeatmapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(color: colors.onSurfaceVariant);
    final textDirection = Directionality.of(context);
    final rowLabelWidth =
        widget.rowLabels.fold(0.0, (max, label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: textDirection,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return math.max(max, width);
        }) +
        6;
    final labelHeight = (labelStyle.fontSize ?? 11) * (labelStyle.height ?? 1.4) + 4;
    final selected = _selected;

    return Semantics(
      label: widget.semanticsLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartTooltip(text: selected == null ? null : widget.tooltip?.call(selected.$1, selected.$2)),
          LayoutBuilder(
            builder: (context, constraints) {
              final layout = _HeatmapLayout(
                rowLabelWidth: rowLabelWidth,
                cellWidth: (constraints.maxWidth - rowLabelWidth) / math.max(1, widget.columnLabels.length),
                cellHeight: widget.cellHeight,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final cell = layout.cellAt(details.localPosition, rows: widget.rowLabels.length, columns: widget.columnLabels.length);
                  setState(() => _selected = cell == null || cell == _selected ? null : cell);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.rowLabels.length * widget.cellHeight + labelHeight),
                  painter: _HeatmapPainter(
                    layout: layout,
                    rowLabels: widget.rowLabels,
                    columnLabels: widget.columnLabels,
                    values: widget.values,
                    selected: selected,
                    emptyColor: colors.surfaceContainerHighest,
                    fullColor: colors.primary,
                    selectedColor: colors.onSurface,
                    labelStyle: labelStyle,
                    textDirection: textDirection,
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

class _HeatmapLayout {
  const _HeatmapLayout({required this.rowLabelWidth, required this.cellWidth, required this.cellHeight});

  final double rowLabelWidth;
  final double cellWidth;
  final double cellHeight;

  Rect cell(int row, int column) => Rect.fromLTWH(rowLabelWidth + column * cellWidth, row * cellHeight, cellWidth, cellHeight);

  (int, int)? cellAt(Offset position, {required int rows, required int columns}) {
    final column = ((position.dx - rowLabelWidth) / cellWidth).floor();
    final row = (position.dy / cellHeight).floor();
    if (column < 0 || column >= columns || row < 0 || row >= rows) return null;
    return (row, column);
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.layout,
    required this.rowLabels,
    required this.columnLabels,
    required this.values,
    required this.selected,
    required this.emptyColor,
    required this.fullColor,
    required this.selectedColor,
    required this.labelStyle,
    required this.textDirection,
  });

  final _HeatmapLayout layout;
  final List<String> rowLabels;
  final List<String?> columnLabels;
  final List<List<double>> values;
  final (int, int)? selected;
  final Color emptyColor;
  final Color fullColor;
  final Color selectedColor;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold(0.0, (max, row) => row.fold(max, math.max));
    for (var row = 0; row < rowLabels.length; row++) {
      _label(canvas, rowLabels[row], Offset(0, row * layout.cellHeight), height: layout.cellHeight);
      for (var column = 0; column < columnLabels.length; column++) {
        final value = row < values.length && column < values[row].length ? values[row][column] : 0.0;
        // A minimum shade so a little focus time is still visible.
        final color = value <= 0 || max <= 0 ? emptyColor : Color.lerp(emptyColor, fullColor, 0.2 + 0.8 * value / max)!;
        final rect = layout.cell(row, column).deflate(1);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = color);
        if (selected == (row, column)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()
              ..color = selectedColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
    final labelTop = rowLabels.length * layout.cellHeight + 2;
    for (var column = 0; column < columnLabels.length; column++) {
      final label = columnLabels[column];
      if (label != null) _label(canvas, label, Offset(layout.rowLabelWidth + column * layout.cellWidth, labelTop));
    }
  }

  void _label(Canvas canvas, String text, Offset offset, {double? height}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final dy = height == null ? 0.0 : (height - painter.height) / 2;
    painter.paint(canvas, offset.translate(0, dy));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.selected != selected ||
        oldDelegate.fullColor != fullColor ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.layout.cellWidth != layout.cellWidth;
  }
}
