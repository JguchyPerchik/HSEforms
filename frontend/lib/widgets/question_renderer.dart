import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

// Sentinel значение, идентифицирующее вариант «Другое».
// Должно совпадать со значением, которое OptionsEditor записывает
// в option.value при добавлении варианта «Другое».
const _kOther = '__other__';

class QuestionRenderer extends StatelessWidget {
  final Question question;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const QuestionRenderer({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
  });

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
      case QuestionType.long_text:
        return TextFormField(
          initialValue: v?.toString() ?? '',
          maxLines: q.type == QuestionType.long_text ? 4 : 1,
          decoration: const InputDecoration(hintText: 'Ваш ответ'),
          onChanged: _set,
        );

      // ── ОДИН ВАРИАНТ ───────────────────────────────────────────────────
      case QuestionType.single_choice:
        final selectedValue = v?.toString();
        // other_text сохраняется в том же map-е ответа, чтобы не терять
        // текст при повторных перестройках виджета.
        final otherText = (value?['other_text'] as String?) ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final o in q.options) ...[
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: o.value,
                groupValue: selectedValue,
                activeColor: HseColors.primary,
                title: Text(o.label),
                onChanged: (val) {
                  if (val == _kOther) {
                    // Выбираем «Другое»: сохраняем уже набранный текст
                    onChanged({'value': _kOther, 'other_text': otherText});
                  } else {
                    // Переключаемся на обычный вариант: стираем other_text
                    onChanged({'value': val});
                  }
                },
              ),
              // Текстовое поле появляется только пока выбрано «Другое»
              if (o.value == _kOther && selectedValue == _kOther)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
                  child: _OtherTextField(
                    key: const ValueKey('other-single'),
                    initialValue: otherText,
                    onChanged: (text) =>
                        onChanged({'value': _kOther, 'other_text': text}),
                  ),
                ),
            ],
          ],
        );

      // ── НЕСКОЛЬКО ВАРИАНТОВ ────────────────────────────────────────────
      case QuestionType.multiple_choice:
        final cur = (v as List?)?.cast<String>() ?? <String>[];
        final otherText = (value?['other_text'] as String?) ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final o in q.options) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: cur.contains(o.value),
                activeColor: HseColors.primary,
                title: Text(o.label),
                onChanged: (sel) {
                  final next = List<String>.from(cur);
                  if (sel == true) {
                    if (!next.contains(o.value)) next.add(o.value);
                  } else {
                    next.remove(o.value);
                  }
                  if (next.contains(_kOther)) {
                    // «Другое» всё ещё отмечено — сохраняем текст
                    onChanged({'value': next, 'other_text': otherText});
                  } else {
                    // Галочка «Другое» снята — стираем текст
                    onChanged({'value': next});
                  }
                },
              ),
              // Текстовое поле появляется только пока стоит галочка «Другое»
              if (o.value == _kOther && cur.contains(_kOther))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
                  child: _OtherTextField(
                    key: const ValueKey('other-multi'),
                    initialValue: otherText,
                    onChanged: (text) =>
                        onChanged({'value': cur, 'other_text': text}),
                  ),
                ),
            ],
          ],
        );

      case QuestionType.dropdown:
        return DropdownButtonFormField<String>(
          value: v?.toString(),
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Выберите…'),
          items: q.options
              .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
              .toList(),
          onChanged: (val) => _set(val),
        );

      case QuestionType.scale:
        final mnRaw = q.config['min'];
        final mxRaw = q.config['max'];
        int mn = (mnRaw is int) ? mnRaw : ((mnRaw is num) ? mnRaw.toInt() : 1);
        int mx = (mxRaw is int) ? mxRaw : ((mxRaw is num) ? mxRaw.toInt() : 5);
        if (mx <= mn) mx = mn + 1;
        final showTicks = q.config['show_ticks'] != false;
        final showValue = q.config['show_value'] != false;
        final showBounds = q.config['show_bounds'] != false;
        final cur = (v is num) ? v.toDouble() : mn.toDouble();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (showBounds)
              Text('$mn', style: const TextStyle(color: HseColors.muted, fontWeight: FontWeight.w600)),
            Expanded(child: Slider(
              value: cur.clamp(mn.toDouble(), mx.toDouble()),
              min: mn.toDouble(), max: mx.toDouble(),
              divisions: showTicks ? (mx - mn) : null,
              label: showValue ? cur.toInt().toString() : null,
              activeColor: HseColors.primary,
              onChanged: (d) => _set(d.toInt()),
            )),
            if (showBounds)
              Text('$mx', style: const TextStyle(color: HseColors.muted, fontWeight: FontWeight.w600)),
          ]),
          if (showValue && v != null) Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: HseColors.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${(v as num).toInt()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: HseColors.primary, fontSize: 16)),
            ),
          ),
        ]);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateful-виджет для текстового поля «Другое».
//
// Почему StatefulWidget, а не initialValue в TextFormField?
// Потому что QuestionRenderer — StatelessWidget. Каждый вызов onChanged
// провоцирует setState в родителе → перестройку QuestionRenderer → пересоздание
// дерева виджетов. TextFormField с initialValue при этом сбрасывает курсор
// в позицию 0. StatefulWidget с собственным контроллером сохраняет State
// (и позицию курсора) между перестройками родителя, т. к. Flutter
// сопоставляет StateFullWidget'ы по runtimeType + key и переиспользует
// существующий State вместо создания нового.
// ─────────────────────────────────────────────────────────────────────────────

class _OtherTextField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _OtherTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_OtherTextField> createState() => _OtherTextFieldState();
}

class _OtherTextFieldState extends State<_OtherTextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      autofocus: true,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Введите свой вариант…',
        filled: true,
        fillColor: HseColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: HseColors.primaryBright, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: HseColors.primaryBright, width: 1.5),
        ),
      ),
      textCapitalization: TextCapitalization.sentences,
      onChanged: widget.onChanged,
    );
  }
}