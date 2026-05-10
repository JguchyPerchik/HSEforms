/// Mirror of backend conditional evaluator (see backend/app/core/conditional.py).
/// Used by the runner to hide questions client-side; the server re-validates on submit.
dynamic _scalar(Map<String, dynamic>? a) => a == null ? null : (a['value'] ?? a['text'] ?? a);

bool _matches(Map<String, dynamic>? answer, String op, dynamic expected) {
  final val = _scalar(answer);
  if (op == 'answered') return answer != null && val != null && val != '' && !(val is List && val.isEmpty);
  if (op == 'not_answered') return answer == null || val == null || val == '' || (val is List && val.isEmpty);
  if (val == null) return false;
  try {
    switch (op) {
      case 'eq': return val == expected;
      case 'neq': return val != expected;
      case 'gt': return double.parse(val.toString()) > double.parse(expected.toString());
      case 'gte': return double.parse(val.toString()) >= double.parse(expected.toString());
      case 'lt': return double.parse(val.toString()) < double.parse(expected.toString());
      case 'lte': return double.parse(val.toString()) <= double.parse(expected.toString());
      case 'in': return (expected as List?)?.contains(val) ?? false;
      case 'not_in': return !((expected as List?)?.contains(val) ?? false);
      case 'contains':
        if (val is List) return val.contains(expected);
        return val.toString().contains(expected.toString());
    }
  } catch (_) { return false; }
  return false;
}

bool evaluateCondition(Map<String, dynamic>? rule, Map<int, Map<String, dynamic>> answers) {
  if (rule == null) return true;
  if (rule['all'] is List) {
    return (rule['all'] as List).every((r) => evaluateCondition(Map<String, dynamic>.from(r), answers));
  }
  if (rule['any'] is List) {
    return (rule['any'] as List).any((r) => evaluateCondition(Map<String, dynamic>.from(r), answers));
  }
  if (rule['not'] != null) {
    return !evaluateCondition(Map<String, dynamic>.from(rule['not']), answers);
  }
  final qid = rule['question_id'] as int?;
  return _matches(qid == null ? null : answers[qid], rule['op'] as String? ?? 'eq', rule['value']);
}
