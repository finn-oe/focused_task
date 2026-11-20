import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/ui/keyboard.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';

/// Target duration: preset chips, "Custom" (hours + minutes, up to 12 h) and "None".
class DurationPicker extends StatefulWidget {
  const DurationPicker({super.key, required this.minutes, required this.onChanged});

  final int? minutes;
  final ValueChanged<int?> onChanged;

  static const presets = [15, 25, 45, 60, 90];

  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late bool _custom = widget.minutes != null && !DurationPicker.presets.contains(widget.minutes);
  late final _hours = TextEditingController(text: _custom ? '${widget.minutes! ~/ 60}' : '');
  late final _minutes = TextEditingController(text: _custom ? '${widget.minutes! % 60}' : '');

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  int get _customTotal => (int.tryParse(_hours.text) ?? 0) * 60 + (int.tryParse(_minutes.text) ?? 0);

  void _select(int? minutes) {
    setState(() => _custom = false);
    widget.onChanged(minutes);
  }

  void _selectCustom() {
    setState(() => _custom = true);
    final current = widget.minutes;
    if (current != null) {
      _hours.text = '${current ~/ 60}';
      _minutes.text = '${current % 60}';
    }
  }

  void _customChanged() {
    final total = _customTotal;
    setState(() {});
    widget.onChanged(total == 0 ? null : total.clamp(1, TaskDraft.maxTargetMinutes));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tooLong = _custom && _customTotal > TaskDraft.maxTargetMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(label: Text(l10n.taskFormDurationNone), selected: !_custom && widget.minutes == null, onSelected: (_) => _select(null)),
            for (final preset in DurationPicker.presets)
              ChoiceChip(label: Text(l10n.commonMinutes(preset)), selected: !_custom && widget.minutes == preset, onSelected: (_) => _select(preset)),
            ChoiceChip(label: Text(l10n.taskFormDurationCustom), selected: _custom, onSelected: (_) => _selectCustom()),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  onTapOutside: unfocusOnTapOutside,
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: InputDecoration(labelText: l10n.taskFormHours, border: const OutlineInputBorder(), errorText: tooLong ? l10n.taskFormDurationMax : null),
                  onChanged: (_) => _customChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  onTapOutside: unfocusOnTapOutside,
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: InputDecoration(labelText: l10n.taskFormMinutes, border: const OutlineInputBorder()),
                  onChanged: (_) => _customChanged(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
