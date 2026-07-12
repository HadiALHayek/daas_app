import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';

class DaySessionEdit {
  const DaySessionEdit({required this.cleared, this.start, this.end});
  final bool cleared;
  final TimeOfDay? start;
  final TimeOfDay? end;
}

/// Dialog to set an employee's clock-in / clock-out for a specific day.
/// Returns a [DaySessionEdit] on save, or null if cancelled.
Future<DaySessionEdit?> showDaySessionEditDialog(
  BuildContext context, {
  required String employeeName,
  required DateTime day,
  TimeOfDay? initialStart,
  TimeOfDay? initialEnd,
}) {
  return showDialog<DaySessionEdit>(
    context: context,
    builder: (_) => _DaySessionEditDialog(
      employeeName: employeeName,
      day: day,
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

class _DaySessionEditDialog extends StatefulWidget {
  const _DaySessionEditDialog({
    required this.employeeName,
    required this.day,
    this.initialStart,
    this.initialEnd,
  });

  final String employeeName;
  final DateTime day;
  final TimeOfDay? initialStart;
  final TimeOfDay? initialEnd;

  @override
  State<_DaySessionEditDialog> createState() => _DaySessionEditDialogState();
}

class _DaySessionEditDialogState extends State<_DaySessionEditDialog> {
  TimeOfDay? _start;
  TimeOfDay? _end;
  String? _error;

  final _dateFormat = DateFormat('EEEE، yyyy/MM/dd', 'ar');

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  String _fmt(TimeOfDay? t) {
    if (t == null) return StringsAr.notRecorded;
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('hh:mm a', 'ar').format(dt);
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ??
          TimeOfDay(hour: isStart ? 8 : 17, minute: 0),
      helpText: isStart ? StringsAr.checkIn : StringsAr.checkOut,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  void _save() {
    if (_start == null || _end == null) {
      setState(() => _error = 'حدّد وقت الحضور والانصراف');
      return;
    }
    final startMin = _start!.hour * 60 + _start!.minute;
    final endMin = _end!.hour * 60 + _end!.minute;
    if (endMin <= startMin) {
      setState(() => _error = StringsAr.departureBeforeArrival);
      return;
    }
    Navigator.pop(context, DaySessionEdit(cleared: false, start: _start, end: _end));
  }

  Widget _timeRow(String label, TimeOfDay? value, bool isStart) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(isStart),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(_fmt(value)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${StringsAr.editDay} - ${widget.employeeName}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateFormat.format(widget.day),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _timeRow(StringsAr.checkIn, _start, true),
          _timeRow(StringsAr.checkOut, _end, false),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.pop(context, const DaySessionEdit(cleared: true)),
              icon: const Icon(Icons.person_off_outlined,
                  size: 18, color: AppColors.error),
              label: const Text(StringsAr.clearDay,
                  style: TextStyle(color: AppColors.error)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(StringsAr.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text(StringsAr.save),
        ),
      ],
    );
  }
}
