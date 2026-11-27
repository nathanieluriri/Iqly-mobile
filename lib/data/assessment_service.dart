import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deadline.dart';
import '../core/session.dart';
import 'live/live_repository.dart';
import 'api_client.dart';
import 'assessment_data.dart';

final assessmentServiceProvider = Provider<AssessmentService?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return AssessmentService(api);
});

const assessmentAccessTtl = Duration(minutes: 15);

const _passedAccess = AssessmentAccess(
  canTake: false,
  canResume: false,
  canAccessChallenges: true,
  state: 'passed',
);

class AssessmentAccessState {
  const AssessmentAccessState({
    this.access,
    this.fetchedAt,
    this.refreshing = false,
    this.error,
    this.terminalPassed = false,
    this.preview = false,
  });

  final AssessmentAccess? access;
  final DateTime? fetchedAt;
  final bool refreshing;
  final Object? error;
  final bool terminalPassed;
  final bool preview;

  AssessmentAccess? get effectiveAccess =>
      terminalPassed || preview ? _passedAccess : access;

  AssessmentAccessState copyWith({
    AssessmentAccess? access,
    DateTime? fetchedAt,
    bool? refreshing,
    Object? error,
    bool? terminalPassed,
    bool? preview,
    bool clearError = false,
  }) => AssessmentAccessState(
    access: access ?? this.access,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : error ?? this.error,
    terminalPassed: terminalPassed ?? this.terminalPassed,
    preview: preview ?? this.preview,
  );
}

class AssessmentAccessController extends Notifier<AssessmentAccessState> {
  AccountScope? _scope;
  String? _userId;
  var _request = 0;
  var _refreshing = false;

  String? get _accessKey => _userKey('assessment.access');
  String? get _qualifiedKey => _userKey('assessment.qualified');

  String? _userKey(String prefix) {
    final user = _userId;
    return user == null || user.isEmpty ? null : '$prefix.$user';
  }

  bool _current(AccountScope scope, String? userId, int request) =>
      ref.mounted && scope.open && _userId == userId && _request == request;

  bool _stale(DateTime? fetchedAt) {
    if (fetchedAt == null) return true;
    return !ref
        .read(clockProvider)()
        .isBefore(fetchedAt.add(assessmentAccessTtl));
  }

  ({AssessmentAccess access, DateTime fetchedAt})? _snapshot() {
    final key = _accessKey;
    if (key == null) return null;
    final raw = ref.read(sharedPreferencesProvider).getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final access = json['access'];
      final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
      if (access is! Map || fetchedAt == null) return null;
      return (
        access: AssessmentAccess.fromJson(access.cast<String, dynamic>()),
        fetchedAt: fetchedAt,
      );
    } on Object {
      return null;
    }
  }

  @override
  AssessmentAccessState build() {
    final scope = ref.watch(accountScopeProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    _scope = scope;
    _userId = scope.userId;
    _request++;
    _refreshing = false;
    if (ref.watch(liveModeProvider).isPreview) {
      return const AssessmentAccessState(preview: true);
    }
    final qualifiedAt = _qualifiedKey == null
        ? null
        : DateTime.tryParse(prefs.getString(_qualifiedKey!) ?? '');
    if (qualifiedAt != null) {
      return AssessmentAccessState(
        access: _passedAccess,
        fetchedAt: qualifiedAt,
        terminalPassed: true,
      );
    }
    final snapshot = _snapshot();
    if (_userId != null && _stale(snapshot?.fetchedAt)) {
      Future.microtask(() {
        if (ref.mounted && scope.open && _userId == scope.userId) {
          unawaited(refresh());
        }
      });
    }
    return AssessmentAccessState(
      access: snapshot?.access,
      fetchedAt: snapshot?.fetchedAt,
    );
  }

  Future<void> refresh({bool force = false}) async {
    if (state.preview || state.terminalPassed || _refreshing) return;
    if (!force && !_stale(state.fetchedAt)) return;
    final scope = _scope;
    final userId = _userId;
    if (scope == null || !scope.open || userId == null) return;
    final service = ref.read(assessmentServiceProvider);
    if (service == null) {
      state = state.copyWith(refreshing: false, error: StateError('No API'));
      return;
    }
    final request = ++_request;
    _refreshing = true;
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final access = await service.access();
      if (!_current(scope, userId, request)) return;
      await _commit(access, scope, userId, request);
    } on Object {
      if (_current(scope, userId, request)) {
        state = state.copyWith(refreshing: false, error: StateError('Offline'));
      }
    } finally {
      if (_current(scope, userId, request)) _refreshing = false;
    }
  }

  Future<void> apply(AssessmentAccess access) async {
    final scope = _scope;
    final userId = _userId;
    if (scope == null || userId == null || !scope.open) return;
    final request = ++_request;
    await _commit(access, scope, userId, request);
  }

  Future<void> _commit(
    AssessmentAccess access,
    AccountScope scope,
    String userId,
    int request,
  ) async {
    final now = ref.read(clockProvider)();
    final prefs = ref.read(sharedPreferencesProvider);
    final passed = access.canAccessChallenges;
    if (passed) {
      await prefs.remove(_accessKey!);
      await prefs.setString(_qualifiedKey!, now.toIso8601String());
    } else {
      await prefs.setString(
        _accessKey!,
        jsonEncode({
          'access': access.toJson(),
          'fetchedAt': now.toIso8601String(),
        }),
      );
    }
    if (!_current(scope, userId, request)) return;
    state = AssessmentAccessState(
      access: passed ? _passedAccess : access,
      fetchedAt: now,
      terminalPassed: passed,
    );
  }
}

final assessmentAccessProvider =
    NotifierProvider<AssessmentAccessController, AssessmentAccessState>(
      AssessmentAccessController.new,
    );

/// Refreshes stale qualification state when connectivity returns, and detaches
/// completely after a server-confirmed pass.
final assessmentNudgeRefreshProvider = Provider<void>((ref) {
  final state = ref.watch(assessmentAccessProvider);
  if (state.terminalPassed || state.preview) return;
  final api = ref.watch(apiClientProvider);
  if (api == null) return;
  final subscription = api.reachable.listen((_) {
    unawaited(
      ref.read(assessmentAccessProvider.notifier).refresh(force: false),
    );
  });
  ref.onDispose(subscription.cancel);
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
