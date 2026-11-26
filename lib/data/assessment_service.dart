import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'assessment_data.dart';

final assessmentServiceProvider = Provider<AssessmentService?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return AssessmentService(api);
});

final assessmentAccessProvider = FutureProvider<AssessmentAccess?>((ref) async {
  final svc = ref.watch(assessmentServiceProvider);
  if (svc == null) return null;
  return svc.access();
});

class AssessmentService {
  AssessmentService(this.api);

  final ApiClient api;

  Future<AssessmentAccess> access() async {
    final res = await api.get('/assessments/me');
    if (!res.ok) throw ApiException(res);
    return AssessmentAccess.fromJson(res.data);
  }

  Future<AssessmentSession> start() async {
    final res = await api.post('/assessments/start');
    if (!res.ok) throw ApiException(res);
    return AssessmentSession.fromJson(res.data);
  }

  Future<AssessmentSession> get(String id) async {
    final res = await api.get('/assessments/$id');
    if (!res.ok) throw ApiException(res);
    return AssessmentSession.fromJson(res.data);
  }

  Future<AssessmentSession> answer(String id, int optionIndex) async {
    final res = await api.post('/assessments/$id/answer', {
      'optionIndex': optionIndex,
    });
    if (!res.ok) throw ApiException(res);
    return AssessmentSession.fromJson(res.data);
  }

  Future<AssessmentSession> skip(String id) async {
    final res = await api.post('/assessments/$id/skip');
    if (!res.ok) throw ApiException(res);
    return AssessmentSession.fromJson(res.data);
  }
}

class ApiException implements Exception {
  ApiException(this.response);

  final ApiResponse response;

  String get message =>
      response.message ?? 'New challenges are currently unavailable.';
}
