import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/share_service.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/share_card.dart';
import '../../ui/share_target.dart';
import '../../ui/top_bar.dart';
import '../submissions/row_card.dart';
import 'outcomes_state.dart';
import 'result_screen.dart';

/// B13 · Share sheet (193:9621) over the Winner, on the brand .35 scrim. The
/// card flies into the 0.62 preview (MOTION-SPEC §4.4) and the targets pop
/// in 40 apart. A target hands the card, rendered at 3x, to that app (More…
/// to the system sheet) through ShareService; Copy link copies the brief's
/// page, Save image keeps the card in the photo library; each closes the
/// sheet, as the scrim, the close button and WhatsApp do in Figma.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.id});

  final String id;

  static const double previewWidth = 222;

  static const _targets = [
    (IqShareTargetKind.whatsapp, ShareApp.whatsapp),
    (IqShareTargetKind.instagram, ShareApp.instagram),
    (IqShareTargetKind.x, ShareApp.x),
    (IqShareTargetKind.telegram, ShareApp.telegram),
    (IqShareTargetKind.more, null),
  ];

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _png() async {
    if (_card.currentContext == null) return null;
    final image = await IqShareCard.capture(_card);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> _hand(Future<bool> Function(Uint8List png) to) async {
    if (_busy) return;
    _busy = true;
    final png = await _png();
    final done = png != null && await to(png);
    if (!mounted) return;
    _busy = false;
    if (done) {
      context.pop();
    } else {
      IqHaptics.error.play();
    }
  }

  void _share(ResultData data, ShareApp? app) {
    final share = ref.read(shareServiceProvider);
    final text = data.outcome?.link;
    _hand((png) async {
      if (app == null) {
        await share.shareImage(png, name: data.shareName, text: text);
      } else {
        await share.shareImageTo(app, png, name: data.shareName, text: text);
      }
      return true;
    });
  }

  void _save(ResultData data) {
    final share = ref.read(shareServiceProvider);
    _hand((png) async {
      final saved = await share.saveImage(png, name: data.shareName);
      if (saved) IqHaptics.success.play();
      return saved;
    });
  }

  /// Pops true, so the result says so above its own buttons.
  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    IqHaptics.success.play();
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(resultProvider(widget.id)).value;
    final media = MediaQuery.of(context);
    final link = data?.outcome?.link;
    return CenteredContent(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.top,
        ),
        child: Material(
          color: IqColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IqTopBar(
                variant: IqTopBarVariant.sheet,
                title: 'Share your win',
                onClose: () => context.pop(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: IqSpace.s1,
                    bottom: IqSpace.s4,
                  ),
                  child: data == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: WinnerCard(
                                data: data,
                                width: ShareSheet.previewWidth,
                                cardKey: _card,
                              ),
                            ),
                            const SizedBox(height: IqSpace.s4),
                            Center(
                              child: SizedBox(
                                width:
                                    IqShareTarget.width *
                                    ShareSheet._targets.length,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final (i, (kind, app))
                                        in ShareSheet._targets.indexed)
                                      Pop(
                                        delay: IqDurations.stagger * (4 + i),
                                        child: IqShareTarget(
                                          kind: kind,
                                          onTap: () => _share(data, app),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: IqSpace.s4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: IqSpace.s4,
                              ),
                              child: RowCard(
                                child: Column(
                                  children: [
                                    if (link != null)
                                      IqListRow(
                                        label: 'Copy link',
                                        icon: IqIcons.link,
                                        showDescription: false,
                                        showChevron: false,
                                        onTap: () => _copy(link),
                                      ),
                                    IqListRow(
                                      label: 'Save image',
                                      icon: IqIcons.download,
                                      showDescription: false,
                                      showChevron: false,
                                      divider: false,
                                      onTap: () => _save(data),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: media.padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
