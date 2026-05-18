import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/question_editor.dart';
import '../widgets/survey_settings_panel.dart';
import '../widgets/collaborators_dialog.dart';
import '../widgets/share_dialog.dart';

class BuilderScreen extends StatefulWidget {
  final int surveyId;
  const BuilderScreen({super.key, required this.surveyId});
  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());
  Survey? survey;
  bool _busy = false;
  int? _expandedQid;
  Timer? _titleSaveTimer;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  // Per-question debounced + serialized save infrastructure.
  final Map<int, Timer> _qSaveTimers = {};
  Future<void> _qSaveChain = Future.value();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _load();
  }

  @override
  void didUpdateWidget(covariant BuilderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.surveyId != widget.surveyId) {
      _expandedQid = null;
      _load();
    }
  }

  @override
  void dispose() {
    _titleSaveTimer?.cancel();
    for (final t in _qSaveTimers.values) {
      t.cancel();
    }
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final s = await _api.get(widget.surveyId);
      survey = s;
      _titleCtrl.text = s.title;
      _descCtrl.text = s.description ?? '';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scheduleTitleSave() {
    _titleSaveTimer?.cancel();
    _titleSaveTimer = Timer(const Duration(milliseconds: 600), () async {
      if (survey == null) return;
      try {
        await _api.update(survey!.id,
            {'title': survey!.title, 'description': survey!.description});
      } catch (_) {}
    });
  }

  // Debounce per question, then enqueue serially.
  void _scheduleQuestionSave(Question q) {
    _qSaveTimers[q.id]?.cancel();
    _qSaveTimers[q.id] = Timer(const Duration(milliseconds: 350), () {
      _qSaveChain = _qSaveChain.then((_) => _doSaveQuestion(q));
    });
  }

  Future<void> _doSaveQuestion(Question q) async {
    try {
      final updated = await _api.updateQuestion(widget.surveyId, q.id, {
        'title': q.title,
        'description': q.description,
        'page_break_before': q.pageBreakBefore,
        'required': q.required,
        'config': q.config,
        'display_condition': q.displayCondition,
        'options': q.options.map((o) {
          final j = o.toJson();
          if ((o.id ?? 0) < 0) j.remove('id');
          return j;
        }).toList(),
      });
      if (!mounted) return;
      setState(() {
        final i = survey!.questions.indexWhere((x) => x.id == q.id);
        if (i >= 0) survey!.questions[i] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось сохранить вопрос: $e', style: TextStyle(fontFamily: 'HSESans'))));
      }
    }
  }

  Future<void> _addQuestion(QuestionType type) async {
    final q = await _api.addQuestion(widget.surveyId, {
      'type': type.name,
      'title': '',
      'page_break_before': false,
      'required': false,
      'config': type == QuestionType.scale
          ? {
              'min': 1,
              'max': 5,
              'show_ticks': true,
              'show_value': true,
              'show_bounds': true
            }
          : <String, dynamic>{},
      'options': (type == QuestionType.single_choice ||
              type == QuestionType.multiple_choice ||
              type == QuestionType.dropdown)
          ? [
              {'label': '', 'value': '', 'position': 0}
            ]
          : [],
    });
    setState(() {
      survey!.questions.add(q);
      _expandedQid = q.id;
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (survey == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final q = survey!.questions.removeAt(oldIndex);
      survey!.questions.insert(newIndex, q);
    });
    final ids = survey!.questions.map((q) => q.id).toList();
    final updated = await _api.reorder(widget.surveyId, ids);
    setState(() => survey!.questions
      ..clear()
      ..addAll(updated));
  }

  Future<void> _deleteQuestion(Question q) async {
    await _api.deleteQuestion(widget.surveyId, q.id);
    setState(() => survey!.questions.removeWhere((x) => x.id == q.id));
  }

  void _togglePageBreak(int index) {
    final q = survey!.questions[index];
    setState(() => q.pageBreakBefore = !q.pageBreakBefore);
    _scheduleQuestionSave(q);
  }

  Future<void> _publishToggle() async {
    final next =
        survey!.status == SurveyStatus.published ? 'draft' : 'published';
    final s = await _api.update(widget.surveyId, {'status': next});
    setState(() => survey = s);
    if (mounted && next == 'published') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text(
                'Опубликовано! Поделитесь ссылкой через кнопку «Поделиться».',
                style: TextStyle(fontFamily: 'HSESans'))),
      );
    }
  }

  Future<void> _createVariant() async {
    final letter = String.fromCharCode(65 + survey!.variants.length + 1);
    final v = await _api.create(
      title: '${survey!.title} — Вариант $letter',
      parentId: survey!.id,
      variantLabel: 'Вариант $letter',
      variantWeight: 1.0,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Создан «Вариант $letter». Открыть для редактирования?',
            style: TextStyle(fontFamily: 'HSESans')),
        action: SnackBarAction(
            label: 'Открыть', onPressed: () => context.go('/builder/${v.id}')),
      ));
    }
    await _load();
  }

Future<void> _deleteVariant(int variantId) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(
        'Удалить вариант?',
        style: TextStyle(fontFamily: 'HSESans'),
      ),
      content: const Text(
        'Уже собранные ответы по этому варианту тоже удалятся.',
        style: TextStyle(fontFamily: 'HSESans'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Отмена',
            style: TextStyle(fontFamily: 'HSESans'),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: HseColors.danger,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );

  if (ok == true) {
    await _api.delete(variantId);

    _expandedQid = null;

    await _load();

    if (mounted) {
      setState(() {});
    }
  }
}

Future<void> _changeVariantWeight(
  int variantId,
  double weight,
) async {
  await _api.update(
    variantId,
    {
      'variant_weight': weight,
    },
  );

  await _load();

  if (mounted) {
    setState(() {});
  }
}

  void _openShare() {
    showDialog(context: context, builder: (_) => ShareDialog(survey: survey!));
  }

  /// Returns the questions on strictly earlier pages than the question at [index].
  /// Page boundaries are defined by Question.pageBreakBefore on subsequent questions.
  List<Question> _availableTriggers(int index) {
    if (survey == null || index == 0) return const [];
    final qs = survey!.questions;
    int startOfThisPage = 0;
    for (int k = index; k >= 1; k--) {
      if (qs[k].pageBreakBefore) {
        startOfThisPage = k;
        break;
      }
    }
    if (startOfThisPage == 0) return const [];
    return qs.sublist(0, startOfThisPage);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && survey == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (survey == null)
      return const Scaffold(
          body: Center(
              child: Text('Опрос не найден',
                  style: TextStyle(fontFamily: 'HSESans'))));
    final s = survey!;
    final wide = MediaQuery.of(context).size.width > 980;
    final published = s.status == SurveyStatus.published;

    return Scaffold(
      backgroundColor: HseColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'К списку',
          onPressed: () => context.go('/'),
        ),
        title: TextField(
          controller: _titleCtrl,
          style: const TextStyle(
              fontFamily: 'HSESans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HseColors.ink),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            hintText: 'Название опроса',
            hintStyle: TextStyle(fontFamily: 'HSESans'),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) {
            s.title = v;
            _scheduleTitleSave();
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TextButton.icon(
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Поделиться',
                  style: TextStyle(fontFamily: 'HSESans')),
              onPressed: _openShare,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Предпросмотр',
            onPressed: () => context.go('/s/${s.slug}'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Аналитика',
            onPressed: () => context.go('/analytics/${s.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            tooltip: 'Соавторы',
            onPressed: () => showDialog(
                context: context,
                builder: (_) => CollaboratorsDialog(surveyId: s.id)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: published
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('В черновик',
                        style: TextStyle(fontFamily: 'HSESans')),
                    onPressed: _publishToggle,
                  )
                : GradientButton(
                    icon: Icons.rocket_launch_rounded,
                    onPressed: _publishToggle,
                    child: const Text('Опубликовать',
                        style: TextStyle(fontFamily: 'HSESans')),
                  ),
          ),
        ],
      ),
      body: Row(children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
                children: [
                  _StatusBadge(status: s.status),
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: TextField(
                      controller: _descCtrl,
                      style: const TextStyle(fontSize: 15, height: 1.45),
                      decoration: const InputDecoration(
                        hintText: 'Добавьте описание опроса (необязательно)',
                        hintStyle: TextStyle(fontFamily: 'HSESans'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      maxLines: null,
                      onChanged: (v) {
                        s.description = v;
                        _scheduleTitleSave();
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (s.questions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: HseColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: HseColors.primary, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text('Добавьте первый вопрос',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 6),
                          const Text('Выберите тип в правой панели →',
                              style: TextStyle(
                                  fontFamily: 'HSESans',
                                  color: HseColors.muted)),
                        ]),
                      ),
                    )
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: _onReorder,
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: Transform.scale(scale: 1.02, child: child),
                      ),
                      children: [
                        for (int i = 0; i < s.questions.length; i++)
                          QuestionEditor(
                            key: ValueKey(s.questions[i].id),
                            index: i,
                            question: s.questions[i],
                            availableTriggers: _availableTriggers(i),
                            expanded: _expandedQid == s.questions[i].id,
                            onTap: () => setState(() => _expandedQid =
                                _expandedQid == s.questions[i].id
                                    ? null
                                    : s.questions[i].id),
                            onChanged: (q) =>
                                setState(() => s.questions[i] = q),
                            onSave: () => _scheduleQuestionSave(s.questions[i]),
                            onDelete: () => _deleteQuestion(s.questions[i]),
                            onTogglePageBreak:
                                i == 0 ? null : () => _togglePageBreak(i),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (wide)
          Container(
            width: 340,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: HseColors.border)),
            ),
            child: SurveySettingsPanel(
              survey: s,
              onAddQuestion: _addQuestion,
              onSettingsChanged: (data) async {
                final updated = await _api.update(s.id, data);
                setState(() => survey = updated);
              },
              onCreateVariant: _createVariant,
              onOpenVariant: (vid) => context.go('/builder/$vid'),
              onChangeVariantWeight: _changeVariantWeight,
              onDeleteVariant: _deleteVariant,
            ),
          ),
      ]),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label:
                  const Text('Вопрос', style: TextStyle(fontFamily: 'HSESans')),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.85,
                  builder: (_, scroll) => SurveySettingsPanel(
                    survey: s,
                    onAddQuestion: (t) {
                      Navigator.pop(context);
                      _addQuestion(t);
                    },
                    onSettingsChanged: (data) async {
                      final updated = await _api.update(s.id, data);
                      setState(() => survey = updated);
                    },
                    onCreateVariant: () async {
                      Navigator.pop(context);
                      await _createVariant();
                    },
                    onOpenVariant: (vid) {
                      Navigator.pop(context);
                      context.go('/builder/$vid');
                    },
                    onChangeVariantWeight: _changeVariantWeight,
                    onDeleteVariant: _deleteVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SurveyStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (status) {
      SurveyStatus.draft => (
          HseColors.surfaceAlt,
          HseColors.inkSoft,
          'Черновик',
          Icons.edit_note_rounded
        ),
      SurveyStatus.published => (
          const Color(0x1A2E9D6E),
          HseColors.success,
          'Опубликован',
          Icons.public_rounded
        ),
      SurveyStatus.closed => (
          const Color(0x1AE05656),
          HseColors.danger,
          'Закрыт',
          Icons.lock_outline_rounded
        ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration:BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(999)),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: 'HSESans',
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  fontSize: 14,
                  height: 1)),
        ]),
      ),
    );
  }
}
