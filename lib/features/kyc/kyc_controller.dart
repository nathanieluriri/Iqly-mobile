import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/kyc_service.dart';

class KycController extends Notifier<KycState> {
  var _request = 0;

  @override
  KycState build() {
    final service = ref.watch(kycServiceProvider);
    Future.microtask(() {
      if (ref.mounted) refresh(service: service);
    });
    return const KycState();
  }

  KycService get service => ref.read(kycServiceProvider);

  bool _current(int request) => ref.mounted && request == _request;

  Future<KycStatus?> refresh({KycService? service}) async {
    final request = ++_request;
    state = state.copyWith(
      loading: true,
      busy: false,
      error: null,
      clearError: true,
    );
    try {
      final status = await (service ?? this.service).status();
      if (!_current(request)) return null;
      state = KycState(status: status, loading: false);
      return status;
    } on KycRefused catch (error) {
      if (_current(request)) {
        state = KycState(loading: false, error: error);
      }
    } on Object {
      if (_current(request)) {
        state = const KycState(
          loading: false,
          error: KycRefused(KycProblem.unavailable),
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
      state = KycState(status: status, loading: false);
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
  });

  final KycStatus? status;
  final bool loading;
  final bool busy;
  final KycRefused? error;

  KycState copyWith({
    KycStatus? status,
    bool? loading,
    bool? busy,
    KycRefused? error,
    bool clearError = false,
  }) => KycState(
    status: status ?? this.status,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

final kycControllerProvider =
    NotifierProvider.autoDispose<KycController, KycState>(KycController.new);
