import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../data/api_client.dart';
import '../../data/kyc_service.dart';

const kycRefreshTtl = Duration(minutes: 15);

class KycController extends Notifier<KycState> {
  var _request = 0;

  @override
  KycState build() {
    ref.watch(kycServiceProvider);
    Future.microtask(() {
      if (ref.mounted) refresh();
    });
    return const KycState();
  }

  KycService get service => ref.read(kycServiceProvider);

  bool _current(int request) => ref.mounted && request == _request;

  Future<KycStatus?> refresh({bool force = true}) async {
    final now = ref.read(clockProvider)();
    if (!force &&
        state.fetchedAt != null &&
        now.isBefore(state.fetchedAt!.add(kycRefreshTtl))) {
      return state.status;
    }
    final request = ++_request;
    state = state.copyWith(
      loading: true,
      busy: false,
      error: null,
      clearError: true,
    );
    try {
      final status = await service.status();
      if (!_current(request)) return null;
      state = KycState(
        status: status,
        loading: false,
        fetchedAt: ref.read(clockProvider)(),
      );
      return status;
    } on KycRefused catch (error) {
      if (_current(request)) {
        state = state.copyWith(loading: false, busy: false, error: error);
      }
    } on Object {
      if (_current(request)) {
        state = state.copyWith(
          loading: false,
          busy: false,
          error: const KycRefused(KycProblem.unavailable),
        );
      }
    }
    return null;
  }

  Future<KycStatus?> verify(KycCheck check) =>
      _write((service) => service.verify(check));

  Future<KycStatus?> upload(KycCheckKind check, KycEvidence file) =>
      _write((service) => service.upload(check, file));

  Future<KycStatus?> _write(
    Future<KycStatus> Function(KycService service) send,
  ) async {
    if (!ref.mounted || state.busy) return state.status;
    final request = ++_request;
    final target = service;
    state = state.copyWith(busy: true, error: null, clearError: true);
    try {
      final status = await send(target);
      if (!_current(request)) return null;
      state = KycState(
        status: status,
        loading: false,
        fetchedAt: ref.read(clockProvider)(),
      );
      return status;
    } on KycRefused catch (error) {
      if (_current(request)) {
        state = state.copyWith(busy: false, error: error);
      }
    } on Object {
      if (_current(request)) {
        state = state.copyWith(
          busy: false,
          error: const KycRefused(KycProblem.unavailable),
        );
      }
    }
    return null;
  }
}

class KycState {
  const KycState({
    this.status,
    this.loading = true,
    this.busy = false,
    this.error,
    this.fetchedAt,
  });

  final KycStatus? status;
  final bool loading;
  final bool busy;
  final KycRefused? error;
  final DateTime? fetchedAt;

  KycState copyWith({
    KycStatus? status,
    bool? loading,
    bool? busy,
    KycRefused? error,
    DateTime? fetchedAt,
    bool clearError = false,
  }) => KycState(
    status: status ?? this.status,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
}

final kycControllerProvider =
    NotifierProvider.autoDispose<KycController, KycState>(KycController.new);

/// Keeps a connectivity listener only while a Discover requirement remains.
final kycNudgeRefreshProvider = Provider<void>((ref) {
  final status = ref.watch(kycControllerProvider).status;
  if (status?.canSubmit == true && status?.canWithdraw == true) return;
  final api = ref.watch(apiClientProvider);
  if (api == null) return;
  final subscription = api.reachable.listen((_) {
    unawaited(ref.read(kycControllerProvider.notifier).refresh(force: false));
  });
  ref.onDispose(subscription.cancel);
});
