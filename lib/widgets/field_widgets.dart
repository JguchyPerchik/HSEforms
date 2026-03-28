// lib/widgets/field_widgets.dart
// ─── Individual field renderers for each FormFieldType ────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../models/form_field_model.dart';
import '../../../../providers/form_provider.dart' as fp;

// ─── Shared Styles ─────────────────────────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final FormFieldModel field;
  final Widget child;
  final String? errorText;

  const _FieldCard({
    required this.field,
    required this.child,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: errorText != null
              ? theme.colorScheme.error.withOpacity(0.6)
              : isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
          width: errorText != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  field.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (field.isRequired)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    '*',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          // Description
          if (field.description != null && field.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field.description!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          child,
          // Error
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Short Text Field ─────────────────────────────────────────────────────────

class ShortTextField extends StatelessWidget {
  final FormFieldModel field;

  const ShortTextField({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final error = FormProvider.errors[field.id];

    final isEmail = field.validations.any((v) => v.rule == ValidationRule.email);
    final isNumber = field.validations.any((v) => v.rule == ValidationRule.number);

    return _FieldCard(
      field: field,
      errorText: error,
      child: TextFormField(
        initialValue: FormProvider.getAnswer(field.id) as String?,
        onChanged: (v) => context.read<fp.FormProvider>().setAnswer(field.id, v),
        keyboardType: isEmail
            ? TextInputType.emailAddress
            : isNumber
                ? TextInputType.number
                : TextInputType.text,
        decoration: InputDecoration(
          hintText: field.placeholder,
          errorText: null, // handled above
          suffixIcon: isEmail
              ? const Icon(Icons.alternate_email_rounded, size: 18)
              : null,
        ),
      ),
    );
  }
}

// ─── Long Text Field ──────────────────────────────────────────────────────────

class LongTextField extends StatefulWidget {
  final FormFieldModel field;

  const LongTextField({super.key, required this.field});

  @override
  State<LongTextField> createState() => _LongTextFieldState();
}

class _LongTextFieldState extends State<LongTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = context.read<fp.FormProvider>().getAnswer(widget.field.id)
        as String? ?? '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final error = FormProvider.errors[widget.field.id];
    final maxLen = widget.field.validations
        .where((v) => v.rule == ValidationRule.maxLength)
        .firstOrNull
        ?.value as int?;
    final currentLen = (_controller.text).length;

    return _FieldCard(
      field: widget.field,
      errorText: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextFormField(
            controller: _controller,
            onChanged: (v) {
              context.read<fp.FormProvider>().setAnswer(widget.field.id, v);
              setState(() {});
            },
            maxLines: widget.field.rows ?? 4,
            decoration: InputDecoration(hintText: widget.field.placeholder),
          ),
          if (maxLen != null) ...[
            const SizedBox(height: 4),
            Text(
              '$currentLen / $maxLen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: currentLen > maxLen
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Radio Button Field ───────────────────────────────────────────────────────

class RadioField extends StatelessWidget {
  final FormFieldModel field;

  const RadioField({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final selected = FormProvider.getAnswer(field.id) as String?;
    final error = FormProvider.errors[field.id];
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      errorText: error,
      child: Column(
        children: field.options.map((opt) {
          final isSelected = selected == opt.id;
          return _OptionTile(
            label: opt.label,
            isSelected: isSelected,
            onTap: () => context.read<fp.FormProvider>().setAnswer(field.id, opt.id),
            leading: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: isSelected ? 5 : 2,
                ),
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Checkbox Field ───────────────────────────────────────────────────────────

class CheckboxField extends StatelessWidget {
  final FormFieldModel field;

  const CheckboxField({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final error = FormProvider.errors[field.id];
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      errorText: error,
      child: Column(
        children: field.options.map((opt) {
          final isSelected = FormProvider.isCheckboxSelected(field.id, opt.id);
          return _OptionTile(
            label: opt.label,
            isSelected: isSelected,
            onTap: () =>
                context.read<fp.FormProvider>().toggleCheckbox(field.id, opt.id),
            leading: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: 2,
                ),
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Shared Option Tile ───────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget leading;

  const _OptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.leading,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.08)
                : theme.scaffoldBackgroundColor,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.4)
                  : theme.dividerColor.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dropdown Field ───────────────────────────────────────────────────────────

class DropdownFieldWidget extends StatelessWidget {
  final FormFieldModel field;

  const DropdownFieldWidget({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final selected = FormProvider.getAnswer(field.id) as String?;
    final error = FormProvider.errors[field.id];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _FieldCard(
      field: field,
      errorText: error,
      child: DropdownButtonFormField<String>(
        value: selected,
        hint: Text(
          field.placeholder ?? 'Select an option',
          style: TextStyle(color: theme.hintColor, fontSize: 14),
        ),
        onChanged: (v) {
          if (v != null) context.read<fp.FormProvider>().setAnswer(field.id, v);
        },
        decoration: const InputDecoration(errorText: null),
        borderRadius: BorderRadius.circular(12),
        dropdownColor: isDark
            ? const Color(0xFF27272A)
            : theme.cardColor,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.primary,
        ),
        items: field.options
            .map(
              (opt) => DropdownMenuItem(
                value: opt.id,
                child: Text(
                  opt.label,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Date Picker Field ────────────────────────────────────────────────────────

class DatePickerField extends StatelessWidget {
  final FormFieldModel field;

  const DatePickerField({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final selectedDate = FormProvider.getAnswer(field.id) as DateTime?;
    final error = FormProvider.errors[field.id];
    final theme = Theme.of(context);
    final formatted = selectedDate != null
        ? DateFormat('MMMM d, yyyy').format(selectedDate)
        : null;

    return _FieldCard(
      field: field,
      errorText: error,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme,
                dialogBackgroundColor: theme.cardColor,
              ),
              child: child!,
            ),
          );
          if (picked != null && context.mounted) {
            context.read<fp.FormProvider>().setAnswer(field.id, picked);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
            color: theme.inputDecorationTheme.fillColor,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: selectedDate != null
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: 10),
              Text(
                formatted ?? 'Select a date',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selectedDate != null ? null : theme.hintColor,
                ),
              ),
              const Spacer(),
              if (selectedDate != null)
                GestureDetector(
                  onTap: () =>
                      context.read<fp.FormProvider>().setAnswer(field.id, null),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.hintColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Time Picker Field ────────────────────────────────────────────────────────

class TimePickerField extends StatelessWidget {
  final FormFieldModel field;

  const TimePickerField({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final selectedTime = FormProvider.getAnswer(field.id) as TimeOfDay?;
    final error = FormProvider.errors[field.id];
    final theme = Theme.of(context);
    final formatted = selectedTime != null ? selectedTime.format(context) : null;

    return _FieldCard(
      field: field,
      errorText: error,
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: selectedTime ?? TimeOfDay.now(),
            builder: (ctx, child) => Theme(
              data: theme,
              child: child!,
            ),
          );
          if (picked != null && context.mounted) {
            context.read<fp.FormProvider>().setAnswer(field.id, picked);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
            color: theme.inputDecorationTheme.fillColor,
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: selectedTime != null
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: 10),
              Text(
                formatted ?? 'Select a time',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selectedTime != null ? null : theme.hintColor,
                ),
              ),
              const Spacer(),
              if (selectedTime != null)
                GestureDetector(
                  onTap: () =>
                      context.read<fp.FormProvider>().setAnswer(field.id, null),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.hintColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Star Rating Field ────────────────────────────────────────────────────────

class RatingField extends StatelessWidget {
  final FormFieldModel field;

  const RatingField({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final currentRating = (FormProvider.getAnswer(field.id) as int?) ?? 0;
    final error = FormProvider.errors[field.id];
    final max = field.maxRating ?? 5;
    final theme = Theme.of(context);

    return _FieldCard(
      field: field,
      errorText: error,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(max, (index) {
          final starValue = index + 1;
          final isFilled = starValue <= currentRating;
          return GestureDetector(
            onTap: () {
              final newRating = starValue == currentRating ? 0 : starValue;
              context.read<fp.FormProvider>().setAnswer(field.id, newRating);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                  key: ValueKey('$starValue-$isFilled'),
                  size: 36,
                  color: isFilled
                      ? const Color(0xFFF59E0B)
                      : theme.dividerColor,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Divider Widget ───────────────────────────────────────────────────────────

class FormDivider extends StatelessWidget {
  const FormDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        color: Theme.of(context).dividerColor,
        thickness: 1,
      ),
    );
  }
}

// ─── Heading Widget ───────────────────────────────────────────────────────────

class FormHeading extends StatelessWidget {
  final FormFieldModel field;

  const FormHeading({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (field.description != null && field.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field.description!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
