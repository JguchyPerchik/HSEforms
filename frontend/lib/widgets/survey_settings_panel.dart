import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class SurveySettingsPanel extends StatelessWidget {
  final Survey survey;
  final void Function(QuestionType) onAddQuestion;
  final Future<void> Function(Map<String, dynamic>) onSettingsChanged;
  final Future<void> Function()? onCreateVariant;
  final void Function(int variantId)? onOpenVariant;
  final Future<void> Function(int variantId, double weight)? onChangeVariantWeight;
  final Future<void> Function(int variantId)? onDeleteVariant;
  /// Сбросить round-robin счётчик опроса (вернуть к началу очереди).
  final Future<void> Function()? onResetAssignment;

  const SurveySettingsPanel({
    super.key, required this.survey,
    required this.onAddQuestion, required this.onSettingsChanged,
    this.onCreateVariant, this.onOpenVariant,
    this.onChangeVariantWeight, this.onDeleteVariant,
    this.onResetAssignment,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(text: 'ДОБАВИТЬ ВОПРОС'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in QuestionType.values) _QuestionTypeChip(type: t, onTap: () => onAddQuestion(t)),
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
        const SizedBox(height: 28),
        _SectionHeader(text: 'A/B И ВИНЬЕТКИ'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HseColors.surfaceAlt,
            borderRadius: BorderRadius.circular(HseRadius.md),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shuffle_rounded, size: 18, color: HseColors.primaryBright),
              const SizedBox(width: 8),
              const Text('Как это работает', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Создайте 2+ вариантов опроса. Респондентам можно раздавать '
              'их случайно (по весам) или строго по очереди — выберите ниже.',
              style: TextStyle(color: HseColors.inkSoft, fontSize: 13, height: 1.4),
            ),
          ]),
        ),
        if (survey.parentSurveyId == null && survey.variants.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AssignmentModeSelector(
            mode: survey.assignmentMode,
            onChanged: (m) => onSettingsChanged({'assignment_mode': m}),
            onReset: onResetAssignment,
          ),
        ],
        const SizedBox(height: 12),
        if (survey.parentSurveyId != null) Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x1A234B9B),
            borderRadius: BorderRadius.circular(HseRadius.md),
          ),
          child: Row(children: [
            Icon(Icons.account_tree_rounded, color: HseColors.primaryBright, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Этот опрос — вариант. Управляйте им через родительский.',
              style: TextStyle(fontSize: 12.5, color: HseColors.primary, fontWeight: FontWeight.w600),
            )),
          ]),
        ) else ...[
          Row(children: [
            Expanded(child: Text(
              survey.variants.isEmpty ? 'Вариантов пока нет' : 'Варианты (${survey.variants.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            )),
            if (onCreateVariant != null) TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Добавить'),
              onPressed: () => onCreateVariant!(),
            ),
          ]),
          const SizedBox(height: 6),
          if (survey.variants.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: HseColors.surface,
                borderRadius: BorderRadius.circular(HseRadius.md),
                border: Border.all(color: HseColors.border, style: BorderStyle.solid, width: 1),
              ),
              child: const Text(
                'Нажмите «Добавить», чтобы создать копию текущего опроса. ',
                style: TextStyle(color: HseColors.muted, fontSize: 12.5, height: 1.4),
              ),
            )
          else ...[
            _VariantRow(
              label: survey.variantLabel ?? 'Основной',
              weight: survey.variantWeight,
              isMain: true,
              onOpen: null,
              onChangeWeight: null,
              onDelete: null,
            ),
            ...survey.variants.map((v) => _VariantRow(
              label: v.variantLabel ?? v.title,
              weight: v.variantWeight,
              isMain: false,
              onOpen: onOpenVariant != null ? () => onOpenVariant!(v.id) : null,
              onChangeWeight: onChangeVariantWeight != null
                  ? (w) => onChangeVariantWeight!(v.id, w)
                  : null,
              onDelete: onDeleteVariant != null ? () => onDeleteVariant!(v.id) : null,
            )),
          ],
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
        color: HseColors.muted, fontSize: 11,
        fontWeight: FontWeight.w800, letterSpacing: 1.2,
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Setting({required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: HseColors.muted, fontSize: 12)),
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
      case QuestionType.short_text: return Icons.short_text_rounded;
      case QuestionType.long_text: return Icons.notes_rounded;
      case QuestionType.single_choice: return Icons.radio_button_checked_rounded;
      case QuestionType.multiple_choice: return Icons.check_box_outlined;
      case QuestionType.dropdown: return Icons.expand_circle_down_outlined;
      case QuestionType.scale: return Icons.linear_scale_rounded;
      // case QuestionType.rating: return Icons.star_outline_rounded;
      // case QuestionType.number: return Icons.numbers_rounded;
      // case QuestionType.date: return Icons.calendar_today_rounded;
      // case QuestionType.email: return Icons.alternate_email_rounded;
      case QuestionType.section_header: return Icons.title_rounded;
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
            Text(type.human, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
  const _AssignmentModeSelector({
    required this.mode,
    required this.onChanged,
    this.onReset,
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
            child: const Text('Отмена', style: TextStyle(fontFamily: 'HSESans')),
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
          const SnackBar(content: Text('Счётчик сброшен',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Раздача вариантов',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          // SegmentedButton + ширина 340px у боковой панели = переполнение.
          // Делаем компактные радио-чипы вертикально.
          _ModeOption(
            selected: mode == 'random',
            icon: Icons.casino_outlined,
            title: 'Случайно (по весам)',
            subtitle: 'Каждый респондент получает вариант случайно. Веса '
                'задают пропорцию на большой выборке.',
            onTap: () => onChanged('random'),
          ),
          const SizedBox(height: 6),
          _ModeOption(
            selected: isRR,
            icon: Icons.format_list_numbered_rounded,
            title: 'По очереди',
            subtitle: 'Респонденты по очереди получают варианты в '
                'круг. Точное равное распределение на малой выборке.',
            onTap: () => onChanged('round_robin'),
          ),
          if (isRR && onReset != null) ...[
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
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
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
            Icon(icon, size: 18,
                color: selected ? HseColors.primary : HseColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

class _VariantRow extends StatelessWidget {
  final String label;
  final double weight;
  final bool isMain;
  final VoidCallback? onOpen;
  final ValueChanged<double>? onChangeWeight;
  final VoidCallback? onDelete;
  const _VariantRow({
    required this.label, required this.weight, required this.isMain,
    this.onOpen, this.onChangeWeight, this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: isMain ? HseColors.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(HseRadius.md),
        border: Border.all(color: HseColors.border, width: 1.2),
      ),
      child: Row(children: [
        Icon(isMain ? Icons.bookmark_rounded : Icons.science_outlined, size: 16, color: HseColors.primaryBright),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('Вес: ${weight.toStringAsFixed(1)}', style: const TextStyle(color: HseColors.muted, fontSize: 11)),
          ]),
        ),
        if (onOpen != null) IconButton(
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          tooltip: 'Открыть вариант',
          onPressed: onOpen,
        ),
        if (onDelete != null) IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          tooltip: 'Удалить вариант',
          onPressed: onDelete,
        ),
      ]),
    );
  }
}
