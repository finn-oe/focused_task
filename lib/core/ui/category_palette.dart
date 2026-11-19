import 'package:material_ui/material_ui.dart';

import 'package:focused_task/features/categories/domain/task_category.dart';

/// The fixed palette of category colours. A category stores only the index ([TaskCategory.colorIndex]).
///
/// Each entry is a seed hue; the colours shown are the `primary` / `primaryContainer` roles of a [ColorScheme] seeded
/// with it for the current brightness, so they have Material contrast in light and dark mode and fit the app's tones.
enum CategoryColor {
  red(Color(0xFFE53935)),
  orange(Color(0xFFFB8C00)),
  yellow(Color(0xFFFDD835)),
  green(Color(0xFF43A047)),
  teal(Color(0xFF00897B)),
  cyan(Color(0xFF00ACC1)),
  blue(Color(0xFF1E88E5)),
  indigo(Color(0xFF3949AB)),
  purple(Color(0xFF8E24AA)),
  pink(Color(0xFFD81B60));

  const CategoryColor(this._seed);

  final Color _seed;

  /// The palette entry for a stored index; unknown indexes (e.g. from a newer version) wrap around.
  static CategoryColor of(int index) => values[index % values.length];

  static final Map<(CategoryColor, Brightness), ColorScheme> _schemes = {};

  ColorScheme _scheme(Brightness brightness) {
    return _schemes.putIfAbsent((this, brightness), () => ColorScheme.fromSeed(seedColor: _seed, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.fidelity));
  }

  /// Strong colour for dots, bars and borders.
  Color color(BuildContext context) => _scheme(Theme.of(context).brightness).primary;

  /// Icons and text on [color].
  Color onColor(BuildContext context) => _scheme(Theme.of(context).brightness).onPrimary;

  /// Soft background, e.g. of a board column header, with [onContainer] for text on it.
  Color container(BuildContext context) => _scheme(Theme.of(context).brightness).primaryContainer;

  Color onContainer(BuildContext context) => _scheme(Theme.of(context).brightness).onPrimaryContainer;
}

/// Small coloured dot for a category.
class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.colorIndex, this.size = 10});

  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: CategoryColor.of(colorIndex).color(context), shape: BoxShape.circle),
    );
  }
}
