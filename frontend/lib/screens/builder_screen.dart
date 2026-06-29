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
import '../widgets/import_dialog.dart';

class BuilderScreen extends StatefulWidget {
  final int surveyId;
  const BuilderScreen({super.key, required this.surveyId});
  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());
  Survey? survey;
  /// Родительский опрос, если текущий — child-вариант. Нужен затем, чтобы
  /// правая панель могла отрисовать ПОЛНЫЙ список вариантов (parent +
  /// siblings) даже когда мы открыли один из вариантов, а не корень.
  /// Без этого, находясь в child'е, нельзя было увидеть братьев и
  /// перепрыгнуть на них одним кликом — приходилось возвращаться в parent.
  Survey? _parent;
  bool _busy = false;
  int? _expandedQid;
  Timer? _titleSaveTimer;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  /// Корневой опрос — parent (если мы в child) или сам survey (если мы и
  /// есть parent). От него считаются: список вариантов, target для
  /// создания нового варианта, и URL «возврата» при удалении текущего.
  Survey get _root => _parent ?? survey!;

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
      // Если открыт child-вариант — параллельно подтягиваем родителя, чтобы
      // в правой панели сразу был полный список братьев. Один лишний GET
      // на каждом входе в child — приемлемая цена за то, чтобы не пилить
      // backend (там сейчас Survey.variants для child пустой; альтернатива —
      // менять `_to_detail`, чтобы для child он отдавал siblings, но это
      // больше изменение API на меньший выигрыш).
      if (s.parentSurveyId != null) {
        try {
          _parent = await _api.get(s.parentSurveyId!);
        } catch (_) {
          // Если parent недоступен (например, удалён) — просто не покажем
          // список вариантов. Сам child всё равно открыт и редактируется.
          _parent = null;
        }
      } else {
        _parent = null;
      }
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
        // type ОБЯЗАН быть в payload: без него смена типа (например,
        // single_choice → multiple_choice) применяется только локально и
        // откатывается при следующей загрузке опроса. Бэкенд принимает
        // QuestionType | None в QuestionUpdate — если поле не пришло,
        // exclude_unset=True его проигнорирует.
        'type': q.type.name,
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
      // CRITICAL: do NOT replace the local Question object with the server
      // response. Between issuing the save and receiving it, the user may have
      // typed more — those keystrokes mutated the local Question and its
      // options. Replacing the reference would discard them AND invalidate
      // every ObjectKey/identityHashCode-based widget key under this question,
      // causing State (and TextEditingController text) to be wiped.
      //
      // We only need server-assigned IDs for newly created options so that
      // the next save can drop the temporary negative IDs. Patch them in place.
      setState(() {
        for (int k = 0; k < q.options.length && k < updated.options.length; k++) {
          q.options[k].id = updated.options[k].id;
        }
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

    // Куда вставлять. Если есть раскрытый вопрос — сразу после него
    // (типичный сценарий: пользователь читает длинный опрос, кликнул на
    // вопрос, хочет добавить следующий рядом — а не мотать в конец).
    // Если ничего не раскрыто — в конец, как было.
    int insertIdx;
    if (_expandedQid != null) {
      final exp =
          survey!.questions.indexWhere((x) => x.id == _expandedQid);
      insertIdx = exp == -1 ? survey!.questions.length : exp + 1;
    } else {
      insertIdx = survey!.questions.length;
    }

    setState(() {
      survey!.questions.insert(insertIdx, q);
      _expandedQid = q.id;
    });

    // Если вставили не в самый конец — нужно синхронизировать порядок
    // на сервере. Бэк уже добавил вопрос с position = last+1, но
    // относительно списка он окажется не там, где мы его показываем.
    // Reorder перенумерует position-ы строго по нашему порядку.
    //
    // ВАЖНО: ответ reorder'а игнорируем — НЕ заменяем локальные объекты
    // на серверные. Иначе если параллельно идёт debounced-сохранение
    // другого вопроса, мы перезапишем уже набранный текст серверной
    // (ещё не дошедшей) версией. Локально позиции в списке уже верные,
    // поле position у Question.toJson всё равно не передаётся в update.
    if (insertIdx < survey!.questions.length - 1) {
      final ids = survey!.questions.map((x) => x.id).toList();
      try {
        await _api.reorder(widget.surveyId, ids);
      } catch (_) {
        // Не критично: render по индексу списка, не по полю position.
      }
    }
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
    // Считаем номер варианта от корня, а не от текущего опроса — иначе при
    // создании варианта изнутри child'а буква бы сбилась (у child массив
    // variants пустой, и каждый новый получал бы букву B).
    final letter = String.fromCharCode(65 + _root.variants.length + 1);
    await _api.create(
      title: '${_root.title} — Вариант $letter',
      // Все варианты висят на корне (root), а не на сиблингах. Это
      // важно: если бы parentId был current id, мы бы получили дерево
      // глубиной >1, а раздача вариантов в pick_variant работает только
      // с плоским списком потомков корня.
      parentId: _root.id,
      variantLabel: 'Вариант $letter',
      variantWeight: 1.0,
    );
    // Просто обновляем — новый вариант появится строкой в правой панели,
    // оттуда пользователь сам решит, переключаться на него или нет.
    // Раньше тут был SnackBar «Открыть для редактирования?» — он отвлекал
    // от текущей работы и дублировал функционал, который теперь живёт в
    // правой панели (вся строка варианта — кликабельный таб).
    await _load();
  }

  Future<void> _changeVariantWeight(int variantId, double weight) async {
    await _api.update(variantId, {'variant_weight': weight});
    await _load();
  }

  Future<void> _resetAssignment() async {
    if (survey == null) return;
    try {
      await _api.resetAssignment(survey!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Не удалось сбросить счётчик: $e',
              style: const TextStyle(fontFamily: 'HSESans')),
        ));
      }
    }
  }

  Future<void> _deleteVariant(int variantId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить вариант?',
            style: TextStyle(fontFamily: 'HSESans')),
        content: const Text(
            'Уже собранные ответы по этому варианту тоже удалятся.',
            style: TextStyle(fontFamily: 'HSESans')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена',
                  style: TextStyle(fontFamily: 'HSESans'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HseColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _api.delete(variantId);
      if (!mounted) return;
      // Если удалили вариант, на котором сейчас находимся, URL станет
      // невалидным (на /builder/<deleted-id> бэк ответит 404). Прыгаем
      // на корень — он всегда жив, потому что удалить его через эту кнопку
      // нельзя (у root в правой панели нет иконки удаления).
      if (variantId == survey!.id) {
        context.go('/builder/${_root.id}');
      } else {
        await _load();
      }
    }
  }

  void _openShare() {
    showDialog(context: context, builder: (_) => ShareDialog(survey: survey!));
  }

  /// Импорт структуры опроса из Google Forms / Яндекс Форм.
  /// onImported получает обновлённый Survey (с дописанными вопросами) —
  /// заменяем им локальное состояние, чтобы экран мгновенно отрисовал
  /// новые вопросы без дополнительного GET.
  void _openImport() {
    if (survey == null) return;
    showDialog(
      context: context,
      builder: (_) => ImportDialog(
        surveyId: survey!.id,
        onImported: (updated) {
          if (!mounted) return;
          setState(() => survey = updated);
        },
      ),
    );
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
    final width = MediaQuery.of(context).size.width;
    final wide = width > 980;
    final compact = width < 720;
    final published = s.status == SurveyStatus.published;

    // Полный набор действий — раскладывается по-разному для desktop/mobile.
    final shareAction = compact
        ? IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Поделиться',
            onPressed: _openShare,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TextButton.icon(
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Поделиться',
                  style: TextStyle(fontFamily: 'HSESans')),
              onPressed: _openShare,
            ),
          );

    final previewBtn = IconButton(
      icon: const Icon(Icons.visibility_outlined),
      tooltip: 'Предпросмотр',
      onPressed: () => context.go('/s/${s.slug}?preview=true'),
    );
    final analyticsBtn = IconButton(
      icon: const Icon(Icons.bar_chart_rounded),
      tooltip: 'Аналитика',
      onPressed: () => context.go('/analytics/${s.id}'),
    );
    final collaboratorsBtn = IconButton(
      icon: const Icon(Icons.people_outline_rounded),
      tooltip: 'Соавторы',
      onPressed: () => showDialog(
          context: context,
          builder: (_) => CollaboratorsDialog(surveyId: s.id)),
    );
    final importBtn = IconButton(
      icon: const Icon(Icons.cloud_download_outlined),
      tooltip: 'Импорт из Google / Яндекс Форм',
      onPressed: _openImport,
    );

    // Кнопка публикации: на узких экранах — компактная иконка, иначе — полноценная.
    final publishWidget = published
        ? (compact
            ? IconButton(
                icon: const Icon(Icons.pause_rounded),
                tooltip: 'В черновик',
                onPressed: _publishToggle,
              )
            : OutlinedButton.icon(
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text('В черновик',
                    style: TextStyle(fontFamily: 'HSESans')),
                onPressed: _publishToggle,
              ))
        : (compact
            ? IconButton(
                icon: const Icon(Icons.rocket_launch_rounded),
                tooltip: 'Опубликовать',
                onPressed: _publishToggle,
                color: HseColors.ink,
              )
            : GradientButton(
                icon: Icons.rocket_launch_rounded,
                onPressed: _publishToggle,
                child: const Text('Опубликовать',
                    style: TextStyle(fontFamily: 'HSESans')),
              ));

    final List<Widget> actions = compact
        ? [
            publishWidget,
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Ещё',
              onSelected: (v) {
                switch (v) {
                  case 'share':
                    _openShare();
                    break;
                  case 'preview':
                    context.go('/s/${s.slug}?preview=true');
                    break;
                  case 'analytics':
                    context.go('/analytics/${s.id}');
                    break;
                  case 'collab':
                    showDialog(
                        context: context,
                        builder: (_) => CollaboratorsDialog(surveyId: s.id));
                    break;
                  case 'import':
                    _openImport();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.ios_share_rounded),
                    title: Text('Поделиться',
                        style: TextStyle(fontFamily: 'HSESans')),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'preview',
                  child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Предпросмотр',
                        style: TextStyle(fontFamily: 'HSESans')),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'analytics',
                  child: ListTile(
                    leading: Icon(Icons.bar_chart_rounded),
                    title: Text('Аналитика',
                        style: TextStyle(fontFamily: 'HSESans')),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'collab',
                  child: ListTile(
                    leading: Icon(Icons.people_outline_rounded),
                    title: Text('Соавторы',
                        style: TextStyle(fontFamily: 'HSESans')),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.cloud_download_outlined),
                    title: Text('Импорт из Google / Яндекс Форм',
                        style: TextStyle(fontFamily: 'HSESans')),
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ]
        : [
            shareAction,
            importBtn,
            previewBtn,
            analyticsBtn,
            collaboratorsBtn,
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: publishWidget,
            ),
          ];

    return Scaffold(
      backgroundColor: HseColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'К списку',
          onPressed: () => context.go('/'),
        ),
        title: TextField(
          controller: _titleCtrl,
          style: TextStyle(
              fontFamily: 'HSESans',
              fontSize: compact ? 17 : 20,
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
        actions: actions,
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
              parent: _parent,
              currentSurveyId: s.id,
              onAddQuestion: _addQuestion,
              onSettingsChanged: (data) async {
                final updated = await _api.update(s.id, data);
                setState(() => survey = updated);
              },
              onCreateVariant: _createVariant,
              onOpenVariant: (vid) => context.go('/builder/$vid'),
              onChangeVariantWeight: _changeVariantWeight,
              onDeleteVariant: _deleteVariant,
              onResetAssignment: _resetAssignment,
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
                    parent: _parent,
                    currentSurveyId: s.id,
                    onAddQuestion: (t) {
                      Navigator.pop(context);
                      _addQuestion(t);
                    },
                    onSettingsChanged: (data) async {
                      final updated = await _api.update(s.id, data);
                      setState(() => survey = updated);
                    },
                    onCreateVariant: () async {
                      // Шит НЕ закрываем — в нём же лежит список вариантов,
                      // где появится свежесозданный. На широком экране оба
                      // меняются одинаково, на мобильном — пользователь
                      // увидит новый таб сразу и решит, кликнуть или нет.
                      await _createVariant();
                    },
                    onOpenVariant: (vid) {
                      Navigator.pop(context);
                      context.go('/builder/$vid');
                    },
                    onChangeVariantWeight: _changeVariantWeight,
                    onDeleteVariant: _deleteVariant,
                    onResetAssignment: _resetAssignment,
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
