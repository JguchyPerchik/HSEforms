// lib/providers/filler_provider.dart
// Manages user answers while completing a published survey.

import 'package:flutter/material.dart';
import '../../../models/form_field_model.dart';
import 'survey_store.dart';

enum FillerStatus { idle, validating, submitting, submitted }

class FillerProvider extends ChangeNotifier {
  final SurveyStore _store;
  FillerProvider(this._store);

  FormSchema? _schema;
  FormSchema? get schema => _schema;

  final Map<String, dynamic> _answers = {};
  Map<String, dynamic> get answers => Map.unmodifiable(_answers);

  final Map<String, String?> _errors = {};
  Map<String, String?> get errors => Map.unmodifiable(_errors);

  FillerStatus _status = FillerStatus.idle;
  FillerStatus get status => _status;
  bool get isSubmitted => _status == FillerStatus.submitted;
  bool get isSubmitting => _status == FillerStatus.submitting;

  void load(FormSchema schema) {
    _schema = schema;
    _answers.clear();
    _errors.clear();
    _status = FillerStatus.idle;
    notifyListeners();
  }

  void setAnswer(String fieldId, dynamic value) {
    _answers[fieldId] = value;
    _errors[fieldId] = null;
    notifyListeners();
  }

  void toggleCheckbox(String fieldId, String optionId) {
    final current = List<String>.from(_answers[fieldId] as List? ?? []);
    if (current.contains(optionId)) {
      current.remove(optionId);
    } else {
      current.add(optionId);
    }
    _answers[fieldId] = current;
    _errors[fieldId] = null;
    notifyListeners();
  }

  bool isCheckboxSelected(String fieldId, String optionId) =>
      (_answers[fieldId] as List? ?? []).contains(optionId);

  dynamic getAnswer(String fieldId) => _answers[fieldId];

  double get progress {
    if (_schema == null) return 0;
    return _schema!.completionProgress(_answers);
  }

  bool _validateAll() {
    if (_schema == null) return false;
    bool valid = true;
    for (final field in _schema!.fields) {
      if (field.type.isStructural) continue;
      final error = _validateField(field);
      _errors[field.id] = error;
      if (error != null) valid = false;
    }
    return valid;
  }

  String? _validateField(FormFieldModel field) {
    final answer = _answers[field.id];
    for (final v in field.validations) {
      switch (v.rule) {
        case ValidationRule.required:
          if (answer == null ||
              (answer is String && answer.trim().isEmpty) ||
              (answer is List && (answer).isEmpty)) return v.errorMessage;
          break;
        case ValidationRule.minLength:
          final min = v.value as int? ?? 0;
          if (answer is String && answer.trim().length < min) return v.errorMessage;
          break;
        case ValidationRule.maxLength:
          final max = v.value as int? ?? 9999;
          if (answer is String && answer.trim().length > max) return v.errorMessage;
          break;
        case ValidationRule.email:
          final re = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
          if (answer is String && answer.isNotEmpty && !re.hasMatch(answer.trim()))
            return v.errorMessage;
          break;
        case ValidationRule.url:
          final re = RegExp(r'^https?:\/\/.+');
          if (answer is String && answer.isNotEmpty && !re.hasMatch(answer.trim()))
            return v.errorMessage;
          break;
        case ValidationRule.number:
          if (answer is String && answer.isNotEmpty && double.tryParse(answer.trim()) == null)
            return v.errorMessage;
          break;
      }
    }
    return null;
  }

  Future<bool> submit() async {
    _status = FillerStatus.validating;
    notifyListeners();

    if (!_validateAll()) {
      _status = FillerStatus.idle;
      notifyListeners();
      return false;
    }

    _status = FillerStatus.submitting;
    notifyListeners();

    await _store.submitResponse(
      formId: _schema!.id,
      formTitle: _schema!.title,
      answers: _answers,
    );

    _status = FillerStatus.submitted;
    notifyListeners();
    return true;
  }

  void reset() {
    _answers.clear();
    _errors.clear();
    _status = FillerStatus.idle;
    notifyListeners();
  }
}
