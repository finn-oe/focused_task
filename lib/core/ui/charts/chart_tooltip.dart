import 'package:material_ui/material_ui.dart';

/// One line above a chart showing the tapped value; keeps its height when empty so the chart doesn't jump.
class ChartTooltip extends StatelessWidget {
  const ChartTooltip({super.key, required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExcludeSemantics(
        child: Text(text ?? '', style: Theme.of(context).textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      ),
    );
  }
}
