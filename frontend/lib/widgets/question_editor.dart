import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'condition_editor.dart';

class QuestionEditor extends StatelessWidget {
  final int index;
  final Question question;
  final List<Question> availableTriggers;
  final bool expanded;
  final VoidCallback onTap;
  final void Function(Question) onChanged;
  final VoidCallback onSave;
  final Future<void> Function() onDelete;
  final VoidCallback? onTogglePageBreak;

  const QuestionEditor({
    super.key,
    required this.index,
    required this.question,
    required this.availableTriggers,
    required this.expanded,
    required this.onTap,
    required this.onChanged,
    required this.onSave,
    required this.onDelete,
    required this.onTogglePageBreak,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final hasVariants = q.readVariants().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (index > 0)
        PageBreakRail(
          active: q.pageBreakBefore,
          onToggle: onTogglePageBreak ?? () {},
        ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HseRadius.lg),
          boxShadow: expanded ? HseShadows.lift : HseShadows.card,
          border: Border.all(
            color: expanded
                ? HseColors.primary.withOpacity(0.25)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.drag_indicator_rounded,
                      color: HseColors.muted.withOpacity(0.7)),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HseColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HseColors.primary,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(HseRadius.sm),
                  onTap: onTap,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.title.isEmpty ? 'Без заголовка' : q.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: q.title.isEmpty
                                  ? HseColors.muted
                                  : HseColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            _Tag(
                                text: q.type.human,
                                color: HseColors.surfaceAlt,
                                fg: HseColors.primary),
                            if (q.required)
                              const _Tag(
                                  text: 'обязательный',
                                  color: Color(0x1AE05656),
                                  fg: HseColors.danger),
                            if (q.displayCondition != null)
                              const _Tag(
                                  text: 'условие',
                                  color: Color(0x1A234B9B),
                                  fg: HseColors.primaryBright),
                            if (hasVariants)
                              _Tag(
                                  text: 'A/B (${q.readVariants().length + 1})',
                                  color: const Color(0x1A2E9D6E),
                                  fg: HseColors.success),
                          ]),
                        ]),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Удалить',
                color: HseColors.muted,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Удалить вопрос?'),
                      content: const Text('Это действие нельзя отменить.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Отмена')),
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: HseColors.danger),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await onDelete();
                },
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.expand_more_rounded, color: HseColors.muted),
              ),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _ExpandedBody(
                      key: ValueKey('body-${q.id}'),
                      q: q,
                      availableTriggers: availableTriggers,
                      onChanged: onChanged,
                      onSave: onSave,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PAGE BREAK SEPARATOR
// ─────────────────────────────────────────────────────────────────────────

class PageBreakRail extends StatefulWidget {
  final bool active;
  final VoidCallback onToggle;
  const PageBreakRail(
      {super.key, required this.active, required this.onToggle});
  @override
  State<PageBreakRail> createState() => _PageBreakRailState();
}

class _PageBreakRailState extends State<PageBreakRail> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Expanded(child: _DashedLine(color: HseColors.primaryBright)),
          const SizedBox(width: 10),
          Material(
            color: HseColors.primary,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.insert_page_break_rounded,
                      size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Разделитель страницы',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  SizedBox(width: 6),
                  Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: _DashedLine(color: HseColors.primaryBright)),
        ]),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 28,
          alignment: Alignment.center,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _hover ? 1.0 : 0.0,
            child: Row(children: [
              Expanded(
                  child: _DashedLine(color: HseColors.muted.withOpacity(0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: HseColors.borderStrong),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.add_rounded,
                        size: 14, color: HseColors.primaryBright),
                    SizedBox(width: 4),
                    Text('Разделитель страницы',
                        style: TextStyle(
                            color: HseColors.primaryBright,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ]),
                ),
              ),
              Expanded(
                  child: _DashedLine(color: HseColors.muted.withOpacity(0.5))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(double.infinity, 1), painter: _DashedLinePainter(color));
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 5.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final Color fg;
  const _Tag({required this.text, required this.color, required this.fg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// EXPANDED BODY
// ─────────────────────────────────────────────────────────────────────────

class _ExpandedBody extends StatefulWidget {
  final Question q;
  final List<Question> availableTriggers;
  final void Function(Question) onChanged;
  final VoidCallback onSave;
  const _ExpandedBody(
      {super.key,
      required this.q,
      required this.availableTriggers,
      required this.onChanged,
      required this.onSave});
  @override
  State<_ExpandedBody> createState() => _ExpandedBodyState();
}

class _ExpandedBodyState extends State<_ExpandedBody> {
  void _commit() {
    widget.onChanged(widget.q);
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(height: 1),
      const SizedBox(height: 18),
      // Variants pager handles BOTH the empty case (just inline original editor +
      // "make experiment" CTA) and the pager case (original at page 0 + variants).
      VariantsPager(
        key: ValueKey('var-${q.id}'),
        q: q,
        onChanged: _commit,
      ),
      const SizedBox(height: 14),
      // Common controls — apply to all variants of this question.
      Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: HseColors.surface,
          borderRadius: BorderRadius.circular(HseRadius.md),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text('ОБЩИЕ НАСТРОЙКИ',
                style: TextStyle(
                    color: HseColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
          ),
          const Text(
            'Применяются ко всем вариантам ниже.',
            style: TextStyle(color: HseColors.inkSoft, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 18, runSpacing: 4, children: [
            _toggle('Обязательный', q.required, (v) {
              q.required = v;
              _commit();
            }),
          ]),
          const SizedBox(height: 8),
          if (widget.availableTriggers.isEmpty && q.displayCondition == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Условную логику можно добавить, если перед вопросом есть «Разделитель страницы».',
                style: TextStyle(
                    color: HseColors.muted, fontSize: 12.5, height: 1.4),
              ),
            )
          else
            ConditionEditor(
              question: q,
              previousQuestions: widget.availableTriggers,
              onChanged: (cond) {
                q.displayCondition = cond;
                _commit();
              },
            ),
        ]),
      ),
    ]);
  }

  Widget _toggle(String label, bool v, ValueChanged<bool> on) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(value: v, onChanged: on),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────
// SLOT — unifies "original Question" and "variant" so one page editor
// can handle both with the same UI.
// ─────────────────────────────────────────────────────────────────────────

class _Slot {
  final Question q;
  final QuestionVariant? v; // null = editing the original question itself
  _Slot.original(this.q) : v = null;
  _Slot.variant(this.q, QuestionVariant variant) : v = variant;

  bool get isOriginal => v == null;

  QuestionType get type => v?.type ?? q.type;
  set type(QuestionType t) {
    if (v != null) {
      v!.type = t;
    } else {
      q.type = t;
    }
  }

  String get title => v?.title ?? q.title;
  set title(String t) {
    if (v != null) {
      v!.title = t;
    } else {
      q.title = t;
    }
  }

  String? get description => v != null ? v!.description : q.description;
  set description(String? d) {
    if (v != null) {
      v!.description = d;
    } else {
      q.description = d;
    }
  }

  List<QuestionOption> get options => v?.options ?? q.options;
  Map<String, dynamic> get config => v?.config ?? q.config;

  double get weight => v?.weight ?? q.originalWeight;
  set weight(double w) {
    if (v != null) {
      v!.weight = w;
    } else {
      q.originalWeight = w;
    }
  }

  bool get skip => v?.skip ?? false;
  set skip(bool s) {
    if (v != null) v!.skip = s;
  }
}

/// Apply a type change to either Question or QuestionVariant via a Slot.
void _applyTypeChange(_Slot slot, QuestionType newType) {
  final old = slot.type;
  if (old == newType) return;
  slot.type = newType;

  final cfg = slot.config;
  cfg.remove('min');
  cfg.remove('max');
  cfg.remove('show_ticks');
  cfg.remove('show_value');
  cfg.remove('show_bounds');

  bool isChoice(QuestionType t) =>
      t == QuestionType.single_choice ||
      t == QuestionType.multiple_choice ||
      t == QuestionType.dropdown;

  if (newType == QuestionType.scale) {
    cfg['min'] = 1;
    cfg['max'] = 5;
    cfg['show_ticks'] = true;
    cfg['show_value'] = true;
    cfg['show_bounds'] = true;
    slot.options.clear();
  } else if (isChoice(newType)) {
    if (!isChoice(old)) {
      slot.options
        ..clear()
        ..add(QuestionOption(label: '', value: '', position: 0));
    }
    // switching between choice types — keep options
  } else {
    slot.options.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// QUESTION TYPE PICKER
// ─────────────────────────────────────────────────────────────────────────

class QuestionTypePicker extends StatelessWidget {
  final QuestionType value;
  final ValueChanged<QuestionType> onChanged;
  const QuestionTypePicker(
      {super.key, required this.value, required this.onChanged});

  IconData _iconFor(QuestionType t) {
    switch (t) {
      case QuestionType.short_text:
        return Icons.short_text_rounded;
      case QuestionType.long_text:
        return Icons.notes_rounded;
      case QuestionType.single_choice:
        return Icons.radio_button_checked_rounded;
      case QuestionType.multiple_choice:
        return Icons.check_box_outlined;
      case QuestionType.dropdown:
        return Icons.expand_circle_down_outlined;
      case QuestionType.scale:
        return Icons.linear_scale_rounded;
      // case QuestionType.rating:
      //   return Icons.star_outline_rounded;
      // case QuestionType.number:
      //   return Icons.numbers_rounded;
      // case QuestionType.date:
      //   return Icons.calendar_today_rounded;
      // case QuestionType.email:
      //   return Icons.alternate_email_rounded;
      case QuestionType.section_header:
         return Icons.title_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<QuestionType>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Тип вопроса'),
      items: QuestionType.values
          .map((t) => DropdownMenuItem(
                value: t,
                child: Row(children: [
                  Icon(_iconFor(t), size: 16, color: HseColors.primary),
                  const SizedBox(width: 8),
                  Text(t.human),
                ]),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// OPTIONS EDITOR — generic, race-safe
// ─────────────────────────────────────────────────────────────────────────

class OptionsEditor extends StatefulWidget {
  final List<QuestionOption> options;
  final QuestionType questionType;
  final VoidCallback onChanged;
  const OptionsEditor({
    super.key,
    required this.options,
    required this.questionType,
    required this.onChanged,
  });
  @override
  State<OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionRow {
  final TextEditingController controller;
  final FocusNode focus;
  QuestionOption option;
  _OptionRow(this.option)
      : controller = TextEditingController(text: option.label),
        focus = FocusNode();
  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _OptionsEditorState extends State<OptionsEditor> {
  final List<_OptionRow> _rows = [];
  int _newIdSeed = -1;

  @override
  void initState() {
    super.initState();
    for (final o in widget.options) {
      _rows.add(_OptionRow(o));
    }
  }

  @override
  void didUpdateWidget(covariant OptionsEditor old) {
    super.didUpdateWidget(old);
    final qOpts = widget.options;
    if (qOpts.length == _rows.length) {
      for (int i = 0; i < _rows.length; i++) {
        _rows[i].option = qOpts[i];
      }
    }
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  IconData _bullet() {
    switch (widget.questionType) {
      case QuestionType.single_choice:
        return Icons.radio_button_unchecked_rounded;
      case QuestionType.multiple_choice:
        return Icons.check_box_outline_blank_rounded;
      default:
        return Icons.menu_rounded;
    }
  }

  void _addOption() {
    final newOpt = QuestionOption(
        id: _newIdSeed--, label: '', value: '', position: _rows.length);
    setState(() {
      widget.options.add(newOpt);
      _rows.add(_OptionRow(newOpt));
    });
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _rows.isNotEmpty) _rows.last.focus.requestFocus();
    });
  }

  void _removeAt(int i) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
      widget.options.removeAt(i);
      for (int k = 0; k < widget.options.length; k++) {
        widget.options[k].position = k;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('ВАРИАНТЫ ОТВЕТА',
            style: TextStyle(
                color: HseColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
      ),
      for (int i = 0; i < _rows.length; i++)
        Padding(
          key: ValueKey(_rows[i]),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(_bullet(), color: HseColors.muted, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
              controller: _rows[i].controller,
              focusNode: _rows[i].focus,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Вариант ${i + 1}',
                filled: true,
                fillColor: HseColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HseRadius.sm),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HseRadius.sm),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HseRadius.sm),
                  borderSide: const BorderSide(
                      color: HseColors.primaryBright, width: 1.5),
                ),
              ),
              onChanged: (v) {
                _rows[i].option.label = v;
                _rows[i].option.value = v;
                widget.onChanged();
              },
              onSubmitted: (_) {
                widget.onChanged();
                _addOption();
              },
            )),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: HseColors.muted,
              tooltip: 'Удалить вариант',
              onPressed: _rows.length > 1 ? () => _removeAt(i) : null,
            ),
          ]),
        ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить вариант'),
          onPressed: _addOption,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SCALE CONFIG — generic
// ─────────────────────────────────────────────────────────────────────────

class ScaleConfigEditor extends StatefulWidget {
  final Map<String, dynamic> config;
  final VoidCallback onChanged;
  const ScaleConfigEditor(
      {super.key, required this.config, required this.onChanged});
  @override
  State<ScaleConfigEditor> createState() => _ScaleConfigEditorState();
}

class _ScaleConfigEditorState extends State<ScaleConfigEditor> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  String? _error;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(text: '${widget.config['min'] ?? 1}');
    _max = TextEditingController(text: '${widget.config['max'] ?? 5}');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _validate() {
    final mn = int.tryParse(_min.text);
    final mx = int.tryParse(_max.text);
    setState(() {
      if (mn == null || mx == null) {
        _error = 'Введите целые числа';
      } else if (mn >= mx) {
        _error = 'Минимум должен быть строго меньше максимума';
      } else if (mx - mn > 100) {
        _error = 'Слишком большой диапазон (макс. 100 шагов)';
      } else {
        _error = null;
        widget.config['min'] = mn;
        widget.config['max'] = mx;
        widget.onChanged();
      }
    });
  }

  bool _flag(String key, bool def) => (widget.config[key] ?? def) as bool;
  void _setFlag(String key, bool v) {
    setState(() => widget.config[key] = v);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: TextField(
          controller: _min,
          decoration: InputDecoration(
            labelText: 'Минимум',
            errorText: _error == null ? null : ' ',
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => _validate(),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: TextField(
          controller: _max,
          decoration: InputDecoration(
            labelText: 'Максимум',
            errorText: _error == null ? null : ' ',
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => _validate(),
        )),
      ]),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: HseColors.danger, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text(_error!,
                    style: const TextStyle(
                        color: HseColors.danger, fontSize: 12.5))),
          ]),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 18, runSpacing: 8, children: [
        _switch('Засечки на шкале', _flag('show_ticks', true),
            (v) => _setFlag('show_ticks', v)),
        _switch('Показывать выбранное число', _flag('show_value', true),
            (v) => _setFlag('show_value', v)),
        _switch('Показывать границы', _flag('show_bounds', true),
            (v) => _setFlag('show_bounds', v)),
      ]),
    ]);
  }

  Widget _switch(String label, bool v, ValueChanged<bool> on) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(value: v, onChanged: on),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────
// VARIANTS PAGER — original is page 0; swipeable across all variants.
// ─────────────────────────────────────────────────────────────────────────

class VariantsPager extends StatefulWidget {
  final Question q;
  final VoidCallback onChanged;
  const VariantsPager({super.key, required this.q, required this.onChanged});
  @override
  State<VariantsPager> createState() => _VariantsPagerState();
}

class _VariantsPagerState extends State<VariantsPager> {
  late List<QuestionVariant> _variants;
  late PageController _pageCtrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _variants = widget.q.readVariants();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _persist() {
    widget.q.writeVariants(_variants);
    widget.onChanged();
  }

  /// Total pages = 1 (original) + variants.
  int get _totalPages => 1 + _variants.length;
  bool get _experimentMode => _variants.isNotEmpty;

  void _addVariant() {
    final isChoice = widget.q.type == QuestionType.single_choice ||
        widget.q.type == QuestionType.multiple_choice ||
        widget.q.type == QuestionType.dropdown;
    final v = QuestionVariant(
      type: widget.q.type,
      title: '',
      options:
          isChoice ? [QuestionOption(label: '', value: '', position: 0)] : [],
      config: widget.q.type == QuestionType.scale
          ? {
              'min': 1,
              'max': 5,
              'show_ticks': true,
              'show_value': true,
              'show_bounds': true
            }
          : <String, dynamic>{},
      weight: 1.0,
    );
    final wasEmpty = _variants.isEmpty;
    setState(() {
      _variants.add(v);
      // If we just entered experiment mode, ensure original_weight has a value.
      if (wasEmpty) widget.q.originalWeight = widget.q.originalWeight;
      _index = _totalPages - 1; // jump to the brand-new variant page
    });
    _persist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients) {
        _pageCtrl.animateToPage(_index,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  void _removePage(int pageIndex) {
    if (pageIndex == 0) return; // can't remove the original
    final variantIdx = pageIndex - 1;
    if (variantIdx < 0 || variantIdx >= _variants.length) return;
    setState(() {
      _variants.removeAt(variantIdx);
      if (_index >= _totalPages) _index = _totalPages - 1;
      if (_index < 0) _index = 0;
    });
    _persist();
    if (_pageCtrl.hasClients && _experimentMode) {
      _pageCtrl.jumpToPage(_index);
    }
  }

  void _go(int i) {
    if (i < 0 || i >= _totalPages) return;
    setState(() => _index = i);
    if (_pageCtrl.hasClients) {
      _pageCtrl.animateToPage(i,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  _Slot _slotForPage(int i) => i == 0
      ? _Slot.original(widget.q)
      : _Slot.variant(widget.q, _variants[i - 1]);

  @override
  Widget build(BuildContext context) {
    // ───── Inline (no experiment yet) ─────
    if (!_experimentMode) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SinglePageEditor(
          key: ObjectKey(widget.q),
          slot: _Slot.original(widget.q),
          onChanged: widget.onChanged,
          showWeight: false,
          showSkip: false,
        ),
        const SizedBox(height: 14),
        _MakeExperimentCTA(onTap: _addVariant),
      ]);
    }

    // ───── Experiment mode: pager containing original + variants ─────
    final currentSlot = _slotForPage(_index);
    return Container(
      decoration: BoxDecoration(
        color: HseColors.surface,
        borderRadius: BorderRadius.circular(HseRadius.lg),
        border:
            Border.all(color: HseColors.success.withOpacity(0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(children: [
            Icon(Icons.science_rounded, size: 18, color: HseColors.success),
            const SizedBox(width: 8),
            const Text('Эксперимент: варианты вопроса',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Добавить вариант',
              onPressed: _addVariant,
            ),
          ]),
        ),
        const Divider(height: 1),
        // Nav row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _index > 0 ? () => _go(_index - 1) : null,
            ),
            Expanded(
                child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (int i = 0; i < _totalPages; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => _go(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? (i == 0 ? HseColors.primary : HseColors.success)
                              : HseColors.borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  _index == 0
                      ? 'Оригинал (1 из $_totalPages)'
                      : 'Вариант ${_index + 1} из ${_totalPages}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: HseColors.inkSoft),
                ),
              ]),
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed:
                  _index < _totalPages - 1 ? () => _go(_index + 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: _index == 0
                  ? 'Оригинал нельзя удалить — удалите все варианты, чтобы выйти из режима'
                  : 'Удалить этот вариант',
              color: _index == 0 ? HseColors.borderStrong : HseColors.danger,
              onPressed: _index == 0 ? null : () => _removePage(_index),
            ),
          ]),
        ),
        // Pager body — fixed height that adapts to current slot's content type.
        SizedBox(
          height: _heightFor(currentSlot),
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _totalPages,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) {
              final slot = _slotForPage(i);
              return _SinglePageEditor(
                // ObjectKey ties State to the underlying data object identity,
                // so when a variant is removed mid-list, controllers don't
                // bleed into a different variant's data.
                key: ObjectKey(slot.v ?? slot.q),
                slot: slot,
                onChanged: _persist,
                showWeight: true,
                showSkip: !slot.isOriginal,
              );
            },
          ),
        ),
      ]),
    );
  }

  double _heightFor(_Slot slot) {
    if (slot.skip) return 280;
    switch (slot.type) {
      case QuestionType.single_choice:
      case QuestionType.multiple_choice:
      case QuestionType.dropdown:
        return 540 + (slot.options.length * 56);
      case QuestionType.scale:
        return 600;
      default:
        return 440;
    }
  }
}

class _MakeExperimentCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _MakeExperimentCTA({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HseColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(HseRadius.md),
        border: Border.all(color: HseColors.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: HseColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.science_rounded,
              color: HseColors.success, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Сделать вопрос экспериментом',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          SizedBox(height: 2),
          Text(
            'Добавить альтернативные версии — каждый респондент случайно увидит одну.',
            style: TextStyle(color: HseColors.inkSoft, fontSize: 12.5),
          ),
        ])),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('A/B вариант'),
          onPressed: onTap,
        ),
      ]),
    );
  }
}

/// Universal page editor used both inline (no experiment) and inside the pager
/// (one of: original at page 0, or any variant). Drives layout via Slot.
class _SinglePageEditor extends StatefulWidget {
  final _Slot slot;
  final VoidCallback onChanged;
  final bool showWeight;
  final bool showSkip;
  const _SinglePageEditor({
    super.key,
    required this.slot,
    required this.onChanged,
    required this.showWeight,
    required this.showSkip,
  });
  @override
  State<_SinglePageEditor> createState() => _SinglePageEditorState();
}

class _SinglePageEditorState extends State<_SinglePageEditor> {
  late final TextEditingController _title;
  late final TextEditingController _desc;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.slot.title);
    _desc = TextEditingController(text: widget.slot.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final body =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.showSkip)
        _SkipToggle(
          value: slot.skip,
          onChanged: (v) {
            setState(() => slot.skip = v);
            widget.onChanged();
          },
        ),
      if (widget.showSkip) const SizedBox(height: 12),
      if (!slot.skip) ...[
        QuestionTypePicker(
          value: slot.type,
          onChanged: (t) {
            setState(() => _applyTypeChange(slot, t));
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
              labelText: 'Текст вопроса', hintText: 'О чём спрашиваем?'),
          onChanged: (val) {
            slot.title = val;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          decoration: const InputDecoration(
              labelText: 'Подсказка или пояснение', hintText: 'Опционально'),
          onChanged: (val) {
            slot.description = val.isEmpty ? null : val;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        _typeSpecific(slot),
        const SizedBox(height: 16),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x1AE05656),
              borderRadius: BorderRadius.circular(HseRadius.sm),
            ),
            child: const Text(
              'Если этот вариант выпадет — вопрос не покажется респонденту. Вес ниже определяет вероятность.',
              style: TextStyle(
                  color: HseColors.danger,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      if (widget.showWeight)
        _WeightSlider(
          value: slot.weight,
          isOriginal: slot.isOriginal,
          onChanged: (val) {
            setState(() => slot.weight = val);
            widget.onChanged();
          },
        ),
    ]);

    if (widget.showWeight) {
      // We're inside the pager — make the page scroll if too tall.
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: body,
      );
    }
    // Inline mode — no extra padding/scroll, parent handles it.
    return body;
  }

  Widget _typeSpecific(_Slot slot) {
    switch (slot.type) {
      case QuestionType.single_choice:
      case QuestionType.multiple_choice:
      case QuestionType.dropdown:
        return OptionsEditor(
          key: ValueKey(
              'opts-${identityHashCode(slot.options)}-${slot.type.name}'),
          options: slot.options,
          questionType: slot.type,
          onChanged: widget.onChanged,
        );
      case QuestionType.scale:
        return ScaleConfigEditor(
          key: ValueKey('scale-${identityHashCode(slot.config)}'),
          config: slot.config,
          onChanged: widget.onChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SkipToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SkipToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: value ? const Color(0x1AE05656) : Colors.white,
        borderRadius: BorderRadius.circular(HseRadius.sm),
        border: Border.all(
            color:
                value ? HseColors.danger.withOpacity(0.3) : HseColors.border),
      ),
      child: Row(children: [
        Icon(value ? Icons.visibility_off_rounded : Icons.visibility_outlined,
            size: 18, color: value ? HseColors.danger : HseColors.muted),
        const SizedBox(width: 8),
        const Expanded(
            child: Text(
          'Пропустить вопрос (вариант = не показывать)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        )),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  final double value;
  final bool isOriginal;
  final ValueChanged<double> onChanged;
  const _WeightSlider(
      {required this.value, required this.isOriginal, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final accent = isOriginal ? HseColors.primary : HseColors.success;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HseRadius.sm),
        border: Border.all(color: HseColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isOriginal ? Icons.bookmark_rounded : Icons.scale_rounded,
              size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
            isOriginal ? 'Вес показа оригинала' : 'Вес показа варианта',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          )),
          Text(value.toStringAsFixed(1),
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: accent, fontSize: 14)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context)
              .copyWith(activeTrackColor: accent, thumbColor: accent),
          child: Slider(
            value: value.clamp(0.0, 5.0),
            min: 0,
            max: 5,
            divisions: 50,
            onChanged: (val) => onChanged(double.parse(val.toStringAsFixed(1))),
          ),
        ),
        const Text(
          'Вероятность ≈ вес ÷ сумма весов всех страниц.',
          style: TextStyle(color: HseColors.muted, fontSize: 11.5),
        ),
      ]),
    );
  }
}
