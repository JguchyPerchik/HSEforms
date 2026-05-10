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
    super.key, required this.question,
    required this.previousQuestions, required this.onChanged,
  });

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<ConditionEditor> {
  late List<Map<String, dynamic>> clauses;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    final cond = widget.question.displayCondition;
    enabled = cond != null;
    clauses = enabled
        ? List<Map<String, dynamic>>.from((cond!['all'] ?? cond['any'] ?? []) as List)
        : [];
  }

  void _emit() {
    if (!enabled || clauses.isEmpty) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged({'all': clauses});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previousQuestions.isEmpty) {
      return const Text('Добавьте предыдущие вопросы, чтобы создавать условия',
          style: TextStyle(color: HseColors.muted, fontSize: 12));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HseColors.surface, borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Switch(
            value: enabled,
            activeColor: HseColors.secondary,
            onChanged: (v) { setState(() => enabled = v); _emit(); },
          ),
          const Text('Показывать только если…', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        if (enabled) ...[
          const SizedBox(height: 8),
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
        Expanded(flex: 3, child: DropdownButtonFormField<int>(
          value: refQ.id,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: widget.previousQuestions.map((q) =>
              DropdownMenuItem(value: q.id, child: Text(q.title.isEmpty ? '#${q.id}' : q.title, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { setState(() => c['question_id'] = v); _emit(); },
        )),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: DropdownButtonFormField<String>(
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
            DropdownMenuItem(value: 'not_answered', child: Text('не заполнено')),
          ],
          onChanged: (v) { setState(() => c['op'] = v); _emit(); },
        )),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: hasOptions && (c['op'] == 'eq' || c['op'] == 'neq')
            ? DropdownButtonFormField<String>(
                value: refQ.options.any((o) => o.value == c['value']) ? c['value'] as String? : null,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: refQ.options.map((o) =>
                    DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) { c['value'] = v; _emit(); },
              )
            : (c['op'] == 'answered' || c['op'] == 'not_answered'
                ? const SizedBox.shrink()
                : TextFormField(
                    initialValue: c['value']?.toString() ?? '',
                    decoration: const InputDecoration(isDense: true, hintText: 'значение'),
                    onChanged: (v) { c['value'] = v; },
                    onTapOutside: (_) => _emit(),
                  ))),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: HseColors.muted),
          onPressed: () { setState(() => clauses.removeAt(i)); _emit(); },
        ),
      ]),
    );
  }
}
