import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'avatar.dart';
import 'avatar_choice.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/AvatarSheet: Choose your avatar. Make your own opens the editor, Use
/// a photo the camera or library and then the circle crop; Avatars lists
/// the saved [photo] first, then the six people and the eight buddies;
/// Emojis the twelve emoji avatars. The [current] avatar has the ring.
class IqAvatarSheet extends StatelessWidget {
  const IqAvatarSheet({
    super.key,
    this.current,
    this.photo,
    this.onMakeYourOwn,
    this.onUsePhoto,
    this.onPick,
  });

  final IqAvatarSpec? current;
  final Uint8List? photo;
  final VoidCallback? onMakeYourOwn;
  final VoidCallback? onUsePhoto;
  final ValueChanged<IqAvatarSpec>? onPick;

  static const double radius = 28;

  /// The avatars in the grid, the saved [photo] first.
  static List<IqAvatarSpec> avatars(Uint8List? photo) => [
    if (photo != null) IqPhotoAvatar(photo),
    for (final look in IqAvatarPresets.people) IqPersonAvatar(look),
    for (final kind in IqAvatarBuddyKind.values) IqBuddyAvatar(kind),
  ];

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    IqAvatarChoiceState state(IqAvatarSpec spec) => spec == current
        ? IqAvatarChoiceState.selected
        : IqAvatarChoiceState.standard;
    Widget heading(String text) => Semantics(
      header: true,
      child: Text(text, style: IqText.cardTitle.copyWith(color: IqColors.fg)),
    );
    return Container(
      decoration: const BoxDecoration(
        color: IqColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s2p5,
          IqSpace.s4,
          IqSpace.s6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: IqColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: IqSpace.s4),
            Semantics(
              header: true,
              child: Text(
                'Choose your avatar',
                style: IqText.title.copyWith(color: IqColors.fg),
              ),
            ),
            const SizedBox(height: IqSpace.s4),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: IqIcons.pencil,
                    label: 'Make your own',
                    dashed: true,
                    onTap: onMakeYourOwn,
                  ),
                ),
                const SizedBox(width: IqSpace.s2p5),
                Expanded(
                  child: _Action(
                    icon: IqIcons.camera,
                    label: 'Use a photo',
                    onTap: onUsePhoto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: IqSpace.s4),
            heading('Avatars'),
            const SizedBox(height: IqSpace.s4),
            Wrap(
              spacing: IqSpace.s2p5,
              runSpacing: IqSpace.s2p5,
              children: [
                for (final (i, spec) in avatars(photo).indexed)
                  IqAvatarChoice(
                    avatar: spec,
                    state: state(spec),
                    semanticLabel: _label(spec, i),
                    onTap: onPick == null ? null : () => onPick!(spec),
                  ),
              ],
            ),
            const SizedBox(height: IqSpace.s4),
            heading('Emojis'),
            const SizedBox(height: IqSpace.s4),
            Wrap(
              spacing: 3.2,
              runSpacing: IqSpace.s2,
              children: [
                for (final emoji in IqAvatarPresets.emojis)
                  IqAvatarChoice(
                    kind: IqAvatarChoiceKind.emoji,
                    emoji: emoji,
                    state: state(IqEmojiAvatar(emoji)),
                    semanticLabel: emoji,
                    onTap: onPick == null
                        ? null
                        : () => onPick!(IqEmojiAvatar(emoji)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(IqAvatarSpec spec, int index) => switch (spec) {
    IqPhotoAvatar() => 'Your photo',
    IqPersonAvatar(:final look) =>
      'Person ${IqAvatarPresets.people.indexOf(look) + 1}',
    IqBuddyAvatar(:final kind) => kind.figma,
    IqEmojiAvatar(:final emoji) => emoji,
  };
}

/// "Make your own" and "Use a photo": a 56 tint tile, the icon on a 40 paper
/// disc (dashed for Make your own) and the label.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.dashed = false,
    this.onTap,
  });

  final IqIcons icon;
  final String label;
  final bool dashed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, pressed) => PressDim(
        pressed: pressed,
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(IqSpace.s2),
          decoration: BoxDecoration(
            color: IqColors.tint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: CustomPaint(
                  painter: _IconDisc(dashed: dashed),
                  child: Center(
                    child: IqIcon(icon, size: 24, color: IqColors.brand),
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconDisc extends CustomPainter {
  _IconDisc({required this.dashed});

  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(centre, radius, Paint()..color = IqColors.bg);
    if (dashed) dashedCircle(canvas, centre, radius - 1, 2, IqColors.primary);
  }

  @override
  bool shouldRepaint(_IconDisc old) => old.dashed != dashed;
}
