import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/top_bar.dart';
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

/// The proof recording at full size, opened from the polaroid's play
/// sticker: its frame flies out of the thumbnail with the push (Hero,
/// MOTION-SPEC §4.4; heroes are off under reduced motion). There is no
/// Figma frame for it: the page reuses the Your proof title and the
/// polaroid's caption. The live version plays the recording here with
/// video_player; the demo has no video, so it shows the frame.
class ProofPlayerScreen extends ConsumerWidget {
  const ProofPlayerScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(activationProvider(id))?.progress?.proof?.video;
    final video = sent ?? ref.watch(proofDraftProvider(id)).video;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Your proof',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(activationPath(id)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                    child: Hero(
                      tag: proofHeroTag(id),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(IqRadius.xl2),
                        child: const ProofFrame(),
                      ),
                    ),
                  ),
                ),
                if (video != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s3,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.bodyStrong.copyWith(
                              color: IqColors.fg,
                            ),
                          ),
                          const SizedBox(height: IqSpace.s0p5),
                          Text(
                            videoFacts(video),
                            style: IqText.small.copyWith(color: IqColors.fg3),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
