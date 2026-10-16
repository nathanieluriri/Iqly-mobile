import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/patches.dart';
import 'package:iqly_mobile/data/patches.dart';

import '../support/fake_patches.dart';

void main() {
  late DateTime now;
  late FakePatchService service;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        patchServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    now = DateTime(2026, 10, 16, 9);
    service = FakePatchService();
  });

  test('no patch leaves the app alone', () async {
    final c = container();
    await c.read(patchesProvider.notifier).check();
    expect(c.read(patchesProvider), PatchPhase.idle);
  });

  test('a patch already on disk is ready at once', () async {
    service.found = [PatchCheck.ready];
    final c = container();
    await c.read(patchesProvider.notifier).check();
    expect(c.read(patchesProvider), PatchPhase.ready);
    expect(service.downloads, 0);
  });

  test('downloads, then is ready once the patch is on disk', () async {
    service.found = [PatchCheck.available, PatchCheck.ready];
    final c = container();
    final phases = <PatchPhase>[];
    c.listen(patchesProvider, (_, next) => phases.add(next));
    await c.read(patchesProvider.notifier).check();
    expect(phases, [PatchPhase.downloading, PatchPhase.ready]);
    expect(c.read(patchesProvider), PatchPhase.ready);
    expect(service.downloads, 1);
  });

  test('waits for the launch download Shorebird already started', () {
    fakeAsyncCheck((async, c) {
      service.found = [
        PatchCheck.available,
        PatchCheck.available,
        PatchCheck.available,
        PatchCheck.ready,
      ];
      c.read(patchesProvider.notifier).check();
      async.elapse(const Duration(seconds: 1));
      expect(c.read(patchesProvider), PatchPhase.downloading);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(patchesProvider), PatchPhase.ready);
    }, container);
  });

  test('a failed download says so, and Continue stops asking', () async {
    service.found = [PatchCheck.available];
    service.fail = true;
    final c = container();
    final patches = c.read(patchesProvider.notifier);
    await patches.check();
    expect(c.read(patchesProvider), PatchPhase.failed);

    patches.dismiss();
    expect(c.read(patchesProvider), PatchPhase.idle);
    service.fail = false;
    service.found = [PatchCheck.ready];
    await patches.check();
    expect(c.read(patchesProvider), PatchPhase.idle);
  });

  test('gives up after 30 s without the patch on disk', () {
    fakeAsyncCheck((async, c) {
      service.found = [PatchCheck.available];
      c.read(patchesProvider.notifier).check();
      async.elapse(const Duration(seconds: 29));
      expect(c.read(patchesProvider), PatchPhase.downloading);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(patchesProvider), PatchPhase.failed);
    }, container);
  });

  test('a resume checks again only once an hour has passed', () async {
    final c = container();
    final patches = c.read(patchesProvider.notifier);
    await patches.check();
    now = now.add(const Duration(minutes: 59));
    patches.resumed();
    expect(service.checks, 1);
    now = now.add(const Duration(minutes: 1));
    patches.resumed();
    expect(service.checks, 2);
  });

  test('Close iQLY ends the app through the service', () async {
    final c = container();
    await c.read(patchesProvider.notifier).close();
    expect(service.closed, isTrue);
  });
}
