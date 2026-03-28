// lib/providers/creator_provider.dart
// Manages the in-progress survey being built in the creator screen.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/form_field_model.dart';
import 'survey_store.dart';

const _uuid = Uuid();

class CreatorProvider extends ChangeNotifier {
  FormSchema _schema = FormSchema.empty();
  FormSchema get schema => _schema;

  String? _expandedFieldId; // which field card is open for editing
  String? get expandedFieldId => _expandedFieldId;

  bool _dirty = false;
  bool get isDirty => _dirty;

  // ── Load existing or new survey ───────────────────────────────────────────

  void loadNew() {
    final now = DateTime.now();
    _schema = FormSchema(
      id: _uuid.v4(),
      title: 'Untitled Survey',
      description: '',
      fields: [],
      showProgressBar: true,
      status: SurveyStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    _expandedFieldId = null;
    _dirty = false;
    notifyListeners();
  }

  void loadExisting(FormSchema schema) {
    _schema = schema;
    _expandedFieldId = null;
    _dirty = false;
    notifyListeners();
  }

  // ── Survey-level edits ────────────────────────────────────────────────────

  void setTitle(String title) {
    _schema = _schema.copyWith(title: title);
    _markDirty();
  }

  void setDescription(String desc) {
    _schema = _schema.copyWith(description: desc);
    _markDirty();
  }

  void setAccentColor(String hex) {
    _schema = _schema.copyWith(accentColor: hex);
    _markDirty();
  }

  void setShowProgressBar(bool v) {
    _schema = _schema.copyWith(showProgressBar: v);
    _markDirty();
  }

  void setConfirmationMessage(String msg) {
    _schema = _schema.copyWith(confirmationMessage: msg);
    _markDirty();
  }

  // ── Field management ──────────────────────────────────────────────────────

  void addField(FormFieldType type) {
    final id = _uuid.v4();
    final defaultOptions = type.hasOptions
        ? [
            FieldOption(id: _uuid.v4(), label: 'Option 1'),
            FieldOption(id: _uuid.v4(), label: 'Option 2'),
          ]
        : <FieldOption>[];

    final field = FormFieldModel(
      id: id,
      type: type,
      label: type.isStructural ? type.label : '',
      options: defaultOptions,
    );

    _schema = _schema.copyWith(
      fields: [..._schema.fields, field],
    );
    _expandedFieldId = id; // auto-expand newly added field
    _markDirty();
  }

  void removeField(String fieldId) {
    _schema = _schema.copyWith(
      fields: _schema.fields.where((f) => f.id != fieldId).toList(),
    );
    if (_expandedFieldId == fieldId) _expandedFieldId = null;
    _markDirty();
  }

  void updateField(FormFieldModel updated) {
    _schema = _schema.copyWith(
      fields: _schema.fields
          .map((f) => f.id == updated.id ? updated : f)
          .toList(),
    );
    _markDirty();
  }

  void reorderFields(int oldIndex, int newIndex) {
    final fields = List<FormFieldModel>.from(_schema.fields);
    if (newIndex > oldIndex) newIndex--;
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex, item);
    _schema = _schema.copyWith(fields: fields);
    _markDirty();
  }

  void duplicateField(String fieldId) {
    final idx = _schema.fields.indexWhere((f) => f.id == fieldId);
    if (idx < 0) return;
    final original = _schema.fields[idx];
    final copy = original.copyWith(
      id: _uuid.v4(),
      options: original.options
          .map((o) => o.copyWith(id: _uuid.v4()))
          .toList(),
    );
    final fields = List<FormFieldModel>.from(_schema.fields);
    fields.insert(idx + 1, copy);
    _schema = _schema.copyWith(fields: fields);
    _markDirty();
  }

  // ── Option management ─────────────────────────────────────────────────────

  void addOption(String fieldId) {
    _modifyField(fieldId, (f) {
      final newOpt = FieldOption(id: _uuid.v4(), label: 'Option ${f.options.length + 1}');
      return f.copyWith(options: [...f.options, newOpt]);
    });
  }

  void updateOption(String fieldId, String optionId, String label) {
    _modifyField(fieldId, (f) {
      return f.copyWith(
        options: f.options.map((o) => o.id == optionId ? o.copyWith(label: label) : o).toList(),
      );
    });
  }

  void removeOption(String fieldId, String optionId) {
    _modifyField(fieldId, (f) {
      return f.copyWith(options: f.options.where((o) => o.id != optionId).toList());
    });
  }

  void _modifyField(String fieldId, FormFieldModel Function(FormFieldModel) fn) {
    _schema = _schema.copyWith(
      fields: _schema.fields.map((f) => f.id == fieldId ? fn(f) : f).toList(),
    );
    _markDirty();
  }

  // ── Expansion ─────────────────────────────────────────────────────────────

  void toggleExpand(String fieldId) {
    _expandedFieldId = _expandedFieldId == fieldId ? null : fieldId;
    notifyListeners();
  }

  void collapseAll() {
    _expandedFieldId = null;
    notifyListeners();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void saveToStore(SurveyStore store) {
    store.saveSurvey(_schema);
    _dirty = false;
    notifyListeners();
  }

  void publishAndSave(SurveyStore store) {
    _schema = _schema.copyWith(status: SurveyStatus.published);
    store.saveSurvey(_schema);
    _dirty = false;
    notifyListeners();
  }

  void _markDirty() {
    _dirty = true;
    notifyListeners();
  }
}
