// lib/providers/survey_store.dart
// Central store: owns ALL surveys & responses; persists via shared_preferences.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../models/form_field_model.dart';
import '../../../utils/telegram_theme.dart';

const _uuid = Uuid();
const _surveysKey = 'surveys_v2';
const _responsesKey = 'responses_v2';

class SurveyStore extends ChangeNotifier {
  // ── Telegram ──────────────────────────────────────────────────────────────
  TelegramThemeParams _tgTheme = TelegramThemeParams.light;
  TelegramThemeParams get tgTheme => _tgTheme;
  bool _isTelegram = false;
  bool get isTelegram => _isTelegram;

  void setTelegramTheme(TelegramThemeParams p, {bool isTelegram = false}) {
    _tgTheme = p;
    _isTelegram = isTelegram;
    notifyListeners();
  }

  // ── Surveys ───────────────────────────────────────────────────────────────
  List<FormSchema> _surveys = [];
  List<FormSchema> get surveys => List.unmodifiable(_surveys);

  List<FormSchema> get draftSurveys =>
      _surveys.where((s) => s.status == SurveyStatus.draft).toList();
  List<FormSchema> get publishedSurveys =>
      _surveys.where((s) => s.status == SurveyStatus.published).toList();

  // ── Responses ─────────────────────────────────────────────────────────────
  List<FormResponse> _responses = [];
  List<FormResponse> get responses => List.unmodifiable(_responses);

  List<FormResponse> responsesFor(String formId) =>
      _responses.where((r) => r.formId == formId).toList();

  // ── Loading ───────────────────────────────────────────────────────────────
  bool _loaded = false;
  bool get loaded => _loaded;

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    // Load surveys
    final rawSurveys = prefs.getString(_surveysKey);
    if (rawSurveys != null) {
      try {
        final list = jsonDecode(rawSurveys) as List;
        _surveys = list
            .map((e) => FormSchema.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _surveys = [];
      }
    }

    // Load responses
    final rawResponses = prefs.getString(_responsesKey);
    if (rawResponses != null) {
      try {
        final list = jsonDecode(rawResponses) as List;
        _responses = list
            .map((e) => FormResponse.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _responses = [];
      }
    }

    // Seed demo surveys if first launch
    if (_surveys.isEmpty) {
      _surveys = _demoSurveys();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _surveysKey, jsonEncode(_surveys.map((s) => s.toJson()).toList()));
    await prefs.setString(
        _responsesKey, jsonEncode(_responses.map((r) => r.toJson()).toList()));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SURVEY CRUD
  // ─────────────────────────────────────────────────────────────────────────

  FormSchema createSurvey({String title = 'Untitled Survey'}) {
    final now = DateTime.now();
    final schema = FormSchema(
      id: _uuid.v4(),
      title: title,
      fields: [],
      status: SurveyStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    _surveys.insert(0, schema);
    _persist();
    notifyListeners();
    return schema;
  }

  void saveSurvey(FormSchema schema) {
    final idx = _surveys.indexWhere((s) => s.id == schema.id);
    final updated = schema.copyWith(updatedAt: DateTime.now());
    if (idx >= 0) {
      _surveys[idx] = updated;
    } else {
      _surveys.insert(0, updated);
    }
    _persist();
    notifyListeners();
  }

  void deleteSurvey(String id) {
    _surveys.removeWhere((s) => s.id == id);
    _responses.removeWhere((r) => r.formId == id);
    _persist();
    notifyListeners();
  }

  void publishSurvey(String id) {
    _updateStatus(id, SurveyStatus.published);
  }

  void unpublishSurvey(String id) {
    _updateStatus(id, SurveyStatus.draft);
  }

  void closeSurvey(String id) {
    _updateStatus(id, SurveyStatus.closed);
  }

  void _updateStatus(String id, SurveyStatus status) {
    final idx = _surveys.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    _surveys[idx] = _surveys[idx].copyWith(status: status, updatedAt: DateTime.now());
    _persist();
    notifyListeners();
  }

  FormSchema? findById(String id) {
    try {
      return _surveys.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESPONSE SUBMIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<FormResponse> submitResponse({
    required String formId,
    required String formTitle,
    required Map<String, dynamic> answers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final response = FormResponse(
      id: _uuid.v4(),
      formId: formId,
      formTitle: formTitle,
      answers: Map<String, dynamic>.from(answers),
      submittedAt: DateTime.now(),
    );

    _responses.add(response);

    // Increment counter on the survey
    final idx = _surveys.indexWhere((s) => s.id == formId);
    if (idx >= 0) {
      _surveys[idx] = _surveys[idx].copyWith(
        responseCount: _surveys[idx].responseCount + 1,
        updatedAt: DateTime.now(),
      );
    }

    await _persist();
    notifyListeners();
    return response;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEMO DATA
  // ─────────────────────────────────────────────────────────────────────────

  List<FormSchema> _demoSurveys() {
    final now = DateTime.now();
    return [
      FormSchema(
        id: _uuid.v4(),
        title: 'Team Satisfaction Survey',
        description: 'Help us improve our workplace culture.',
        accentColor: '#6366F1',
        status: SurveyStatus.published,
        showProgressBar: true,
        confirmationMessage: '🙏 Thanks for your honest feedback!',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
        responseCount: 12,
        fields: [
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.heading,
            label: 'Work Environment',
          ),
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.rating,
            label: 'How satisfied are you with your work environment?',
            isRequired: true, maxRating: 5,
          ),
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.radio,
            label: 'How often do you work from home?',
            isRequired: true,
            options: [
              FieldOption(id: _uuid.v4(), label: 'Never'),
              FieldOption(id: _uuid.v4(), label: '1–2 days/week'),
              FieldOption(id: _uuid.v4(), label: '3–4 days/week'),
              FieldOption(id: _uuid.v4(), label: 'Fully remote'),
            ],
          ),
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.checkbox,
            label: 'Which perks matter most to you?',
            options: [
              FieldOption(id: _uuid.v4(), label: 'Flexible hours'),
              FieldOption(id: _uuid.v4(), label: 'Health insurance'),
              FieldOption(id: _uuid.v4(), label: 'Learning budget'),
              FieldOption(id: _uuid.v4(), label: 'Stock options'),
            ],
          ),
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.longText,
            label: 'Any additional comments?',
            placeholder: 'Share your thoughts...', rows: 3,
          ),
        ],
      ),
      FormSchema(
        id: _uuid.v4(),
        title: 'Event Feedback Form',
        description: 'Tell us how the event went.',
        accentColor: '#0EA5E9',
        status: SurveyStatus.draft,
        showProgressBar: true,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 5)),
        responseCount: 0,
        fields: [
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.shortText,
            label: 'Your Name', placeholder: 'Jane Doe', isRequired: true,
            validations: [FieldValidation(rule: ValidationRule.required, errorMessage: 'Name is required.')],
          ),
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.rating,
            label: 'Overall event rating', isRequired: true, maxRating: 5,
          ),
          FormFieldModel(
            id: _uuid.v4(), type: FormFieldType.radio,
            label: 'Would you attend again?', isRequired: true,
            options: [
              FieldOption(id: _uuid.v4(), label: 'Definitely yes'),
              FieldOption(id: _uuid.v4(), label: 'Probably yes'),
              FieldOption(id: _uuid.v4(), label: 'Not sure'),
              FieldOption(id: _uuid.v4(), label: 'Probably not'),
            ],
          ),
        ],
      ),
    ];
  }
}
