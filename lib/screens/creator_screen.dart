// lib/screens/creator_screen.dart
// Full survey builder: drag-reorder fields, inline editing, add-question picker.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/form_field_model.dart';
import '../../../providers/creator_provider.dart';
import '../../../providers/survey_store.dart';

const _uuid = Uuid();

// ─── Accent palette ───────────────────────────────────────────────────────────

const _accentPalette = [
  '#6366F1', '#0EA5E9', '#10B981', '#F59E0B',
  '#EF4444', '#EC4899', '#8B5CF6', '#14B8A6',
];

// ─── CREATOR SCREEN ───────────────────────────────────────────────────────────

class CreatorScreen extends StatelessWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final creator = context.watch<CreatorProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _CreatorAppBar(creator: creator),
      body: Column(children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // ── Survey settings card ──────────────────────────────────
              SliverToBoxAdapter(
                child: _SurveySettingsCard().animate().slideY(begin: -0.1, duration: 300.ms).fade(),
              ),

              // ── Fields list ──────────────────────────────────────────
              if (creator.schema.fields.isEmpty)
                SliverToBoxAdapter(child: _EmptyFieldsHint())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _ReorderableFieldList(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),

        // ── Add question bar ──────────────────────────────────────────────
        _AddQuestionBar(),
      ]),
    );
  }
}

// ─── App bar ──────────────────────────────────────────────────────────────────

class _CreatorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final CreatorProvider creator;
  const _CreatorAppBar({required this.creator});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<SurveyStore>();

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          if (creator.isDirty) {
            _confirmDiscard(context, creator, store);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        creator.schema.title.isEmpty ? 'New Survey' : creator.schema.title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Save draft
        TextButton.icon(
          onPressed: () {
            creator.saveToStore(store);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Draft saved'), duration: Duration(seconds: 2)),
            );
          },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save'),
        ),
        // Publish
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            onPressed: creator.schema.fields.isEmpty
                ? null
                : () => _confirmPublish(context, creator, store),
            icon: const Icon(Icons.publish_rounded, size: 16),
            label: Text(creator.schema.status == SurveyStatus.published ? 'Update' : 'Publish'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDiscard(BuildContext ctx, CreatorProvider creator, SurveyStore store) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unsaved changes'),
        content: const Text('Save as draft before leaving?'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(_); Navigator.pop(ctx); },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              creator.saveToStore(store);
              Navigator.pop(_);
              Navigator.pop(ctx);
            },
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
  }

  void _confirmPublish(BuildContext ctx, CreatorProvider creator, SurveyStore store) {
    if (creator.schema.title.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Please add a title before publishing.')),
      );
      return;
    }
    creator.publishAndSave(store);
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('✅ Survey published!'), duration: Duration(seconds: 2)),
    );
    Navigator.pop(ctx);
  }
}

// ─── Survey settings card ─────────────────────────────────────────────────────

class _SurveySettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final creator = context.watch<CreatorProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentHex = creator.schema.accentColor ?? '#6366F1';
    Color accent;
    try {
      accent = Color(int.parse('FF${accentHex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      accent = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: accent, width: 5),
          left: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          right: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          TextField(
            controller: TextEditingController(text: creator.schema.title)
              ..selection = TextSelection.collapsed(offset: creator.schema.title.length),
            onChanged: context.read<CreatorProvider>().setTitle,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
            decoration: InputDecoration(
              hintText: 'Survey title',
              hintStyle: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800, fontSize: 22,
                color: theme.hintColor.withOpacity(0.5),
              ),
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          // Description
          TextField(
            controller: TextEditingController(text: creator.schema.description ?? ''),
            onChanged: context.read<CreatorProvider>().setDescription,
            maxLines: 2,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            decoration: InputDecoration(
              hintText: 'Survey description (optional)',
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(height: 24),

          // Options row
          Row(children: [
            // Progress bar toggle
            _ToggleChip(
              label: 'Progress bar',
              value: creator.schema.showProgressBar,
              onChanged: context.read<CreatorProvider>().setShowProgressBar,
            ),
            const SizedBox(width: 8),
            // Accent color
            _ColorPickerChip(currentHex: accentHex),
          ]),
        ]),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleChip({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? theme.colorScheme.primary.withOpacity(0.1) : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? theme.colorScheme.primary.withOpacity(0.5) : theme.dividerColor,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              size: 16, color: value ? theme.colorScheme.primary : theme.hintColor),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: value ? theme.colorScheme.primary : theme.hintColor,
              )),
        ]),
      ),
    );
  }
}

class _ColorPickerChip extends StatelessWidget {
  final String currentHex;
  const _ColorPickerChip({required this.currentHex});

  @override
  Widget build(BuildContext context) {
    Color current;
    try {
      current = Color(int.parse('FF${currentHex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      current = Theme.of(context).colorScheme.primary;
    }

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: current, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).hintColor)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 16, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Accent Color', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: _accentPalette.map((hex) {
            Color c;
            try { c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
            catch (_) { c = Colors.indigo; }
            final isSelected = hex.toLowerCase() == currentHex.toLowerCase();
            return GestureDetector(
              onTap: () {
                context.read<CreatorProvider>().setAccentColor(hex);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: isSelected ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)] : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ─── Empty hint ───────────────────────────────────────────────────────────────

class _EmptyFieldsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_circle_outline_rounded, size: 48, color: theme.hintColor.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text('No questions yet', style: theme.textTheme.titleSmall?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 4),
        Text('Use the bar below to add your first question.',
            style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    ).animate().fade();
  }
}

// ─── Reorderable field list ───────────────────────────────────────────────────

class _ReorderableFieldList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final creator = context.watch<CreatorProvider>();
    final fields = creator.schema.fields;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final field = fields[i];
          return _FieldEditorCard(
            key: ValueKey(field.id),
            field: field,
            index: i,
            total: fields.length,
          ).animate(delay: Duration(milliseconds: 30 * i))
              .slideY(begin: 0.1, duration: 250.ms)
              .fade();
        },
        childCount: fields.length,
      ),
    );
  }
}

// ─── Field editor card ────────────────────────────────────────────────────────

class _FieldEditorCard extends StatelessWidget {
  final FormFieldModel field;
  final int index;
  final int total;

  const _FieldEditorCard({super.key, required this.field, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final creator = context.watch<CreatorProvider>();
    final isExpanded = creator.expandedFieldId == field.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => creator.toggleExpand(field.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExpanded
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : isDark ? Colors.white12 : Colors.black12,
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isExpanded
                    ? theme.colorScheme.primary.withOpacity(0.08)
                    : (isDark ? Colors.black38 : Colors.black.withOpacity(0.04)),
                blurRadius: isExpanded ? 16 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                Icon(field.type.icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label.isEmpty ? field.type.label : field.label,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Required badge
                if (field.isRequired)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Required',
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                  ),
                // Actions
                IconButton(
                  icon: Icon(Icons.copy_outlined, size: 16, color: theme.hintColor),
                  onPressed: () => creator.duplicateField(field.id),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: theme.colorScheme.error.withOpacity(0.7)),
                  onPressed: () => creator.removeField(field.id),
                  visualDensity: VisualDensity.compact,
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 20, color: theme.hintColor,
                ),
              ]),
            ),

            // ── Expanded editor ────────────────────────────────────────
            if (isExpanded) ...[
              Divider(height: 1, color: theme.dividerColor),
              _FieldEditor(field: field),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Field editor (expanded) ──────────────────────────────────────────────────

class _FieldEditor extends StatefulWidget {
  final FormFieldModel field;
  const _FieldEditor({required this.field});

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late TextEditingController _labelCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _placeholderCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _descCtrl = TextEditingController(text: widget.field.description ?? '');
    _placeholderCtrl = TextEditingController(text: widget.field.placeholder ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _placeholderCtrl.dispose();
    super.dispose();
  }

  void _update(FormFieldModel Function(FormFieldModel) fn) {
    context.read<CreatorProvider>().updateField(fn(widget.field));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Label ────────────────────────────────────────────────────
        if (!field.type.isStructural || field.type == FormFieldType.heading) ...[
          _EditorLabel('Question text'),
          const SizedBox(height: 6),
          TextField(
            controller: _labelCtrl,
            onChanged: (v) => _update((f) => f.copyWith(label: v)),
            decoration: InputDecoration(hintText: field.type.isStructural ? 'Section title' : 'Enter your question'),
          ),
          const SizedBox(height: 12),
        ],

        // ── Description ──────────────────────────────────────────────
        if (!field.type.isStructural) ...[
          _EditorLabel('Helper text (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            onChanged: (v) => _update((f) => f.copyWith(description: v.isEmpty ? null : v)),
            decoration: const InputDecoration(hintText: 'Description shown under the question'),
          ),
          const SizedBox(height: 12),
        ],

        // ── Placeholder ──────────────────────────────────────────────
        if (field.type == FormFieldType.shortText || field.type == FormFieldType.longText) ...[
          _EditorLabel('Placeholder'),
          const SizedBox(height: 6),
          TextField(
            controller: _placeholderCtrl,
            onChanged: (v) => _update((f) => f.copyWith(placeholder: v.isEmpty ? null : v)),
            decoration: const InputDecoration(hintText: 'e.g. Type your answer here'),
          ),
          const SizedBox(height: 12),
        ],

        // ── Options editor ────────────────────────────────────────────
        if (field.type.hasOptions) _OptionsEditor(field: field),

        // ── Rating max ────────────────────────────────────────────────
        if (field.type == FormFieldType.rating) ...[
          _EditorLabel('Max stars'),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: field.maxRating ?? 5,
            decoration: const InputDecoration(),
            items: [3, 4, 5, 6, 7, 10].map((n) => DropdownMenuItem(value: n, child: Text('$n stars'))).toList(),
            onChanged: (v) { if (v != null) _update((f) => f.copyWith(maxRating: v)); },
          ),
          const SizedBox(height: 12),
        ],

        // ── Required toggle ───────────────────────────────────────────
        if (!field.type.isStructural) ...[
          const Divider(height: 20),
          Row(children: [
            Text('Required', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Switch.adaptive(
              value: field.isRequired,
              onChanged: (v) => _update((f) => f.copyWith(isRequired: v)),
              activeColor: theme.colorScheme.primary,
            ),
          ]),
        ],
      ]),
    );
  }
}

class _EditorLabel extends StatelessWidget {
  final String text;
  const _EditorLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
      );
}

// ─── Options editor (radio / checkbox / dropdown) ────────────────────────────

class _OptionsEditor extends StatelessWidget {
  final FormFieldModel field;
  const _OptionsEditor({required this.field});

  @override
  Widget build(BuildContext context) {
    final creator = context.read<CreatorProvider>();
    final theme = Theme.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _EditorLabel('Options'),
      const SizedBox(height: 8),
      ...field.options.asMap().entries.map((e) {
        final opt = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(field.type.icon, size: 14, color: theme.hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: opt.label)
                  ..selection = TextSelection.collapsed(offset: opt.label.length),
                onChanged: (v) => creator.updateOption(field.id, opt.id, v),
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Option ${e.key + 1}',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            if (field.options.length > 1)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: theme.hintColor),
                onPressed: () => creator.removeOption(field.id, opt.id),
                visualDensity: VisualDensity.compact,
              ),
          ]),
        );
      }),
      TextButton.icon(
        onPressed: () => creator.addOption(field.id),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add option'),
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
      ),
      const SizedBox(height: 4),
    ]);
  }
}

// ─── Add question bar ─────────────────────────────────────────────────────────

class _AddQuestionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Add a question', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FormFieldType.values.map((type) => _QuestionTypeChip(type: type)).toList(),
        ),
      ]),
    );
  }
}

class _QuestionTypeChip extends StatelessWidget {
  final FormFieldType type;
  const _QuestionTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        context.read<CreatorProvider>().addField(type);
        // Scroll to bottom
        Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(type.icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Text(type.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)),
        ]),
      ),
    );
  }
}
