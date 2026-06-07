import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Виджет одного вопроса в режиме прохождения опроса.
///
/// A11y-договорённости (важно при дальнейших правках):
///   • Заголовок вопроса оборачивается в `Semantics(header: true)` с явной
///     меткой, включающей «Обязательный вопрос». Визуальная звёздочка `*`
///     помечена `excludeSemantics: true` — иначе screen reader говорит
///     неинформативное «звёздочка».
///   • Текстовые поля используют `Semantics(label: q.title, textField: true)`
///     вместо `labelText:` декорации, чтобы:
///       (а) не дублировать заголовок визуально (он уже выведен выше);
///       (б) NVDA читал именно текст вопроса как имя поля даже после ввода
///           первой буквы (hintText исчезает при наборе).
///   • Slider получает `semanticFormatterCallback` — иначе озвучивается
///     просто «3.0», без контекста «из 5».
///   • `section_header` — `Semantics(header: true)` для правильного навигейта
///     по заголовкам (NVDA нажимает «h» — прыгает между заголовками).
class QuestionRenderer extends StatelessWidget {
  final Question question;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const QuestionRenderer(
      {super.key,
      required this.question,
      required this.value,
      required this.onChanged});

  void _set(dynamic v) => onChanged({'value': v});

  /// Подпись, которую screen reader зачитывает для всего вопроса целиком:
  /// текст вопроса плюс пометка про обязательность. Сюда же можно потом
  /// добавлять description, если решим, что её надо подмешивать
  /// в одно семантическое поле.
  String _accessibleLabel(Question q) {
    final base = q.title.isEmpty ? 'Вопрос без названия' : q.title;
    return q.required ? '$base. Обязательный вопрос' : base;
  }

  @override
  Widget build(BuildContext context) {
    final q = question;
    final isHeader = q.type == QuestionType.section_header;

    // section_header — это отдельный «разделитель», не вопрос с ответом.
    // Помечаем как header в semantic tree, чтобы по нему можно было прыгать
    // навигацией «h» в NVDA / «rotor: headings» в VoiceOver.
    if (isHeader) {
      return Semantics(
        header: true,
        child: Text(
          q.title.isEmpty ? '(без названия)' : q.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: HseColors.primary,
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Заголовок: один семантический узел, который соединяет «текст вопроса
      // + статус обязательности». excludeSemantics: true прячет дочерние
      // Text-узлы от screen reader'a, чтобы он не повторял текст дважды
      // и не озвучивал «звёздочку».
      Semantics(
        header: true,
        label: _accessibleLabel(q),
        excludeSemantics: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(
            q.title.isEmpty ? '(без названия)' : q.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          )),
          if (q.required)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('*',
                  style: TextStyle(
                      color: HseColors.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
      if (q.description != null && q.description!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(q.description!,
              style: const TextStyle(color: HseColors.muted, fontSize: 13)),
        ),
      const SizedBox(height: 12),
      _input(context, q),
    ]);
  }

  Widget _input(BuildContext context, Question q) {
    final v = value?['value'];
    switch (q.type) {
      case QuestionType.section_header:
        // Не должно дойти — section_header перехватывается выше.
        return const SizedBox.shrink();
      case QuestionType.short_text:
      case QuestionType.long_text:
        // Semantics-обёртка с label=q.title даёт screen reader'у имя
        // поля даже после ввода первой буквы. textField:true помечает
        // как редактируемое (NVDA озвучит «редактор: текст вопроса»).
        return Semantics(
          textField: true,
          label: _accessibleLabel(q),
          child: TextFormField(
            initialValue: v?.toString() ?? '',
            maxLines: q.type == QuestionType.long_text ? 4 : 1,
            decoration: const InputDecoration(hintText: 'Ваш ответ'),
            onChanged: _set,
          ),
        );
      case QuestionType.single_choice:
        return Semantics(
          // container:true + label делает группу радио-кнопок одним
          // блоком, который NVDA анонсирует целиком: «Текст вопроса.
          // Группа переключателей, 4 элемента».
          container: true,
          label: _accessibleLabel(q),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final o in q.options)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: o.value,
                groupValue: v?.toString(),
                activeColor: HseColors.primary,
                title: Text(o.label),
                onChanged: (val) => _set(val),
              ),
          ]),
        );
      case QuestionType.dropdown:
        return Semantics(
          label: _accessibleLabel(q),
          child: DropdownButtonFormField<String>(
            value: v?.toString(),
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Выберите…'),
            items: q.options
                .map((o) =>
                    DropdownMenuItem(value: o.value, child: Text(o.label)))
                .toList(),
            onChanged: (val) => _set(val),
          ),
        );
      case QuestionType.multiple_choice:
        final cur = (v as List?)?.cast<String>() ?? <String>[];
        return Semantics(
          container: true,
          label: _accessibleLabel(q),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final o in q.options)
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
                  _set(next);
                },
              ),
          ]),
        );
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
        return Semantics(
          container: true,
          label: _accessibleLabel(q),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (showBounds)
                Text('$mn',
                    style: const TextStyle(
                        color: HseColors.muted, fontWeight: FontWeight.w600)),
              Expanded(
                  child: Slider(
                value: cur.clamp(mn.toDouble(), mx.toDouble()),
                min: mn.toDouble(),
                max: mx.toDouble(),
                divisions: showTicks ? (mx - mn) : null,
                label: showValue ? cur.toInt().toString() : null,
                activeColor: HseColors.primary,
                // semanticFormatterCallback — то, что зачитывает screen
                // reader при изменении значения. Без него озвучивается
                // просто «3.0» — непонятно «из чего». Даём контекст:
                // текущее значение, нижнюю и верхнюю границы.
                semanticFormatterCallback: (val) =>
                    'Оценка ${val.toInt()} из $mx, минимум $mn',
                onChangeStart: (d) => _set(d.toInt()),
                onChanged: (d) => _set(d.toInt()),
              )),
              if (showBounds)
                Text('$mx',
                    style: const TextStyle(
                        color: HseColors.muted, fontWeight: FontWeight.w600)),
            ]),
            if (showValue && v != null)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: HseColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(999)),
                  // Сам бейдж со значением — чисто визуальный дубликат
                  // того, что Slider уже озвучил. Прячем от screen reader'а,
                  // чтобы не было «3» «три» «три» подряд.
                  child: ExcludeSemantics(
                    child: Text('${(v as num).toInt()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: HseColors.primary,
                            fontSize: 16)),
                  ),
                ),
              ),
          ]),
        );
    }
  }
}
