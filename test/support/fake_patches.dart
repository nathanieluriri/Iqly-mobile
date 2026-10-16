import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iqly_mobile/data/patches.dart';

/// Answers each check with the next of [found], repeating the last.
class FakePatchService implements PatchService {
  List<PatchCheck> found = [PatchCheck.none];
  bool fail = false;
  int checks = 0;
  int downloads = 0;
  bool closed = false;

  @override
  Future<PatchCheck> check() async {
    final answer = found[checks < found.length ? checks : found.length - 1];
    checks++;
    return answer;
  }

  @override
  Future<void> download() async {
    downloads++;
    if (fail) throw Exception('download failed');
  }

  @override
  Future<void> close() async => closed = true;
}

void fakeAsyncCheck(
  void Function(FakeAsync async, ProviderContainer c) body,
  ProviderContainer Function() container,
) => fakeAsync((async) => body(async, container()));
