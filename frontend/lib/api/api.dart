import '../models/models.dart';
import 'api_client.dart';

class AuthApi {
  final ApiClient c;
  AuthApi(this.c);

  Future<String> register(String email, String password, [String? fullName]) async {
    final r = await c.post('/auth/register', {'email': email, 'password': password, 'full_name': fullName});
    return r['access_token'];
  }

  Future<String> login(String email, String password) async {
    final r = await c.post('/auth/login', {'email': email, 'password': password});
    return r['access_token'];
  }

  Future<String> telegram(String initData) async {
    final r = await c.post('/auth/telegram', {'init_data': initData});
    return r['access_token'];
  }

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await c.get('/auth/me'));
}

class SurveysApi {
  final ApiClient c;
  SurveysApi(this.c);

  Future<List<Survey>> list() async {
    final r = await c.get('/surveys') as List;
    return r.map((e) => Survey.fromJson(e)).toList();
  }

  Future<Survey> create({String title = 'Без названия', int? parentId, String? variantLabel, double variantWeight = 1.0}) async {
    final r = await c.post('/surveys', {
      'title': title,
      if (parentId != null) 'parent_survey_id': parentId,
      if (variantLabel != null) 'variant_label': variantLabel,
      'variant_weight': variantWeight,
    });
    return Survey.fromJson(r);
  }

  Future<Survey> get(int id) async => Survey.fromJson(await c.get('/surveys/$id'));

  Future<Survey> update(int id, Map<String, dynamic> data) async =>
      Survey.fromJson(await c.patch('/surveys/$id', data));

  Future<void> delete(int id) async => c.delete('/surveys/$id');

  Future<Survey> duplicate(int id) async => Survey.fromJson(await c.post('/surveys/$id/duplicate'));

  /// Сбросить round-robin счётчик опроса. После сброса следующий респондент
  /// снова получит первый вариант по очереди. На веса вариантов и режим
  /// `assignment_mode` не влияет.
  Future<void> resetAssignment(int id) async => c.post('/surveys/$id/reset_assignment');

  Future<Question> addQuestion(int surveyId, Map<String, dynamic> data) async =>
      Question.fromJson(await c.post('/surveys/$surveyId/questions', data));

  Future<Question> updateQuestion(int surveyId, int qId, Map<String, dynamic> data) async =>
      Question.fromJson(await c.patch('/surveys/$surveyId/questions/$qId', data));

  Future<void> deleteQuestion(int surveyId, int qId) async =>
      c.delete('/surveys/$surveyId/questions/$qId');

  Future<List<Question>> reorder(int surveyId, List<int> ids) async {
    final r = await c.patch('/surveys/$surveyId/questions/reorder', {'question_ids': ids}) as List;
    return r.map((e) => Question.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> analytics(int surveyId) async =>
      Map<String, dynamic>.from(await c.get('/surveys/$surveyId/analytics'));

  Future<List<Map<String, dynamic>>> collaborators(int surveyId) async {
    final r = await c.get('/surveys/$surveyId/collaborators') as List;
    return r.cast<Map<String, dynamic>>();
  }

  Future<void> addCollaborator(int surveyId, String email, String role) async =>
      c.post('/surveys/$surveyId/collaborators', {'email': email, 'role': role});

  Future<void> removeCollaborator(int surveyId, int userId) async =>
      c.delete('/surveys/$surveyId/collaborators/$userId');

  /// Импорт структуры опроса из Google Forms / Яндекс Форм по URL.
  /// Вопросы ДОПИСЫВАЮТСЯ в конец текущего опроса — это намеренно,
  /// см. комментарий к эндпоинту /import на бэкенде.
  ///
  /// Возвращает обновлённый Survey + statisticts: сколько вопросов
  /// реально импортировано и сколько пропущено как неподдерживаемые
  /// (сетки, дата/время, file upload и т.п.). UI показывает эти числа
  /// в snackbar'е после успеха, чтобы пользователь не удивлялся,
  /// почему «8 вопросов в исходной форме, а у меня появилось 6».
  Future<({Survey survey, String provider, int importedCount, int skippedCount})>
      importFromUrl(int surveyId, String url) async {
    final r = await c.post('/surveys/$surveyId/import', {'url': url}) as Map;
    return (
      survey: Survey.fromJson(Map<String, dynamic>.from(r['survey'])),
      provider: r['provider']?.toString() ?? '',
      importedCount: (r['imported_count'] as num?)?.toInt() ?? 0,
      skippedCount: (r['skipped_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Описание одного формата экспорта — для UI и для запроса.
/// Держим в одном месте, чтобы добавить новый формат было ровно
/// одним изменением (добавить запись в [ExportsApi.formats]).
class ExportFormat {
  final String id;          // ключ для UI и аналитики
  final String label;       // подпись в боттом-шите
  final String description; // одна строка-объяснение под подписью
  final String path;        // относительный путь к endpoint'у (без surveyId)
  final String mimeType;
  final String fallbackExt; // расширение для fallback-имени файла

  /// Поддерживает ли формат фильтры `include_incomplete` / `include_synthetic`.
  /// Codebook и analytics — нет (они не про сырые ответы).
  final bool supportsFilters;

  /// Доп. параметры запроса — например, layout=wide для CSV.
  final Map<String, String> extraQuery;

  const ExportFormat({
    required this.id,
    required this.label,
    required this.description,
    required this.path,
    required this.mimeType,
    required this.fallbackExt,
    this.supportsFilters = true,
    this.extraQuery = const {},
  });
}

class ExportsApi {
  final ApiClient c;
  ExportsApi(this.c);

  /// Каноничный список форматов. Порядок = порядок в UI.
  static const List<ExportFormat> formats = [
    ExportFormat(
      id: 'csv_wide',
      label: 'CSV (wide)',
      description: 'Одна строка = один респондент. Открывается в Excel, R, SPSS, Python.',
      path: '/responses.csv',
      mimeType: 'text/csv',
      fallbackExt: 'csv',
      extraQuery: {'layout': 'wide'},
    ),
    ExportFormat(
      id: 'csv_long',
      label: 'CSV (long, tidy)',
      description: 'Одна строка = один ответ. Для tidyverse, pandas.melt, ggplot.',
      path: '/responses.csv',
      mimeType: 'text/csv',
      fallbackExt: 'csv',
      extraQuery: {'layout': 'long'},
    ),
    ExportFormat(
      id: 'xlsx',
      label: 'Excel (.xlsx)',
      description: 'Книга из 5 листов: Сводка, Wide, Long, Вопросы, Кодбук, Агрегации.',
      path: '/responses.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      fallbackExt: 'xlsx',
    ),
    ExportFormat(
      id: 'sav',
      label: 'SPSS (.sav)',
      description: 'С метками переменных и значений — для SPSS/PSPP/Stata-импорта.',
      path: '/responses.sav',
      mimeType: 'application/x-spss-sav',
      fallbackExt: 'sav',
    ),
    ExportFormat(
      id: 'json_raw',
      label: 'JSON (полный дамп)',
      description: 'Без потерь: вложенные multi-choice, варианты, метаданные. Для архива и API.',
      path: '/responses.json',
      mimeType: 'application/json',
      fallbackExt: 'json',
    ),
    ExportFormat(
      id: 'json_aggregated',
      label: 'JSON (агрегации)',
      description: 'Готовые распределения по вопросам и вариантам — то же, что и на этом экране.',
      path: '/analytics.json',
      mimeType: 'application/json',
      fallbackExt: 'json',
      supportsFilters: false,
    ),
    ExportFormat(
      id: 'codebook',
      label: 'Codebook (CSV)',
      description: 'Словарь переменных: имя в датасете → исходный вопрос → возможные значения.',
      path: '/codebook.csv',
      mimeType: 'text/csv',
      fallbackExt: 'csv',
      supportsFilters: false,
    ),
  ];

  Future<void> download(
    int surveyId,
    ExportFormat f, {
    bool includeIncomplete = true,
    bool includeSynthetic = true,
  }) async {
    final params = <String, String>{...f.extraQuery};
    if (f.supportsFilters) {
      params['include_incomplete'] = includeIncomplete.toString();
      params['include_synthetic'] = includeSynthetic.toString();
    }
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final path = '/surveys/$surveyId/export${f.path}${qs.isEmpty ? '' : '?$qs'}';
    await c.downloadAuthed(
      path,
      fallbackFilename: 'survey_${surveyId}_${f.id}.${f.fallbackExt}',
      mimeType: f.mimeType,
    );
  }
}

class PublicApi {
  final ApiClient c;
  PublicApi(this.c);

  Future<Survey> getBySlug(String slug) async => Survey.fromJson(await c.get('/public/surveys/$slug'));

  Future<Map<String, dynamic>> start(String slug) async =>
      Map<String, dynamic>.from(await c.post('/public/surveys/$slug/start'));

  Future<Map<String, dynamic>> submit(
    int responseId,
    List<Map<String, dynamic>> answers, {
    Map<String, int> variantAssignments = const {},
  }) async =>
      Map<String, dynamic>.from(await c.post(
        '/public/responses/$responseId/submit',
        {
          'answers': answers,
          'variant_assignments': variantAssignments,
        },
      ));
}
