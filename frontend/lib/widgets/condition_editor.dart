import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Simple flat AND-list editor for {"all": [{question_id, op, value}, ...]}.
/// Power users can edit JSON directly via API.
class ConditionEditor extends StatefulWidget {
  final Question question;
  final List<Question> previousQuestions;
  final void Function(Map<String, dynamic>?) onChanged;

  const ConditionEditor({
    super.key,
    required this.question,
    required this.previousQuestions,
    required this.onChanged,
  });

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<ConditionEditor> {
  late List<Map<String, dynamic>> clauses;
  late bool enabled;
  /// 'all' = И (все условия), 'any' = ИЛИ (хотя бы одно).
  /// Эта строка идёт прямо в JSON-ключ payload'а: бэкенд
  /// (backend/app/core/conditional.py) и рантайм-валидатор на клиенте
  /// (utils/conditional.dart) оба понимают и `all`, и `any` — фронт
  /// просто выбирает обёртку.
  late String _groupOp;

  @override
  void initState() {
    super.initState();
    final cond = widget.question.displayCondition;
    enabled = cond != null;
    // Восстанавливаем оператор группировки из существующего условия:
    // если в JSON ключ `any` — значит OR, иначе AND (старые сохранённые
    // правила и пустые условия → AND по умолчанию).
    _groupOp = (cond != null && cond['any'] is List) ? 'any' : 'all';
    clauses = enabled
        ? List<Map<String, dynamic>>.from(
            (cond!['all'] ?? cond['any'] ?? []) as List)
        : [];
  }

  void _emit() {
    if (!enabled || clauses.isEmpty) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged({_groupOp: clauses});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previousQuestions.isEmpty) {
      return const Text('Добавьте предыдущие вопросы, чтобы создавать условия',
          style: TextStyle(color: HseColors.muted, fontSize: 12));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: HseColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(
            value: enabled,
            activeColor: HseColors.secondary,
            onChanged: (v) {
              setState(() => enabled = v);
              _emit();
            },
          ),
          const SizedBox(width: 6),
          const Text('Показывать только если…',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        if (enabled) ...[
          const SizedBox(height: 8),
          // Переключатель И/ИЛИ. Показывается всегда при включённой
          // логике (даже на 1 условии) для визуальной консистентности —
          // пользователь сразу видит, в каком режиме окажется второе
          // условие, когда он его добавит. На 2+ условиях смысл очевиден.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Text('Совпадают: ',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: HseColors.inkSoft,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              _GroupOpToggle(
                value: _groupOp,
                onChanged: (v) {
                  setState(() => _groupOp = v);
                  _emit();
                },
              ),
            ]),
          ),
          for (int i = 0; i < clauses.length; i++) _clauseRow(i),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить условие'),
            onPressed: () {
              setState(() => clauses.add({
                    'question_id': widget.previousQuestions.first.id,
                    'op': 'eq',
                    'value': '',
                  }));
              _emit();
            },
          ),
        ],
      ]),
    );
  }

  Widget _clauseRow(int i) {
    final c = clauses[i];
    final qid = c['question_id'] as int?;
    final refQ = widget.previousQuestions.firstWhere(
      (x) => x.id == qid,
      orElse: () => widget.previousQuestions.first,
    );
    final hasOptions = refQ.options.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              value: refQ.id,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: widget.previousQuestions
                  .map((q) => DropdownMenuItem(
                      value: q.id,
                      child: Text(q.title.isEmpty ? '#${q.id}' : q.title,
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() => c['question_id'] = v);
                _emit();
              },
            )),
        const SizedBox(width: 8),
        Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: c['op'] as String? ?? 'eq',
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: const [
                DropdownMenuItem(value: 'eq', child: Text('=')),
                DropdownMenuItem(value: 'neq', child: Text('≠')),
                DropdownMenuItem(value: 'gt', child: Text('>')),
                DropdownMenuItem(value: 'lt', child: Text('<')),
                DropdownMenuItem(value: 'contains', child: Text('содержит')),
                DropdownMenuItem(value: 'answered', child: Text('заполнено')),
                DropdownMenuItem(
                    value: 'not_answered', child: Text('не заполнено')),
              ],
              onChanged: (v) {
                setState(() => c['op'] = v);
                _emit();
              },
            )),
        const SizedBox(width: 8),
        Expanded(
            flex: 3,
            child: hasOptions && (c['op'] == 'eq' || c['op'] == 'neq')
                ? DropdownButtonFormField<String>(
                    value: refQ.options.any((o) => o.value == c['value'])
                        ? c['value'] as String?
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: refQ.options
                        .map((o) => DropdownMenuItem(
                            value: o.value,
                            child:
                                Text(o.label, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) {
                      c['value'] = v;
                      _emit();
                    },
                  )
                : (c['op'] == 'answered' || c['op'] == 'not_answered'
                    ? const SizedBox.shrink()
                    : TextFormField(
                        initialValue: c['value']?.toString() ?? '',
                        decoration: const InputDecoration(
                            isDense: true, hintText: 'значение'),
                        onChanged: (v) {
                          c['value'] = v;
                        },
                        onTapOutside: (_) => _emit(),
                      ))),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: HseColors.muted),
          onPressed: () {
            setState(() => clauses.removeAt(i));
            _emit();
          },
        ),
      ]),
    );
  }
}

/// Сегментный переключатель «И / ИЛИ» для группировки условий.
/// Маленький, помещается в одну строку с подписью.
class _GroupOpToggle extends StatelessWidget {
  final String value; // 'all' или 'any'
  final ValueChanged<String> onChanged;
  const _GroupOpToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HseColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _segment(label: 'И', tooltip: 'Все условия должны выполняться', op: 'all'),
        Container(width: 1, height: 24, color: HseColors.border),
        _segment(label: 'ИЛИ', tooltip: 'Хотя бы одно условие выполняется', op: 'any'),
      ]),
    );
  }

  Widget _segment({required String label, required String tooltip, required String op}) {
    final selected = value == op;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onChanged(op),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? HseColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label,
              style: TextStyle(
                fontFamily: 'HSESans',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: selected ? Colors.white : HseColors.inkSoft,
              )),
        ),
      ),
    );
  }
}
