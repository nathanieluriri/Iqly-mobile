import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_media.dart';

import 'golden.dart';
import 'press.dart';

Widget _screenshot() => Image.asset(
  'assets/samples/support/withdrawals-screenshot.jpg',
  fit: BoxFit.cover,
);

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqChatMediaKind.values) {
    for (final tone in IqChatMediaTone.values) {
      testWidgets('${kind.name} ${tone.name}', (tester) async {
        await expectComponentGolden(
          tester,
          'chat_media_${kind.name}_${tone.name}',
          IqChatMedia(
            kind: kind,
            tone: tone,
            width: kind == IqChatMediaKind.file ? 240 : 210,
            duration: kind == IqChatMediaKind.video ? '0:31' : '0:24',
            image: kind == IqChatMediaKind.image ? _screenshot() : null,
          ),
          size: switch (kind) {
            IqChatMediaKind.image ||
            IqChatMediaKind.video => const Size(210, 172),
            IqChatMediaKind.voice => const Size(182, 56),
            IqChatMediaKind.file => const Size(240, 53),
          },
          background: tone == IqChatMediaTone.ink
              ? IqColors.brand
              : IqColors.card,
        );
      });
    }
  }

  for (final (name, media) in [
    (
      'image_loading',
      const IqChatMedia(
        kind: IqChatMediaKind.image,
        state: IqChatMediaState.loading,
      ),
    ),
    (
      'image_loading_progress',
      const IqChatMedia(
        kind: IqChatMediaKind.image,
        state: IqChatMediaState.loading,
        progress: 0.4,
      ),
    ),
    (
      'image_uploading',
      IqChatMedia(
        kind: IqChatMediaKind.image,
        tone: IqChatMediaTone.ink,
        state: IqChatMediaState.loading,
        progress: 0.7,
        image: _screenshot(),
      ),
    ),
    (
      'voice_playing',
      const IqChatMedia(
        kind: IqChatMediaKind.voice,
        playing: true,
        played: 13,
        duration: '0:12',
      ),
    ),
    (
      'voice_playing_ink',
      const IqChatMedia(
        kind: IqChatMediaKind.voice,
        tone: IqChatMediaTone.ink,
        playing: true,
        played: 13,
        duration: '0:12',
      ),
    ),
    (
      'voice_loading',
      const IqChatMedia(
        kind: IqChatMediaKind.voice,
        state: IqChatMediaState.loading,
        played: 0,
      ),
    ),
    (
      'image_failed',
      IqChatMedia(
        kind: IqChatMediaKind.image,
        state: IqChatMediaState.failed,
        onRetry: () {},
      ),
    ),
  ]) {
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        'chat_media_$name',
        stillMotion(media),
        size: media.kind == IqChatMediaKind.voice
            ? const Size(182, 56)
            : const Size(210, 172),
        background: media.tone == IqChatMediaTone.ink
            ? IqColors.brand
            : IqColors.card,
      );
    });
  }
}
