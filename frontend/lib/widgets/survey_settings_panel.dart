import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Дефолтный шаблон информированного согласия. Подставляется в
/// `survey.consent_text`, когда автор впервые включает соответствующий
/// тумблер. Текст составлен под академические опросы (соц.науки,
/// психология) — содержит обязательные смысловые блоки: цель, что
/// потребуется, конфиденциальность, добровольность, контакты. Поля в
/// квадратных скобках автор должен заполнить под своё исследование.
///
/// Юридическая сила текста — ответственность автора опроса. Если опрос
/// собирает чувствительные данные (медицинские, ФИО, контакты), такой
/// шаблон стоит дополнительно согласовать с этическим комитетом.
const String kDefaultConsentText =
    'Информированное согласие на участие в исследовании\n\n'
    'Уважаемый респондент!\n\n'
    'Вам предлагается принять участие в исследовании. Перед тем, как '
    'продолжить, пожалуйста, ознакомьтесь с условиями участия.\n\n'
    'Цель исследования: [укажите цель исследования].\n\n'
    'Что от вас потребуется: заполнение этой анкеты, занимающее '
    'примерно [укажите время] минут.\n\n'
    'Конфиденциальность: ваши ответы будут использоваться только в '
    'обобщённом виде в исследовательских целях. Персональные данные не '
    'передаются третьим лицам и не используются для коммерческих целей.\n\n'
    'Анонимность: вы можете участвовать в исследовании анонимно. '
    'Идентифицирующая информация (имя, контакты) собирается только если '
    'это явно указано в анкете.\n\n'
    'Добровольность: ваше участие полностью добровольное. Вы можете '
    'отказаться от прохождения в любой момент, закрыв вкладку браузера. '
    'Незавершённые ответы не сохраняются.\n\n'
    'Контакты исследователя: [укажите ФИО и email для вопросов].\n\n'
    'Нажимая «Принять», вы подтверждаете, что ознакомились с условиями '
    'и даёте согласие на обработку ваших ответов в рамках указанного '
    'исследования.';

class SurveySettingsPanel extends StatelessWidget {
  /// Опрос, который пользователь сейчас редактирует. Может быть как
  /// корневым (parent_survey_id == null), так и одним из вариантов.
  final Survey survey;

  /// Корневой опрос — заполнен, только если [survey] сам является вариантом.
  /// Используется, чтобы отрисовать полный список табов (root + все
  /// варианты) внутри child-view; без этого список братьев был недоступен
  /// и приходилось вручную возвращаться в parent.
  final Survey? parent;

  /// ID текущего открытого опроса. Нужен для подсветки активного таба и
  /// для блокировки клика «открыть себя же». Можно было бы взять из
  /// [survey].id, но явный параметр читается понятнее на месте вызова.
  final int currentSurveyId;

  final void Function(QuestionType) onAddQuestion;
  final Future<void> Function(Map<String, dynamic>) onSettingsChanged;
  final Future<void> Function()? onCreateVariant;
  final void Function(int variantId)? onOpenVariant;
  final Future<void> Function(int variantId, double weight)?
      onChangeVariantWeight;
  final Future<void> Function(int variantId)? onDeleteVariant;

  /// Сбросить round-robin счётчик опроса (вернуть к началу очереди).
  final Future<void> Function()? onResetAssignment;

  const SurveySettingsPanel({
    super.key,
    required this.survey,
    required this.currentSurveyId,
    this.parent,
    required this.onAddQuestion,
    required this.onSettingsChanged,
    this.onCreateVariant,
    this.onOpenVariant,
    this.onChangeVariantWeight,
    this.onDeleteVariant,
    this.onResetAssignment,
  });

  /// Корневой опрос: либо отдельно переданный [parent], либо сам [survey],
  /// если у него нет родителя. Список вариантов берётся отсюда.
  Survey get _root => parent ?? survey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(text: 'ДОБАВИТЬ ВОПРОС'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in QuestionType.values)
            _QuestionTypeChip(type: t, onTap: () => onAddQuestion(t)),
        ]),
        const SizedBox(height: 28),
        _SectionHeader(text: 'НАСТРОЙКИ ОПРОСА'),
        const SizedBox(height: 6),
        _Setting(
          title: 'Анонимный',
          subtitle: 'Не привязывать ответы к пользователю',
          value: survey.isAnonymous,
          onChanged: (v) => onSettingsChanged({'is_anonymous': v}),
        ),
        _Setting(
          title: 'Один ответ от пользователя',
          subtitle: 'Запретить повторное прохождение',
          value: survey.oneResponsePerUser,
          onChanged: (v) => onSettingsChanged({'one_response_per_user': v}),
        ),
        _Setting(
          title: 'Возврат к предыдущим вопросам',
          subtitle: 'Кнопка «Назад» во время прохождения',
          value: survey.allowBackNavigation,
          onChanged: (v) => onSettingsChanged({'allow_back_navigation': v}),
        ),
        _Setting(
          title: 'Прогресс-бар',
          subtitle: 'Показывать, сколько осталось страниц',
          value: survey.showProgress,
          onChanged: (v) => onSettingsChanged({'show_progress': v}),
        ),
        // Информированное согласие. При включении тумблера, если текст
        // согласия ещё не задан, сразу же отправляем на backend дефолтный
        // шаблон — иначе пользователь увидит пустой редактор и не поймёт,
        // что нужно вписать. Дефолт можно редактировать, перезаписав
        // под своё исследование.
        _Setting(
          title: 'Информированное согласие',
          subtitle: 'Модальное окно с согласием перед прохождением опроса',
          value: survey.consentRequired,
          onChanged: (v) {
            final updates = <String, dynamic>{'consent_required': v};
            if (v &&
                (survey.consentText == null ||
                    survey.consentText!.trim().isEmpty)) {
              updates['consent_text'] = kDefaultConsentText;
            }
            onSettingsChanged(updates);
          },
        ),
        if (survey.consentRequired)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: _ConsentEditor(
              key: ValueKey('consent-${survey.id}'),
              initialText: survey.consentText ?? kDefaultConsentText,
              onChanged: (t) => onSettingsChanged({'consent_text': t}),
            ),
          ),
        const SizedBox(height: 28),
        _SectionHeader(text: 'A/B И ВИНЬЕТКИ'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HseColors.surfaceAlt,
            borderRadius: BorderRadius.circular(HseRadius.md),
          ),
          child:
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shuffle_rounded,
                  size: 18, color: HseColors.primaryBright),
              SizedBox(width: 8),
              Text('Как это работает',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            SizedBox(height: 6),
            Text(
              'Создайте 2+ вариантов опроса. '
              'Выберите ниже, как система будет их распределять: случайным образом (по весам) или по очереди',
              style: TextStyle(
                  color: HseColors.inkSoft, fontSize: 13, height: 1.4),
            ),
          ]),
        ),
        // Селектор «как раздавать» актуален только если у корня есть хотя
        // бы один child-вариант. Берём состояние с КОРНЯ — `assignment_mode`
        // живёт там, у вариантов это поле игнорируется.
        if (_root.variants.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AssignmentModeSelector(
            mode: _root.assignmentMode,
            // Изменение режима всегда уезжает на корень. Если мы сейчас в
            // child'е — onSettingsChanged уйдёт на текущий survey id, что
            // НЕправильно. На уровне родителя поле есть и работает; для
            // child'а смена режима через эту панель просто не имеет смысла,
            // поэтому ниже onChanged заворачиваем в дисэйбл для child-view.
            onChanged: (m) => onSettingsChanged({'assignment_mode': m}),
            onReset: onResetAssignment,
            disabled: parent != null, // в child'е режим не редактируется
          ),
        ],
        const SizedBox(height: 12),

        // ─── Список вариантов: всегда видимый, кликабельный, с подсветкой ───
        //
        // Раньше блок прятался под условием `parentSurveyId == null` и в
        // child'е заменялся плашкой «управляйте через родительский». Новое
        // поведение: список ВСЕГДА показан, текущий открытый вариант
        // подсвечен рамкой+фоном и некликабельный, остальные кликаются как
        // табы — клик дёргает onOpenVariant, который ведёт на /builder/<id>.
        Row(children: [
          Expanded(
              child: Text(
            _root.variants.isEmpty
                ? 'Вариантов пока нет'
                : 'Варианты (${_root.variants.length + 1})', // +1 за основной
            style: const TextStyle(fontWeight: FontWeight.w700),
          )),
          if (onCreateVariant != null)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Добавить'),
              onPressed: () => onCreateVariant!(),
            ),
        ]),
        const SizedBox(height: 6),
        if (_root.variants.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: HseColors.surface,
              borderRadius: BorderRadius.circular(HseRadius.md),
              border: Border.all(color: HseColors.border, width: 1),
            ),
            child: const Text(
              'Нажмите «Добавить», чтобы создать копию текущего опроса. ',
              style: TextStyle(
                  color: HseColors.muted, fontSize: 12.5, height: 1.4),
            ),
          )
        else ...[
          // Корневой опрос — всегда первой строкой как «Основной». Клик
          // переключает на него (если мы сейчас в child'е), либо
          // disabled (если мы и так на нём).
          _VariantRow(
            label: _root.variantLabel ?? 'Основной',
            weight: _root.variantWeight,
            isMain: true,
            isCurrent: _root.id == currentSurveyId,
            // На root удалить нельзя — через эту панель снести можно только
            // child-варианты. Поэтому onDelete всегда null.
            onSelect: _root.id == currentSurveyId
                ? null
                : (onOpenVariant != null
                    ? () => onOpenVariant!(_root.id)
                    : null),
            onDelete: null,
          ),
          ..._root.variants.map((v) => _VariantRow(
                label: v.variantLabel ?? v.title,
                weight: v.variantWeight,
                isMain: false,
                isCurrent: v.id == currentSurveyId,
                onSelect: v.id == currentSurveyId
                    ? null // мы уже здесь — не даём кликнуть на самого себя
                    : (onOpenVariant != null
                        ? () => onOpenVariant!(v.id)
                        : null),
                onDelete: onDeleteVariant != null
                    ? () => onDeleteVariant!(v.id)
                    : null,
              )),
        ],
        const SizedBox(height: 28),
        _SectionHeader(text: 'ССЫЛКА'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HseColors.surface,
            borderRadius: BorderRadius.circular(HseRadius.md),
          ),
          child: SelectableText(
            '/s/${survey.slug}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: HseColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Setting(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: HseColors.muted, fontSize: 12)),
        ])),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _QuestionTypeChip extends StatelessWidget {
  final QuestionType type;
  final VoidCallback onTap;
  const _QuestionTypeChip({required this.type, required this.onTap});

  IconData get _icon {
    switch (type) {
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
      // case QuestionType.rating: return Icons.star_outline_rounded;
      // case QuestionType.number: return Icons.numbers_rounded;
      // case QuestionType.date: return Icons.calendar_today_rounded;
      // case QuestionType.email: return Icons.alternate_email_rounded;
      case QuestionType.section_header:
        return Icons.title_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(HseRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(HseRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HseRadius.md),
            border: Border.all(color: HseColors.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_icon, size: 16, color: HseColors.primary),
            const SizedBox(width: 6),
            Text(type.human,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _AssignmentModeSelector extends StatelessWidget {
  final String mode;
  final Future<void> Function(String) onChanged;
  final Future<void> Function()? onReset;

  /// true — селектор показан, но клики и кнопка сброса отключены.
  /// Используется, когда панель открыта из child-варианта: режим раздачи
  /// и счётчик живут на корне, менять их «через child» не имеет смысла —
  /// бэк бы отверг (или хуже, тихо записал поле в child, где оно не
  /// читается). Показываем «как есть», чтобы было видно текущий режим,
  /// плюс подсказка, что менять надо из основного.
  final bool disabled;
  const _AssignmentModeSelector({
    required this.mode,
    required this.onChanged,
    this.onReset,
    this.disabled = false,
  });

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Сбросить распределение?',
            style: TextStyle(fontFamily: 'HSESans')),
        content: const Text(
          'Счётчик «по очереди» обнулится — следующий респондент получит '
          'первый вариант. Сами ответы и веса вариантов не изменятся.',
          style: TextStyle(fontFamily: 'HSESans'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Отмена', style: TextStyle(fontFamily: 'HSESans')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HseColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok == true && onReset != null) {
      await onReset!();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Счётчик сброшен',
                  style: TextStyle(fontFamily: 'HSESans'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRR = mode == 'round_robin';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HseRadius.md),
        border: Border.all(color: HseColors.border, width: 1.2),
      ),
      child: Opacity(
        // Визуально приглушаем весь блок в disabled-режиме, чтобы было
        // ясно: смотреть можно, менять нельзя.
        opacity: disabled ? 0.55 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Распределение вариантов',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            // SegmentedButton + ширина 340px у боковой панели = переполнение.
            // Делаем компактные радио-чипы вертикально.
            _ModeOption(
              selected: mode == 'random',
              icon: Icons.casino_outlined,
              title: 'Случайно (по весам)',
              subtitle: 'Вариант опроса определяется случайным образом. '
                  'Заданные веса обеспечивают нужное процентное соотношение на больших выборках.',
              onTap: disabled ? null : () => onChanged('random'),
            ),
            const SizedBox(height: 6),
            _ModeOption(
              selected: isRR,
              icon: Icons.format_list_numbered_rounded,
              title: 'По очереди',
              subtitle:
                  'Респонденты получают варианты последовательно по кругу. '
                  'Гарантирует строго равное разделение групп даже на малых выборках.',
              onTap: disabled ? null : () => onChanged('round_robin'),
            ),
            if (isRR && onReset != null && !disabled) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Сбросить счётчик',
                      style: TextStyle(fontFamily: 'HSESans')),
                  onPressed: () => _confirmReset(context),
                ),
              ),
            ],
            if (disabled) ...[
              const SizedBox(height: 8),
              const Text(
                'Открыто из варианта. Чтобы изменить режим — переключитесь '
                'на «Основной» в списке выше.',
                style: TextStyle(
                  color: HseColors.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;

  /// null — опция показана, но не реагирует на тап (disabled-режим).
  /// Используется, когда селектор открыт из child-варианта (см.
  /// [_AssignmentModeSelector.disabled]).
  final VoidCallback? onTap;
  const _ModeOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HseColors.primary.withOpacity(0.07) : Colors.white,
      borderRadius: BorderRadius.circular(HseRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(HseRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HseRadius.sm),
            border: Border.all(
              color: selected ? HseColors.primary : HseColors.border,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                size: 18,
                color: selected ? HseColors.primary : HseColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected ? HseColors.primary : HseColors.ink,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                          color: HseColors.muted,
                          fontSize: 11.5,
                          height: 1.35,
                        )),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Строка-таб варианта. Раньше переключение было через отдельную иконку
/// «open_in_new» — пользователь её часто пропускал и не понимал, как
/// переключиться. Теперь вся строка — большая кликабельная зона. Активный
/// вариант не имеет onSelect (null) и визуально подсвечен «выбранным».
class _VariantRow extends StatelessWidget {
  final String label;
  final double weight;

  /// true — корневой опрос. Влияет на иконку и подпись «Основной».
  final bool isMain;

  /// true — этот вариант сейчас открыт. На него нельзя кликнуть.
  final bool isCurrent;

  /// null — строка некликабельна (это активный вариант, или нет коллбэка).
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;
  const _VariantRow({
    required this.label,
    required this.weight,
    required this.isMain,
    required this.isCurrent,
    this.onSelect,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    // Подбор стилей под три состояния: активный / кликабельный / disabled.
    final Color bg;
    final Color borderColor;
    final double borderWidth;
    if (isCurrent) {
      // Активный таб — наиболее яркий: primary-tint фон + жирная primary рамка.
      bg = HseColors.primary.withOpacity(0.09);
      borderColor = HseColors.primary;
      borderWidth = 1.6;
    } else if (isMain) {
      // Корневой опрос (не текущий) — нейтральный, чтобы не путать с активным.
      bg = HseColors.surfaceAlt;
      borderColor = HseColors.border;
      borderWidth = 1.2;
    } else {
      bg = Colors.white;
      borderColor = HseColors.border;
      borderWidth = 1.2;
    }

    final content = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(HseRadius.md),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(children: [
        Icon(
          isMain ? Icons.bookmark_rounded : Icons.science_outlined,
          size: 16,
          color: isCurrent ? HseColors.primary : HseColors.primaryBright,
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isCurrent ? HseColors.primary : HseColors.ink,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: HseColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'открыт',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ]),
            Text('Вес: ${weight.toStringAsFixed(1)}',
                style: const TextStyle(color: HseColors.muted, fontSize: 11)),
          ]),
        ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            tooltip: 'Удалить вариант',
            onPressed: onDelete,
            // Иконка удаления внутри кликабельной строки — её собственный
            // onTap «всплыл» бы и до родительского InkWell тоже, дёргая
            // переключение. Закрываем splash и не даём событию подняться.
          ),
      ]),
    );

    // Если строка активна или нет колбэка — отдаём контейнер как есть,
    // без InkWell (никакого ripple/cursor pointer). Иначе оборачиваем
    // в Material+InkWell для нормального tap-feedback.
    if (onSelect == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(HseRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(HseRadius.md),
        onTap: onSelect,
        child: content,
      ),
    );
  }
}

/// Редактор текста информированного согласия. Многострочный TextField
/// с debounce-сохранением (700 мс): на сервер уходит только финальная
/// версия после паузы в наборе, чтобы не дёргать API на каждое нажатие
/// клавиши. Стандартный паттерн для авто-сохраняющихся полей в
/// builder'е опроса (см. также автосохранение заголовка и описания).
class _ConsentEditor extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  const _ConsentEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
  });

  @override
  State<_ConsentEditor> createState() => _ConsentEditorState();
}

class _ConsentEditorState extends State<_ConsentEditor> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onLocalChange(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HseColors.surfaceAlt,
        borderRadius: BorderRadius.circular(HseRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Текст согласия',
          style: TextStyle(
            color: HseColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        // Многострочное поле без ограничения высоты — растёт по содержимому
        // до 14 строк, после чего появляется внутренний скролл.
        TextField(
          controller: _ctrl,
          minLines: 5,
          maxLines: 14,
          onChanged: _onLocalChange,
          style: const TextStyle(fontSize: 12.5, height: 1.4),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HseRadius.sm),
              borderSide: const BorderSide(color: HseColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HseRadius.sm),
              borderSide: const BorderSide(color: HseColors.border),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Замените текст в квадратных скобках на сведения о вашем '
          'исследовании. Если опрос собирает чувствительные данные, '
          'согласуйте текст с этическим комитетом.',
          style: TextStyle(
            color: HseColors.muted,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ]),
    );
  }
}
