import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/api_client.dart';
import '../../data/help_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/recording_player.dart';
import '../../ui/top_bar.dart';
import '../more/more_widgets.dart' show goBack;

/// The session token's headers for a file the person sent to support.
final helpFileHeadersProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) async => await ref.watch(apiClientProvider)?.fileHeaders() ?? const {},
);

/// Opens [file] from its thread.
Future<void> openHelpAttachment(BuildContext context, HelpAttachment file) =>
    context.open('${GoRouterState.of(context).uri.path}/file', extra: file);

/// A file sent in a help thread, read with the session token: a picture to
/// pinch and zoom, a recording or a voice note in the app's player
/// (IqRecordingPlayer). No Figma frame draws it: the page keeps the proof
/// player's layout under the file's name.
class HelpAttachmentScreen extends ConsumerWidget {
  const HelpAttachmentScreen({super.key, required this.file});

  final HelpAttachment? file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = this.file;
    final api = ref.watch(apiClientProvider);
    final url = file?.url;
    final headers = ref.watch(helpFileHeadersProvider).value;
    final source = url == null || api == null
        ? null
        : api.authorized(url.toString());
    Widget body = const SizedBox.shrink();
    if (file != null && source != null && headers != null) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        child: file.kind == HelpAttachmentKind.image
            ? ColoredBox(
                color: IqColors.panel,
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      source.toString(),
                      headers: headers,
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, _) => const Align(
                        alignment: Alignment.topCenter,
                        child: IqBanner(
                          kind: IqBannerKind.error,
                          title: 'Couldn’t load. Check your connection.',
                          showAction: false,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : IqRecordingPlayer(
                source: source,
                headers: headers,
                placeholder: const ColoredBox(color: IqColors.brand),
              ),
      );
    }
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
                  title: file?.name ?? '',
                  onBack: () => goBack(context),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      0,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: body,
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
