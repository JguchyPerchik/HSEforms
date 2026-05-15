// lib/providers/form_provider.dart

import 'package:flutter/material.dart';
import '../../../../models/form_field_model.dart';
import '../../../../utils/telegram_theme.dart';

// ─── Form State ───────────────────────────────────────────────────────────────

enum FormStatus { idle, validating, submitting, submitted, error }

class FormProvider extends ChangeNotifier {
  // ── Schema ────────────────────────────────────────────────────────────────
  FormSchema? _schema;
  FormSchema? get schema => _schema;

  // ── Answers: fieldId → dynamic (String | List<String> | DateTime) ─────────
  final Map<String, dynamic> _answers = {};
  Map<String, dynamic> get answers => Map.unmodifiable(_answers);

  // ── Validation errors: fieldId → error message ────────────────────────────
  final Map<String, String?> _errors = {};
  Map<String, String?> get errors => Map.unmodifiable(_errors);

  // ── Status ────────────────────────────────────────────────────────────────
  FormStatus _status = FormStatus.idle;
  FormStatus get status => _status;
  bool get isSubmitted => _status == FormStatus.submitted;
  bool get isSubmitting => _status == FormStatus.submitting;

  // ── Telegram theme ────────────────────────────────────────────────────────
  TelegramThemeParams _telegramTheme = TelegramThemeParams.light;
  TelegramThemeParams get telegramTheme => _telegramTheme;

  bool _isTelegramContext = false;
  bool get isTelegramContext => _isTelegramContext;

  // ── Load schema ────────────────────────────────────────────────────────────
  void loadSchema(FormSchema schema) {
    _schema = schema;
    _answers.clear();
    _errors.clear();
    _status = FormStatus.idle;
    notifyListeners();
  }

  // ── Set answer ─────────────────────────────────────────────────────────────
  void setAnswer(String fieldId, dynamic value) {
    _answers[fieldId] = value;
    // Clear error on change
    if (_errors.containsKey(fieldId)) {
      _errors[fieldId] = null;
    }
    notifyListeners();
  }

  // ── Toggle checkbox option ─────────────────────────────────────────────────
  void toggleCheckbox(String fieldId, String optionId) {
    final current = List<String>.from(_answers[fieldId] as List? ?? []);
    if (current.contains(optionId)) {
      current.remove(optionId);
    } else {
      current.add(optionId);
    }
    _answers[fieldId] = current;
    if (_errors.containsKey(fieldId)) _errors[fieldId] = null;
    notifyListeners();
  }

  bool isCheckboxSelected(String fieldId, String optionId) {
    final current = _answers[fieldId] as List? ?? [];
    return current.contains(optionId);
  }

  // ── Get current answer ─────────────────────────────────────────────────────
  dynamic getAnswer(String fieldId) => _answers[fieldId];
  // ── Reset form ─────────────────────────────────────────────────────────────
  void reset() {
    _answers.clear();
    _errors.clear();
    _status = FormStatus.idle;
    notifyListeners();
  }
  // ── Progress ───────────────────────────────────────────────────────────────
  double get progress {
    if (_schema == null || _schema!.fields.isEmpty) return 0;
    final interactiveFields = _schema!.fields
        .where((f) =>
            f.type != FormFieldType.divider && f.type != FormFieldType.heading)
        .toList();
    if (interactiveFields.isEmpty) return 0;
    final answered = interactiveFields.where((f) {
      final ans = _answers[f.id];
      if (ans == null) return false;
      if (ans is String) return ans.isNotEmpty;
      if (ans is List) return (ans).isNotEmpty;
      return true;
    }).length;
    return answered / interactiveFields.length;
  }

  // ── Validate all fields ────────────────────────────────────────────────────
  bool validate() {
    if (_schema == null) return false;
    bool isValid = true;

    for (final field in _schema!.fields) {
      final error = _validateField(field);
      _errors[field.id] = error;
      if (error != null) isValid = false;
    }

    _status = FormStatus.validating;
    notifyListeners();
    return isValid;
  }

  String? _validateField(FormFieldModel field) {
    final answer = _answers[field.id];

    for (final validation in field.validations) {
      switch (validation.rule) {
        case ValidationRule.required:
          if (answer == null ||
              (answer is String && answer.trim().isEmpty) ||
              (answer is List && (answer).isEmpty)) {
            return validation.errorMessage;
          }
          break;

        case ValidationRule.minLength:
          final minLen = validation.value as int? ?? 0;
          if (answer is String && answer.trim().length < minLen) {
            return validation.errorMessage;
          }
          break;

        case ValidationRule.maxLength:
          final maxLen = validation.value as int? ?? 9999;
          if (answer is String && answer.trim().length > maxLen) {
            return validation.errorMessage;
          }
          break;

        case ValidationRule.email:
          final emailRegex = RegExp(
            r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
          );
          if (answer is String &&
              answer.isNotEmpty &&
              !emailRegex.hasMatch(answer.trim())) {
            return validation.errorMessage;
          }
          break;

        case ValidationRule.url:
          final urlRegex = RegExp(
            r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
          );
          if (answer is String &&
              answer.isNotEmpty &&
              !urlRegex.hasMatch(answer.trim())) {
            return validation.errorMessage;
          }
          break;

        case ValidationRule.number:
          if (answer is String &&
              answer.isNotEmpty &&
              double.tryParse(answer.trim()) == null) {
            return validation.errorMessage;
          }
          break;
      }
    }
    return null;
  }

  // ── Submit form ────────────────────────────────────────────────────────────
  // ── Submit form ────────────────────────────────────────────────────────────
  Future<FormResponse?> submit() async {
    if (!validate()) return null;

    _status = FormStatus.submitting;
    notifyListeners();

    // Симуляция задержки сети
    await Future.delayed(const Duration(milliseconds: 1200));

    final response = FormResponse(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(), // 1. Добавляем ID (например, на основе времени)
      formId: _schema!.id,
      formTitle:
          _schema!.title ?? 'Untitled Form', // 2. Добавляем заголовок из схемы
      answers: Map<String, dynamic>.from(_answers),
      submittedAt: DateTime.now(),
    );

    _status = FormStatus.submitted;
    notifyListeners();
    return response;
  }
}
