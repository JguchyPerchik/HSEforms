import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class QuestionRenderer extends StatelessWidget {
  final Question question;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const QuestionRenderer({super.key, required this.question, required this.value, required this.onChanged});

  void _set(dynamic v) => onChanged({'value': v});

  @override
  Widget build(BuildContext context) {
    final q = question;
    final isHeader = q.type == QuestionType.section_header;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(
          q.title.isEmpty ? '(без названия)' : q.title,
          style: TextStyle(
            fontSize: isHeader ? 20 : 16,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
            color: isHeader ? HseColors.primary : Colors.black87,
          ),
        )),
        if (q.required) const Padding(
          padding: EdgeInsets.only(left: 6),
          child: Text('*', style: TextStyle(color: HseColors.danger, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ]),
      if (q.description != null && q.description!.isNotEmpty) Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(q.description!, style: const TextStyle(color: HseColors.muted, fontSize: 13)),
      ),
      const SizedBox(height: 12),
      _input(context, q),
    ]);
  }

  Widget _input(BuildContext context, Question q) {
    final v = value?['value'];
    switch (q.type) {
      case QuestionType.section_header:
        return const SizedBox.shrink();
      case QuestionType.short_text:
      // case QuestionType.email:
      //   return TextFormField(
      //     initialValue: v?.toString() ?? '',
      //     keyboardType: q.type == QuestionType.email ? TextInputType.emailAddress : TextInputType.text,
      //     decoration: const InputDecoration(hintText: 'Ваш ответ'),
      //     onChanged: _set,
      //   );
      case QuestionType.long_text:
        return TextFormField(
          initialValue: v?.toString() ?? '',
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Ваш ответ'),
          onChanged: _set,
        );
      // case QuestionType.number:
      //   return TextFormField(
      //     initialValue: v?.toString() ?? '',
      //     keyboardType: TextInputType.number,
      //     decoration: const InputDecoration(hintText: '0'),
      //     onChanged: (s) => _set(double.tryParse(s)),
      //   );
      // case QuestionType.date:
      //   return OutlinedButton.icon(
      //     icon: const Icon(Icons.calendar_today, size: 18),
      //     label: Text(v?.toString() ?? 'Выбрать дату'),
      //     onPressed: () async {
      //       final d = await showDatePicker(
      //         context: context, initialDate: DateTime.now(),
      //         firstDate: DateTime(1900), lastDate: DateTime(2100),
      //       );
      //       if (d != null) _set('${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      //     },
      //   );
      case QuestionType.single_choice:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final o in q.options) RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: o.value, groupValue: v?.toString(),
            activeColor: HseColors.primary,
            title: Text(o.label),
            onChanged: (val) => _set(val),
          ),
        ]);
      case QuestionType.dropdown:
        return DropdownButtonFormField<String>(
          value: v?.toString(),
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Выберите…'),
          items: q.options.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))).toList(),
          onChanged: (val) => _set(val),
        );
      case QuestionType.multiple_choice:
        final cur = (v as List?)?.cast<String>() ?? <String>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final o in q.options) CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: cur.contains(o.value),
            activeColor: HseColors.primary,
            title: Text(o.label),
            onChanged: (sel) {
              final next = List<String>.from(cur);
              if (sel == true) { if (!next.contains(o.value)) next.add(o.value); }
              else { next.remove(o.value); }
              _set(next);
            },
          ),
        ]);
      case QuestionType.scale:
        final mnRaw = q.config['min'];
        final mxRaw = q.config['max'];
        int mn = (mnRaw is int) ? mnRaw : ((mnRaw is num) ? mnRaw.toInt() : 1);
        int mx = (mxRaw is int) ? mxRaw : ((mxRaw is num) ? mxRaw.toInt() : 5);
        if (mx <= mn) mx = mn + 1; // safety
        final showTicks = q.config['show_ticks'] != false;
        final showValue = q.config['show_value'] != false;
        final showBounds = q.config['show_bounds'] != false;
        final cur = (v is num) ? v.toDouble() : mn.toDouble();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (showBounds) Text('$mn', style: const TextStyle(color: HseColors.muted, fontWeight: FontWeight.w600)),
            Expanded(child: Slider(
              value: cur.clamp(mn.toDouble(), mx.toDouble()),
              min: mn.toDouble(), max: mx.toDouble(),
              divisions: showTicks ? (mx - mn) : null,
              label: showValue ? cur.toInt().toString() : null,
              activeColor: HseColors.primary,
              onChanged: (d) => _set(d.toInt()),
            )),
            if (showBounds) Text('$mx', style: const TextStyle(color: HseColors.muted, fontWeight: FontWeight.w600)),
          ]),
          if (showValue && v != null) Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: HseColors.surfaceAlt, borderRadius: BorderRadius.circular(999)),
              child: Text('${(v as num).toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: HseColors.primary, fontSize: 16)),
            ),
          ),
        ]);
      // case QuestionType.rating:
      //   final cur = (v is num) ? v.toInt() : 0;
      //   return Row(children: List.generate(5, (i) => IconButton(
      //     icon: Icon(i < cur ? Icons.star : Icons.star_border, color: HseColors.secondary, size: 32),
      //     onPressed: () => _set(i + 1),
      //   )));
    }
  }
}
