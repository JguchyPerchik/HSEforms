// lib/widgets/form_generator.dart
// ─── Core Form Engine ─────────────────────────────────────────────────────────
// Renders any FormSchema dynamically, handles submission, and shows confirmation.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../models/form_field_model.dart';
import '../../../../providers/form_provider.dart' as fp;
import 'field_widgets.dart';

// ─── Progress Bar ─────────────────────────────────────────────────────────────

class _FormProgressBar extends StatelessWidget {
  const _FormProgressBar();

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<fp.FormProvider>().progress;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

// ─── Form Header Card ─────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  final FormSchema schema;

  const _FormHeader({required this.schema});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: accent, width: 5),
          left: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
          right: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schema.title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (schema.description != null && schema.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              schema.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.5,
                color: theme.hintColor,
              ),
            ),
          ],
          if (schema.showProgressBar) ...[
            const SizedBox(height: 20),
            const _FormProgressBar(),
          ],
        ],
      ),
    );
  }
}

// ─── Confirmation Screen ──────────────────────────────────────────────────────

class _ConfirmationScreen extends StatelessWidget {
  final FormSchema schema;

  const _ConfirmationScreen({required this.schema});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 44,
                color: theme.colorScheme.primary,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                )
                .fade(),
            const SizedBox(height: 24),
            Text(
              'Response Submitted!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(begin: 0.3, duration: 350.ms).fade(delay: 100.ms),
            const SizedBox(height: 12),
            Text(
              schema.confirmationMessage ??
                  'Thank you for your response. It has been recorded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(begin: 0.3, duration: 350.ms).fade(delay: 200.ms),
            const SizedBox(height: 36),
            OutlinedButton.icon(
              onPressed: () => context.read<fp.FormProvider>().reset(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Submit another response'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ).animate().slideY(begin: 0.3, duration: 350.ms).fade(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Submit Button ────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();
    final isSubmitting = FormProvider.isSubmitting;

    return ElevatedButton(
      onPressed: isSubmitting
          ? null
          : () async {
              await context.read<fp.FormProvider>().submit();
            },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isSubmitting
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                key: ValueKey('idle'),
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Submit'),
                  SizedBox(width: 8),
                  Icon(Icons.send_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

// ─── FORM GENERATOR ───────────────────────────────────────────────────────────

/// The main form engine. Pass a [FormSchema] and it renders every field
/// dynamically, validates, and handles submission.
class FormGenerator extends StatelessWidget {
  final FormSchema schema;

  const FormGenerator({super.key, required this.schema});

  Widget _buildField(BuildContext context, FormFieldModel field) {
    switch (field.type) {
      case FormFieldType.shortText:
        return ShortTextField(field: field);
      case FormFieldType.longText:
        return LongTextField(field: field);
      case FormFieldType.radio:
        return RadioField(field: field);
      case FormFieldType.checkbox:
        return CheckboxField(field: field);
      case FormFieldType.dropdown:
        return DropdownFieldWidget(field: field);
      case FormFieldType.datePicker:
        return DatePickerField(field: field);
      case FormFieldType.timePicker:
        return TimePickerField(field: field);
      case FormFieldType.rating:
        return RatingField(field: field);
      case FormFieldType.divider:
        return const FormDivider();
      case FormFieldType.heading:
        return FormHeading(field: field);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FormProvider = context.watch<fp.FormProvider>();

    if (FormProvider.isSubmitted) {
      return _ConfirmationScreen(schema: schema);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // ── Header card ────────────────────────────────────────────────────
        _FormHeader(schema: schema)
            .animate()
            .slideY(begin: -0.1, duration: 350.ms)
            .fade(),

        const SizedBox(height: 16),

        // ── Fields ──────────────────────────────────────────────────────────
        ...schema.fields.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildField(context, field)
                .animate(delay: Duration(milliseconds: 60 * index))
                .slideY(begin: 0.15, duration: 300.ms, curve: Curves.easeOut)
                .fade(),
          );
        }),

        const SizedBox(height: 8),

        // ── Required fields note ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Text(
                '* ',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Required fields',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // ── Submit button ────────────────────────────────────────────────────
        const _SubmitButton()
            .animate(delay: 200.ms)
            .slideY(begin: 0.2, duration: 300.ms)
            .fade(),

        const SizedBox(height: 32),

        // ── Branding footer ──────────────────────────────────────────────────
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Powered by Forms Engine',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
