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
}

class PublicApi {
  final ApiClient c;
  PublicApi(this.c);

  Future<Survey> getBySlug(String slug) async => Survey.fromJson(await c.get('/public/surveys/$slug'));

  Future<Map<String, dynamic>> start(String slug) async =>
      Map<String, dynamic>.from(await c.post('/public/surveys/$slug/start'));

  Future<Map<String, dynamic>> submit(int responseId, List<Map<String, dynamic>> answers) async =>
      Map<String, dynamic>.from(await c.post('/public/responses/$responseId/submit', {'answers': answers}));
}
