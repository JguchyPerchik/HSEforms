// lib/screens/filler_screen.dart
// The form-filling experience: renders fields, validates, submits.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/form_field_model.dart';
import '../../../providers/filler_provider.dart';

class FillerScreen extends StatelessWidget {
  const FillerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();

    if (filler.schema == null) return const SizedBox.shrink();
    if (filler.isSubmitted) return _ConfirmationScreen(schema: filler.schema!);

    final schema = filler.schema!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color accent = theme.colorScheme.primary;
    if (schema.accentColor != null) {
      try {
        accent = Color(int.parse('FF${schema.accentColor!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    return Theme(
      data: theme.copyWith(colorScheme: theme.colorScheme.copyWith(primary: accent)),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(schema.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Header card ─────────────────────────────────────────────
            _HeaderCard(schema: schema, accent: accent)
                .animate().slideY(begin: -0.1, duration: 300.ms).fade(),

            const SizedBox(height: 14),

            // ── Fields ──────────────────────────────────────────────────
            ...schema.fields.asMap().entries.map((e) {
              final field = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildField(context, field)
                    .animate(delay: Duration(milliseconds: 50 * e.key))
                    .slideY(begin: 0.12, duration: 280.ms, curve: Curves.easeOut)
                    .fade(),
              );
            }),

            // ── Submit ──────────────────────────────────────────────────
            const SizedBox(height: 8),
            _SubmitButton(accent: accent).animate(delay: 200.ms).slideY(begin: 0.2).fade(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext ctx, FormFieldModel field) {
    switch (field.type) {
      case FormFieldType.shortText:   return _ShortTextField(field: field);
      case FormFieldType.longText:    return _LongTextField(field: field);
      case FormFieldType.radio:       return _RadioField(field: field);
      case FormFieldType.checkbox:    return _CheckboxField(field: field);
      case FormFieldType.dropdown:    return _DropdownField(field: field);
      case FormFieldType.datePicker:  return _DateField(field: field);
      case FormFieldType.timePicker:  return _TimeField(field: field);
      case FormFieldType.rating:      return _RatingField(field: field);
      case FormFieldType.divider:     return const _FormDivider();
      case FormFieldType.heading:     return _HeadingWidget(field: field);
    }
  }
}

// ─── Header card ──────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final FormSchema schema;
  final Color accent;
  const _HeaderCard({required this.schema, required this.accent});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: accent, width: 5),
          left: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          right: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        boxShadow: [BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(schema.title, style: theme.textTheme.displaySmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        if (schema.description != null && schema.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(schema.description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.5)),
        ],
        if (schema.showProgressBar) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progress', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            Text('${(filler.progress * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: filler.progress,
              minHeight: 6,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Shared field card wrapper ────────────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final FormFieldModel field;
  final Widget child;

  const _FieldCard({required this.field, required this.child});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final error = filler.errors[field.id];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null
              ? theme.colorScheme.error.withOpacity(0.6)
              : isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          width: error != null ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(field.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          if (field.isRequired)
            Text(' *', style: TextStyle(color: theme.colorScheme.error, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        if (field.description != null && field.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(field.description!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
        const SizedBox(height: 12),
        child,
        if (error != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.error_outline_rounded, size: 13, color: theme.colorScheme.error),
            const SizedBox(width: 4),
            Text(error, style: TextStyle(color: theme.colorScheme.error, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }
}

// ─── Short Text ───────────────────────────────────────────────────────────────

class _ShortTextField extends StatelessWidget {
  final FormFieldModel field;
  const _ShortTextField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.read<FillerProvider>();
    return _FieldCard(
      field: field,
      child: TextFormField(
        initialValue: filler.getAnswer(field.id) as String?,
        onChanged: (v) => filler.setAnswer(field.id, v),
        decoration: InputDecoration(hintText: field.placeholder),
      ),
    );
  }
}

// ─── Long Text ────────────────────────────────────────────────────────────────

class _LongTextField extends StatefulWidget {
  final FormFieldModel field;
  const _LongTextField({required this.field});

  @override
  State<_LongTextField> createState() => _LongTextFieldState();
}

class _LongTextFieldState extends State<_LongTextField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: context.read<FillerProvider>().getAnswer(widget.field.id) as String? ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final maxLen = widget.field.validations
        .where((v) => v.rule == ValidationRule.maxLength).firstOrNull?.value as int?;

    return _FieldCard(
      field: widget.field,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        TextFormField(
          controller: _ctrl,
          maxLines: widget.field.rows ?? 4,
          onChanged: (v) {
            context.read<FillerProvider>().setAnswer(widget.field.id, v);
            setState(() {});
          },
          decoration: InputDecoration(hintText: widget.field.placeholder),
        ),
        if (maxLen != null) ...[
          const SizedBox(height: 4),
          Text('${_ctrl.text.length} / $maxLen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11,
                  color: _ctrl.text.length > maxLen ? Theme.of(context).colorScheme.error : null)),
        ],
      ]),
    );
  }
}

// ─── Radio ────────────────────────────────────────────────────────────────────

class _RadioField extends StatelessWidget {
  final FormFieldModel field;
  const _RadioField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final selected = filler.getAnswer(field.id) as String?;
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      child: Column(children: field.options.map((opt) {
        final isSelected = selected == opt.id;
        return _OptionTile(
          label: opt.label, isSelected: isSelected,
          onTap: () => filler.setAnswer(field.id, opt.id),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                width: isSelected ? 5 : 2,
              ),
            ),
          ),
        );
      }).toList()),
    );
  }
}

// ─── Checkbox ─────────────────────────────────────────────────────────────────

class _CheckboxField extends StatelessWidget {
  final FormFieldModel field;
  const _CheckboxField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      child: Column(children: field.options.map((opt) {
        final isSelected = filler.isCheckboxSelected(field.id, opt.id);
        return _OptionTile(
          label: opt.label, isSelected: isSelected,
          onTap: () => filler.toggleCheckbox(field.id, opt.id),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20, height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                width: 2,
              ),
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            ),
            child: isSelected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
          ),
        );
      }).toList()),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget leading;
  const _OptionTile({required this.label, required this.isSelected, required this.onTap, required this.leading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? theme.colorScheme.primary.withOpacity(0.08) : theme.scaffoldBackgroundColor,
            border: Border.all(color: isSelected ? theme.colorScheme.primary.withOpacity(0.4) : theme.dividerColor.withOpacity(0.5)),
          ),
          child: Row(children: [
            leading, const SizedBox(width: 10),
            Expanded(child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? theme.colorScheme.primary : null,
                ))),
          ]),
        ),
      ),
    );
  }
}

// ─── Dropdown ─────────────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final FormFieldModel field;
  const _DropdownField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final selected = filler.getAnswer(field.id) as String?;
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      child: DropdownButtonFormField<String>(
        value: selected,
        hint: Text(field.placeholder ?? 'Select an option', style: TextStyle(color: theme.hintColor, fontSize: 14)),
        onChanged: (v) { if (v != null) filler.setAnswer(field.id, v); },
        decoration: const InputDecoration(errorText: null),
        borderRadius: BorderRadius.circular(12),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.primary),
        items: field.options.map((opt) => DropdownMenuItem(value: opt.id, child: Text(opt.label))).toList(),
      ),
    );
  }
}

// ─── Date picker ─────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final FormFieldModel field;
  const _DateField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final selected = filler.getAnswer(field.id) as DateTime?;
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selected ?? DateTime.now(),
            firstDate: DateTime(2020), lastDate: DateTime(2035),
          );
          if (picked != null && context.mounted) filler.setAnswer(field.id, picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: _DateTimeDisplay(
          icon: Icons.calendar_today_rounded,
          text: selected != null ? DateFormat('MMMM d, yyyy').format(selected) : 'Select a date',
          hasValue: selected != null,
          onClear: selected != null ? () => filler.setAnswer(field.id, null) : null,
        ),
      ),
    );
  }
}

// ─── Time picker ─────────────────────────────────────────────────────────────

class _TimeField extends StatelessWidget {
  final FormFieldModel field;
  const _TimeField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final selected = filler.getAnswer(field.id) as TimeOfDay?;

    return _FieldCard(
      field: field,
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: selected ?? TimeOfDay.now());
          if (picked != null && context.mounted) filler.setAnswer(field.id, picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: _DateTimeDisplay(
          icon: Icons.schedule_rounded,
          text: selected != null ? selected.format(context) : 'Select a time',
          hasValue: selected != null,
          onClear: selected != null ? () => filler.setAnswer(field.id, null) : null,
        ),
      ),
    );
  }
}

class _DateTimeDisplay extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool hasValue;
  final VoidCallback? onClear;
  const _DateTimeDisplay({required this.icon, required this.text, required this.hasValue, this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        color: theme.inputDecorationTheme.fillColor,
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: hasValue ? theme.colorScheme.primary : theme.hintColor),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: hasValue ? null : theme.hintColor)),
        const Spacer(),
        if (onClear != null)
          GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 15, color: theme.hintColor)),
      ]),
    );
  }
}

// ─── Rating ───────────────────────────────────────────────────────────────────

class _RatingField extends StatelessWidget {
  final FormFieldModel field;
  const _RatingField({required this.field});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    final rating = (filler.getAnswer(field.id) as int?) ?? 0;
    final max = field.maxRating ?? 5;
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      child: Row(children: List.generate(max, (i) {
        final v = i + 1;
        final filled = v <= rating;
        return GestureDetector(
          onTap: () => filler.setAnswer(field.id, v == rating ? 0 : v),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey('$v-$filled'),
                size: 34, color: filled ? const Color(0xFFF59E0B) : theme.dividerColor,
              ),
            ),
          ),
        );
      })),
    );
  }
}

// ─── Structural ───────────────────────────────────────────────────────────────

class _FormDivider extends StatelessWidget {
  const _FormDivider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: Theme.of(context).dividerColor),
      );
}

class _HeadingWidget extends StatelessWidget {
  final FormFieldModel field;
  const _HeadingWidget({required this.field});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(field.label,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
    );
  }
}

// ─── Submit button ────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final Color accent;
  const _SubmitButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    final filler = context.watch<FillerProvider>();
    return ElevatedButton(
      onPressed: filler.isSubmitting ? null : () => filler.submit(),
      style: ElevatedButton.styleFrom(
        backgroundColor: accent, foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: filler.isSubmitting
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(width: 8),
              Icon(Icons.send_rounded, size: 18),
            ]),
    );
  }
}

// ─── Confirmation screen ──────────────────────────────────────────────────────

class _ConfirmationScreen extends StatelessWidget {
  final FormSchema schema;
  const _ConfirmationScreen({required this.schema});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    if (schema.accentColor != null) {
      try { accent = Color(int.parse('FF${schema.accentColor!.replaceAll('#', '')}', radix: 16)); } catch (_) {}
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_outline_rounded, size: 44, color: accent),
              ).animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut).fade(),
              const SizedBox(height: 24),
              Text('Response Submitted!',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                  textAlign: TextAlign.center).animate().slideY(begin: 0.3, duration: 350.ms).fade(delay: 100.ms),
              const SizedBox(height: 12),
              Text(
                schema.confirmationMessage ?? 'Thank you for your response. It has been recorded.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.5),
                textAlign: TextAlign.center,
              ).animate().slideY(begin: 0.3, duration: 350.ms).fade(delay: 200.ms),
              const SizedBox(height: 36),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to surveys'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().slideY(begin: 0.3, duration: 350.ms).fade(delay: 300.ms),
            ]),
          ),
        ),
      ),
    );
  }
}
