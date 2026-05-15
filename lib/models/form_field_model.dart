// lib/models/form_field_model.dart

import 'package:flutter/material.dart';

enum FormFieldType {
  shortText,
  longText,
  radio,
  checkbox,
  dropdown,
  datePicker,
  timePicker,
  rating,
  divider,
  heading,
}

enum ValidationRule { required, minLength, maxLength, email, url, number }

enum SurveyStatus { draft, published, closed }

extension FormFieldTypeX on FormFieldType {
  String get label {
    switch (this) {
      case FormFieldType.shortText:
        return 'Short Text';
      case FormFieldType.longText:
        return 'Paragraph';
      case FormFieldType.radio:
        return 'Multiple Choice';
      case FormFieldType.checkbox:
        return 'Checkboxes';
      case FormFieldType.dropdown:
        return 'Dropdown';
      case FormFieldType.datePicker:
        return 'Date';
      case FormFieldType.timePicker:
        return 'Time';
      case FormFieldType.rating:
        return 'Star Rating';
      case FormFieldType.divider:
        return 'Divider';
      case FormFieldType.heading:
        return 'Section Heading';
    }
  }

  IconData get icon {
    switch (this) {
      case FormFieldType.shortText:
        return Icons.short_text_rounded;
      case FormFieldType.longText:
        return Icons.notes_rounded;
      case FormFieldType.radio:
        return Icons.radio_button_checked_rounded;
      case FormFieldType.checkbox:
        return Icons.check_box_rounded;
      case FormFieldType.dropdown:
        return Icons.arrow_drop_down_circle_rounded;
      case FormFieldType.datePicker:
        return Icons.calendar_today_rounded;
      case FormFieldType.timePicker:
        return Icons.schedule_rounded;
      case FormFieldType.rating:
        return Icons.star_rounded;
      case FormFieldType.divider:
        return Icons.horizontal_rule_rounded;
      case FormFieldType.heading:
        return Icons.title_rounded;
    }
  }

  bool get hasOptions =>
      this == FormFieldType.radio ||
      this == FormFieldType.checkbox ||
      this == FormFieldType.dropdown;
  bool get isStructural =>
      this == FormFieldType.divider || this == FormFieldType.heading;
}

class FieldValidation {
  final ValidationRule rule;
  final dynamic value;
  final String errorMessage;
  const FieldValidation(
      {required this.rule, this.value, required this.errorMessage});
  FieldValidation copyWith(
          {ValidationRule? rule, dynamic value, String? errorMessage}) =>
      FieldValidation(
          rule: rule ?? this.rule,
          value: value ?? this.value,
          errorMessage: errorMessage ?? this.errorMessage);
  factory FieldValidation.fromJson(Map<String, dynamic> json) =>
      FieldValidation(
          rule: ValidationRule.values.firstWhere((r) => r.name == json['rule'],
              orElse: () => ValidationRule.required),
          value: json['value'],
          errorMessage: json['errorMessage'] as String);
  Map<String, dynamic> toJson() =>
      {'rule': rule.name, 'value': value, 'errorMessage': errorMessage};
}

class FieldOption {
  final String id;
  final String label;
  const FieldOption({required this.id, required this.label});
  FieldOption copyWith({String? id, String? label}) =>
      FieldOption(id: id ?? this.id, label: label ?? this.label);
  factory FieldOption.fromJson(Map<String, dynamic> json) =>
      FieldOption(id: json['id'] as String, label: json['label'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

class FormFieldModel {
  final String id;
  final FormFieldType type;
  final String label;
  final String? description;
  final String? placeholder;
  final bool isRequired;
  final List<FieldOption> options;
  final List<FieldValidation> validations;
  final int? maxRating;
  final int? rows;

  const FormFieldModel({
    required this.id,
    required this.type,
    required this.label,
    this.description,
    this.placeholder,
    this.isRequired = false,
    this.options = const [],
    this.validations = const [],
    this.maxRating = 5,
    this.rows = 4,
  });

  FormFieldModel copyWith({
    String? id,
    FormFieldType? type,
    String? label,
    String? description,
    String? placeholder,
    bool? isRequired,
    List<FieldOption>? options,
    List<FieldValidation>? validations,
    int? maxRating,
    int? rows,
  }) =>
      FormFieldModel(
        id: id ?? this.id,
        type: type ?? this.type,
        label: label ?? this.label,
        description: description ?? this.description,
        placeholder: placeholder ?? this.placeholder,
        isRequired: isRequired ?? this.isRequired,
        options: options ?? this.options,
        validations: validations ?? this.validations,
        maxRating: maxRating ?? this.maxRating,
        rows: rows ?? this.rows,
      );

  factory FormFieldModel.fromJson(Map<String, dynamic> json) => FormFieldModel(
        id: json['id'] as String,
        type: FormFieldType.values.firstWhere((t) => t.name == json['type'],
            orElse: () => FormFieldType.shortText),
        label: json['label'] as String? ?? '',
        description: json['description'] as String?,
        placeholder: json['placeholder'] as String?,
        isRequired: json['isRequired'] as bool? ?? false,
        options: (json['options'] as List<dynamic>? ?? [])
            .map((o) => FieldOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        validations: (json['validations'] as List<dynamic>? ?? [])
            .map((v) => FieldValidation.fromJson(v as Map<String, dynamic>))
            .toList(),
        maxRating: json['maxRating'] as int? ?? 5,
        rows: json['rows'] as int? ?? 4,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        if (description != null) 'description': description,
        if (placeholder != null) 'placeholder': placeholder,
        'isRequired': isRequired,
        'options': options.map((o) => o.toJson()).toList(),
        'validations': validations.map((v) => v.toJson()).toList(),
        'maxRating': maxRating,
        'rows': rows,
      };
}

class FormSchema {
  final String id;
  final String title;
  final String? description;
  final List<FormFieldModel> fields;
  final String? accentColor;
  final bool showProgressBar;
  final String? confirmationMessage;
  final SurveyStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int responseCount;

  const FormSchema({
    required this.id,
    required this.title,
    this.description,
    required this.fields,
    this.accentColor,
    this.showProgressBar = true,
    this.confirmationMessage,
    this.status = SurveyStatus.draft,
    required this.createdAt,
    required this.updatedAt,
    this.responseCount = 0,
  });

  FormSchema copyWith({
    String? id,
    String? title,
    String? description,
    List<FormFieldModel>? fields,
    String? accentColor,
    bool? showProgressBar,
    String? confirmationMessage,
    SurveyStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? responseCount,
  }) =>
      FormSchema(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        fields: fields ?? this.fields,
        accentColor: accentColor ?? this.accentColor,
        showProgressBar: showProgressBar ?? this.showProgressBar,
        confirmationMessage: confirmationMessage ?? this.confirmationMessage,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        responseCount: responseCount ?? this.responseCount,
      );

  factory FormSchema.empty() => FormSchema(
      id: '',
      title: '',
      fields: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

  factory FormSchema.fromJson(Map<String, dynamic> json) => FormSchema(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        fields: (json['fields'] as List<dynamic>? ?? [])
            .map((f) => FormFieldModel.fromJson(f as Map<String, dynamic>))
            .toList(),
        accentColor: json['accentColor'] as String?,
        showProgressBar: json['showProgressBar'] as bool? ?? true,
        confirmationMessage: json['confirmationMessage'] as String?,
        status: SurveyStatus.values.firstWhere(
            (s) => s.name == (json['status'] ?? 'draft'),
            orElse: () => SurveyStatus.draft),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        responseCount: json['responseCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'fields': fields.map((f) => f.toJson()).toList(),
        if (accentColor != null) 'accentColor': accentColor,
        'showProgressBar': showProgressBar,
        if (confirmationMessage != null)
          'confirmationMessage': confirmationMessage,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'responseCount': responseCount,
      };

  int get questionCount => fields.where((f) => !f.type.isStructural).length;

  double completionProgress(Map<String, dynamic> answers) {
    final interactive = fields.where((f) => !f.type.isStructural).toList();
    if (interactive.isEmpty) return 0;
    final answered = interactive.where((f) {
      final ans = answers[f.id];
      if (ans == null) return false;
      if (ans is String) return ans.isNotEmpty;
      if (ans is List) return (ans).isNotEmpty;
      return true;
    }).length;
    return answered / interactive.length;
  }
}

class FormResponse {
  final String id;
  final String formId;
  final String formTitle;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;

  const FormResponse({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.answers,
    required this.submittedAt,
  });

  factory FormResponse.fromJson(Map<String, dynamic> json) => FormResponse(
        id: json['id'] as String,
        formId: json['formId'] as String,
        formTitle: json['formTitle'] as String? ?? '',
        answers: Map<String, dynamic>.from(json['answers'] as Map),
        submittedAt: DateTime.parse(json['submittedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'formId': formId,
        'formTitle': formTitle,
        'answers': answers,
        'submittedAt': submittedAt.toIso8601String(),
      };
}
