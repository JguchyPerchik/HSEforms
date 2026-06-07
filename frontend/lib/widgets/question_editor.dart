import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'condition_editor.dart';

const _kOther = '__other__';

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
      if (mounted && _rows.isNotEmpty) {
        // Фокусируем последнюю обычную строку (не «Другое»)
        final idx = _rows.lastIndexWhere((r) => r.option.value != _kOther);
        if (idx >= 0) _rows[idx].focus.requestFocus();
      }
    });
  }

  // Добавляет специальный вариант «Другое» (sentinel value = _kOther).
  // Вызов идемпотентен: если «Другое» уже есть — ничего не делает.
  void _addOtherOption() {
    if (widget.options.any((o) => o.value == _kOther)) return;
    final opt = QuestionOption(
      id: _newIdSeed--,
      label: 'Другое',
      value: _kOther,
      position: _rows.length,
    );
    setState(() {
      widget.options.add(opt);
      _rows.add(_OptionRow(opt));
    });
    widget.onChanged();
  }

  void _removeAt(int i) {
    final isOther = _rows[i].option.value == _kOther;
    // Обычные варианты: не даём удалить последний.
    // «Другое» можно убрать всегда (это не обязательный вариант).
    if (!isOther && _rows.where((r) => r.option.value != _kOther).length <= 1)
      return;
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

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final row = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, row);
      final opt = widget.options.removeAt(oldIndex);
      widget.options.insert(newIndex, opt);
      for (int k = 0; k < widget.options.length; k++) {
        widget.options[k].position = k;
      }
    });
    widget.onChanged();
  }

  Widget _buildRow(int i) {
    final isOther = _rows[i].option.value == _kOther;

    return Padding(
      key: ObjectKey(_rows[i]),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        ReorderableDragStartListener(
          index: i,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.drag_indicator_rounded,
                size: 18, color: HseColors.muted),
          ),
        ),
        Icon(_bullet(), color: HseColors.muted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: isOther
              // ── Вариант «Другое»: нередактируемая плашка ──────────────
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: HseColors.surface,
                    borderRadius: BorderRadius.circular(HseRadius.sm),
                    border: Border.all(
                        color: HseColors.primaryBright.withOpacity(0.45)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.edit_note_rounded,
                        size: 16, color: HseColors.primaryBright),
                    SizedBox(width: 8),
                    Text('Другое',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: HseColors.primaryBright,
                            fontSize: 14)),
                    SizedBox(width: 8),
                    Text('(покажет текстовое поле)',
                        style: TextStyle(fontSize: 12, color: HseColors.muted)),
                  ]),
                )
              // ── Обычный вариант: редактируемое поле ───────────────────
              : TextField(
                  controller: _rows[i].controller,
                  focusNode: _rows[i].focus,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Вариант ${i + 1}',
                    filled: true,
                    fillColor: HseColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
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
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) {
                    _rows[i].option.label = v;
                    // Не трогаем value у «Другое» — его sentinel '_kOther'
                    // нельзя перезаписывать.
                    if (_rows[i].option.value != _kOther) {
                      _rows[i].option.value = v;
                    }
                    widget.onChanged();
                  },
                  onSubmitted: (_) {
                    widget.onChanged();
                    _addOption();
                  },
                ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: HseColors.muted,
          tooltip: isOther ? 'Убрать вариант «Другое»' : 'Удалить вариант',
          onPressed: () => _removeAt(i),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supportsOther = widget.questionType == QuestionType.single_choice ||
        widget.questionType == QuestionType.multiple_choice;
    final hasOther = widget.options.any((o) => o.value == _kOther);

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
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _rows.length,
        onReorder: _reorder,
        itemBuilder: (ctx, i) => _buildRow(i),
      ),
      const SizedBox(height: 4),

      // Кнопка «+ Добавить вариант»
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить вариант'),
          onPressed: _addOption,
        ),
      ),

      // Кнопка «+ Добавить вариант «Другое»» —
      // только для single_choice / multiple_choice, только если её ещё нет
      if (supportsOther && !hasOther)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Добавить вариант «Другое»'),
            style: TextButton.styleFrom(
              foregroundColor: HseColors.primaryBright,
            ),
            onPressed: _addOtherOption,
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
          // Многострочный ввод: minLines=1 чтобы стартовал компактным
          // (как однострочный), maxLines=null — растёт под содержимое
          // вместо горизонтальной прокрутки. Длинные формулировки и
          // вопросы из 2-3 предложений теперь видно целиком.
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
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
          // То же самое — описание часто бывает длинным, без autosize
          // приходится скроллить однострочное поле горизонтально.
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
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
