import 'package:material_ui/material_ui.dart';

/// A small ring that fills with [progress] (0–1) and shows a check mark once [done]. Used for the daily goal and the
/// completion of a category on the board.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, required this.done, this.size = 28, this.color});

  final double progress;
  final bool done;
  final double size;

  /// Colour of the filled part and the check mark; the theme's primary colour by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = color ?? colors.primary;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(value: done ? 1 : progress.clamp(0, 1), strokeWidth: size / 8, color: fill, backgroundColor: colors.surfaceContainerHighest),
          ),
          if (done) Icon(Icons.check, size: size * 0.55, color: fill),
        ],
      ),
    );
  }
}
