enum QuestionType {
  short_text, long_text, single_choice, multiple_choice,
  dropdown, scale, section_header;
  // rating, number, date, email, section_header

  static QuestionType parse(String s) =>
      QuestionType.values.firstWhere((e) => e.name == s, orElse: () => QuestionType.short_text);

  String get human {
    switch (this) {
      case QuestionType.short_text: return 'Короткий текст';
      case QuestionType.long_text: return 'Длинный текст';
      case QuestionType.single_choice: return 'Один вариант';
      case QuestionType.multiple_choice: return 'Несколько вариантов';
      case QuestionType.dropdown: return 'Выпадающий список';
      case QuestionType.scale: return 'Шкала';
      // case QuestionType.rating: return 'Оценка';
      // case QuestionType.number: return 'Число';
      // case QuestionType.date: return 'Дата';
      // case QuestionType.email: return 'Email';
      case QuestionType.section_header: return 'Заголовок секции';
    }
  }
}

enum SurveyStatus { draft, published, closed;
  static SurveyStatus parse(String s) =>
      SurveyStatus.values.firstWhere((e) => e.name == s, orElse: () => SurveyStatus.draft);
  String get human => switch (this) {
    SurveyStatus.draft => 'Черновик',
    SurveyStatus.published => 'Опубликован',
    SurveyStatus.closed => 'Закрыт',
  };
}

class QuestionOption {
  int? id;
  String label;
  String value;
  int position;
  QuestionOption({this.id, this.label = '', this.value = '', this.position = 0});
  factory QuestionOption.fromJson(Map<String, dynamic> j) => QuestionOption(
    id: j['id'], label: j['label'] ?? '', value: j['value'] ?? '', position: j['position'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id, 'label': label, 'value': value, 'position': position,
  };
}

/// A full alternative version of a question — its own type, title,
/// options, type-specific config, weight, and "skip" flag.
/// Stored serialized as a Map inside `Question.config['variants']`.
class QuestionVariant {
  String title;
  String? description;
  QuestionType type;
  List<QuestionOption> options;
  Map<String, dynamic> config;
  double weight;
  bool skip;

  QuestionVariant({
    this.title = '',
    this.description,
    this.type = QuestionType.short_text,
    List<QuestionOption>? options,
    Map<String, dynamic>? config,
    this.weight = 1.0,
    this.skip = false,
  })  : options = options ?? [],
        config = config ?? {};

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'type': type.name,
    'options': options.map((o) => {'label': o.label, 'value': o.value, 'position': o.position}).toList(),
    'config': config,
    'weight': weight,
    'skip': skip,
  };

  factory QuestionVariant.fromJson(Map<String, dynamic> j) => QuestionVariant(
    title: j['title']?.toString() ?? '',
    description: j['description']?.toString(),
    type: QuestionType.parse(j['type']?.toString() ?? 'short_text'),
    options: ((j['options'] ?? []) as List)
        .map((e) => QuestionOption.fromJson(Map<String, dynamic>.from(e))).toList(),
    config: Map<String, dynamic>.from(j['config'] ?? {}),
    weight: ((j['weight'] ?? 1.0) as num).toDouble(),
    skip: j['skip'] == true,
  );
}

class Question {
  int id;
  int surveyId;
  QuestionType type;
  String title;
  String? description;
  int position;
  bool pageBreakBefore;
  bool required;
  Map<String, dynamic> config;
  Map<String, dynamic>? displayCondition;
  List<QuestionOption> options;

  Question({
    required this.id, required this.surveyId, required this.type,
    this.title = '', this.description, this.position = 0,
    this.pageBreakBefore = false, this.required = false,
    Map<String, dynamic>? config, this.displayCondition,
    List<QuestionOption>? options,
  })  : config = config ?? {},
        options = options ?? [];

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'], surveyId: j['survey_id'],
    type: QuestionType.parse(j['type']),
    title: j['title'] ?? '', description: j['description'],
    position: j['position'] ?? 0,
    pageBreakBefore: j['page_break_before'] ?? false,
    required: j['required'] ?? false,
    config: Map<String, dynamic>.from(j['config'] ?? {}),
    displayCondition: j['display_condition'] == null ? null : Map<String, dynamic>.from(j['display_condition']),
    options: ((j['options'] ?? []) as List).map((e) => QuestionOption.fromJson(e)).toList(),
  );

  /// Decoded variants list. Mutating this list does NOT auto-sync to config —
  /// call [writeVariants] after edits.
  List<QuestionVariant> readVariants() {
    final raw = config['variants'];
    if (raw is List) {
      return raw.map((e) => QuestionVariant.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return <QuestionVariant>[];
  }

  void writeVariants(List<QuestionVariant> list) {
    config['variants'] = list.map((v) => v.toJson()).toList();
  }

  double get originalWeight => ((config['original_weight'] ?? 1.0) as num).toDouble();
  set originalWeight(double v) => config['original_weight'] = v;
}

class SurveyVariant {
  final int id;
  final String title;
  final String? variantLabel;
  final double variantWeight;
  SurveyVariant(this.id, this.title, this.variantLabel, this.variantWeight);
  factory SurveyVariant.fromJson(Map<String, dynamic> j) => SurveyVariant(
    j['id'], j['title'] ?? '', j['variant_label'], (j['variant_weight'] ?? 1.0).toDouble(),
  );
}

class Survey {
  int id;
  int ownerId;
  String title;
  String? description;
  String slug;
  SurveyStatus status;
  bool isAnonymous;
  bool oneResponsePerUser;
  bool allowBackNavigation;
  bool showProgress;
  Map<String, dynamic> theme;
  int? parentSurveyId;
  String? variantLabel;
  double variantWeight;
  /// "random" — взвешенный случайный выбор варианта (дефолт).
  /// "round_robin" — детерминированный круг через атомарный Redis-счётчик.
  String assignmentMode;
  List<Question> questions;
  List<SurveyVariant> variants;

  Survey({
    required this.id, required this.ownerId, required this.title, this.description,
    required this.slug, required this.status,
    this.isAnonymous = true, this.oneResponsePerUser = false,
    this.allowBackNavigation = true, this.showProgress = true,
    Map<String, dynamic>? theme, this.parentSurveyId,
    this.variantLabel, this.variantWeight = 1.0,
    this.assignmentMode = 'random',
    List<Question>? questions, List<SurveyVariant>? variants,
  })  : theme = theme ?? {},
        questions = questions ?? [],
        variants = variants ?? [];

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
    id: j['id'], ownerId: j['owner_id'],
    title: j['title'] ?? '', description: j['description'],
    slug: j['slug'] ?? '', status: SurveyStatus.parse(j['status']),
    isAnonymous: j['is_anonymous'] ?? true,
    oneResponsePerUser: j['one_response_per_user'] ?? false,
    allowBackNavigation: j['allow_back_navigation'] ?? true,
    showProgress: j['show_progress'] ?? true,
    theme: Map<String, dynamic>.from(j['theme'] ?? {}),
    parentSurveyId: j['parent_survey_id'],
    variantLabel: j['variant_label'],
    variantWeight: (j['variant_weight'] ?? 1.0).toDouble(),
    assignmentMode: (j['assignment_mode'] ?? 'random').toString(),
    questions: ((j['questions'] ?? []) as List).map((e) => Question.fromJson(e)).toList(),
    variants: ((j['variants'] ?? []) as List).map((e) => SurveyVariant.fromJson(e)).toList(),
  );
}
