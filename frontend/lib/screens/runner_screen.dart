import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/question_renderer.dart';
import '../utils/conditional.dart';

class RunnerScreen extends StatefulWidget {
  final String slug;
  const RunnerScreen({super.key, required this.slug});
  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen> {
  late final PublicApi _api = PublicApi(context.read<ApiClient>());
  Survey? survey;
  int? responseId;
  int pageIndex = 0;
  bool _busy = false;
  bool _done = false;
  String? _error;
  final Map<int, Map<String, dynamic>> answers = {};

  /// Per-question variant assignment computed once per session.
  /// Value: -1 = skipped, 0 = original, 1..n = variant index (1-based; n = variants[n-1]).
  final Map<int, int> _variantAssignment = {};
  int _seed = 0;

  bool get _isPreview => responseId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      survey = await _api.getBySlug(widget.slug);
      if (survey != null && survey!.status == SurveyStatus.published) {
        final r = await _api.start(widget.slug);
        responseId = r['response_id'] as int?;
      }
      _seed = (responseId ?? widget.slug.hashCode);
      _assignVariants();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _assignVariants() {
    if (survey == null) return;
    _variantAssignment.clear();
    for (final q in survey!.questions) {
      _variantAssignment[q.id] = _pickVariant(q);
    }
  }

  int _pickVariant(Question q) {
    final variants = q.readVariants();
    if (variants.isEmpty) return 0;
    // Build weighted pool: index 0 = original (weight = q.originalWeight),
    // 1..N = variants (weight = variants[i-1].weight).
    final weights = <double>[
      q.originalWeight,
      ...variants.map((v) => v.weight.clamp(0.0, double.infinity))
    ];
    final total = weights.fold<double>(0.0, (a, b) => a + b);
    if (total <= 0) return 0;
    final rng = Random(_seed * 1000003 + q.id);
    final r = rng.nextDouble() * total;
    double cum = 0;
    for (int i = 0; i < weights.length; i++) {
      cum += weights[i];
      if (r < cum) {
        if (i == 0) return 0;
        // Variant i-1: check skip flag.
        return variants[i - 1].skip ? -1 : i;
      }
    }
    return 0;
  }

  /// Returns a copy of the question rendered as the assigned variant —
  /// possibly with a different type, options, and config.
  Question _resolveVariant(Question q) {
    final pick = _variantAssignment[q.id] ?? 0;
    if (pick <= 0) return q;
    final variants = q.readVariants();
    final v = variants[pick - 1];
    return Question(
      id: q.id,
      surveyId: q.surveyId,
      type: v.type,
      title: v.title.isEmpty ? q.title : v.title,
      description: v.description ?? q.description,
      position: q.position,
      pageBreakBefore: q.pageBreakBefore,
      required: q.required,
      config: v.config,
      displayCondition: q.displayCondition,
      options: v.options,
    );
  }

  /// Visible-only flat list, then split by page_break_before.
  /// Skipped (variant=-1) and condition-hidden questions are removed.
  List<List<Question>> _pages() {
    if (survey == null) return [];
    final visible = <Question>[];
    for (final raw in survey!.questions) {
      if ((_variantAssignment[raw.id] ?? 0) < 0) continue;
      if (!evaluateCondition(raw.displayCondition, answers)) continue;
      visible.add(_resolveVariant(raw));
    }
    final pages = <List<Question>>[];
    for (final q in visible) {
      if (pages.isEmpty || q.pageBreakBefore) {
        pages.add([q]);
      } else {
        pages.last.add(q);
      }
    }
    return pages;
  }

  bool _validatePage(List<Question> page) {
    for (final q in page) {
      if (q.required) {
        final v = answers[q.id]?['value'];
        if (v == null || v == '' || (v is List && v.isEmpty)) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Заполните: ${q.title}')));
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _submit() async {
    // Preview mode: no responseId, just show "thank you" without API call.
    if (_isPreview) {
      setState(() => _done = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final list = answers.entries
          .map((e) => {'question_id': e.key, 'value': e.value})
          .toList();
      await _api.submit(responseId!, list);
      setState(() => _done = true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _bg(Survey s) {
    final hex = (s.theme['background'] as String?) ?? '#FFFFFF';
    return _parseHex(hex, fallback: const Color(0xFFFFFFFF));
  }

  Color _primary(Survey s) {
    final hex = (s.theme['primary'] as String?) ?? '#0F2D69';
    return _parseHex(hex, fallback: HseColors.primary);
  }

  Color _parseHex(String hex, {required Color fallback}) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && survey == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text(_error!)));
    if (survey == null)
      return const Scaffold(
          body: Center(
              child: Text('Опрос не найден',
                  style: TextStyle(fontFamily: 'HSESans'))));

    final s = survey!;
    if (_done) {
      return Scaffold(
        backgroundColor: _bg(s),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _primary(s).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: _primary(s), size: 56),
                  ),
                  const SizedBox(height: 18),
                  Text('Спасибо!',
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 6),
                  Text(
                    _isPreview ? 'Предпросмотр завершён' : 'Ваш ответ записан',
                    style: const TextStyle(
                        fontFamily: 'HSESans',
                        color: HseColors.muted,
                        fontSize: 15),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    final pages = _pages();
    if (pages.isEmpty) {
      return Scaffold(
        backgroundColor: _bg(s),
        body: const Center(
            child: Text('В опросе пока нет вопросов',
                style:
                    TextStyle(fontFamily: 'HSESans', color: HseColors.muted))),
      );
    }
    pageIndex = pageIndex.clamp(0, pages.length - 1);
    final page = pages[pageIndex];
    final isLast = pageIndex == pages.length - 1;
    final isFirst = pageIndex == 0;

    return Scaffold(
      backgroundColor: _bg(s),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_primary(s), _primary(s).withOpacity(0.78)],
                        ),
                        borderRadius: BorderRadius.circular(HseRadius.lg),
                        boxShadow: HseShadows.card,
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                style: const TextStyle(
                                    fontFamily: 'HSESans',
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15)),
                            if (s.description != null &&
                                s.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(s.description!,
                                  style: const TextStyle(
                                      fontFamily: 'HSESans',
                                      color: Colors.white70,
                                      fontSize: 15,
                                      height: 1.45)),
                            ],
                            if (s.showProgress) ...[
                              const SizedBox(height: 18),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (pageIndex + 1) / pages.length,
                                  minHeight: 8,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Шаг ${pageIndex + 1} из ${pages.length}',
                                  style: const TextStyle(
                                      fontFamily: 'HSESans',
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ]),
                    ),
                    const SizedBox(height: 16),
                    for (final q in page)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: QuestionRenderer(
                              question: q,
                              value: answers[q.id],
                              onChanged: (v) =>
                                  setState(() => answers[q.id] = v),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(children: [
                      if (s.allowBackNavigation && !isFirst)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Назад',
                              style: TextStyle(fontFamily: 'HSESans')),
                          onPressed: () => setState(() => pageIndex -= 1),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: Icon(isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded),
                        label: Text(isLast ? 'Отправить' : 'Далее'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary(s),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 16),
                        ),
                        onPressed: _busy
                            ? null
                            : () {
                                if (!_validatePage(page)) return;
                                if (isLast) {
                                  _submit();
                                } else {
                                  setState(() => pageIndex += 1);
                                }
                              },
                      ),
                    ]),
                    if (_isPreview)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: HseColors.surfaceAlt,
                              borderRadius:
                                  BorderRadius.circular(HseRadius.md)),
                          child: Row(children: const [
                            Icon(Icons.visibility_outlined,
                                color: HseColors.muted, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                              'Режим предпросмотра — ответы не сохраняются. Опубликуйте опрос, чтобы собирать ответы.',
                              style: TextStyle(
                                  fontFamily: 'HSESans',
                                  color: HseColors.muted,
                                  fontSize: 12.5),
                            )),
                          ]),
                        ),
                      ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
