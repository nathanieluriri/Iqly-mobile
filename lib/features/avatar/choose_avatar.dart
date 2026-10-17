import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/transitions.dart';
import '../../data/avatar_service.dart' show liveAvatarServiceProvider;
import '../../data/photo_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/avatar.dart';
import '../../ui/avatar_sheet.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/toast.dart';
import '../more/more_widgets.dart';
import 'avatar_state.dart';

/// Opens Choose your avatar (B22, 590:28885 over Your profile, 590:29515
/// over More). A pick moves the ring, holds 150 ms and closes the sheet
/// with the new avatar saved; Make your own closes it and opens the editor;
/// Use a photo takes a photo through the circle crop, which goes back to
/// the sheet until Use photo saves it. While photos go to the account
/// (contract 12.4) holding the saved photo offers to remove it. Tapping
/// outside closes the sheet.
Future<void> chooseAvatar(BuildContext context) async {
  final edit = await Navigator.of(context).push<bool>(
    IqSheetRoute<bool>(
      scrim: IqScrim.fg,
      rise: IqDurations.avatarSheetRise,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (context) => const _AvatarSheetBody(),
    ),
  );
  if (edit == true && context.mounted) {
    await context.open(Routes.avatarEditor);
  }
}

class _AvatarSheetBody extends ConsumerStatefulWidget {
  const _AvatarSheetBody();

  @override
  ConsumerState<_AvatarSheetBody> createState() => _AvatarSheetBodyState();
}

class _AvatarSheetBodyState extends ConsumerState<_AvatarSheetBody> {
  IqAvatarSpec? _picked;
  bool _closing = false;

  Future<void> _pick(IqAvatarSpec spec) async {
    if (_closing) return;
    setState(() {
      _picked = spec;
      _closing = true;
    });
    await Future<void>.delayed(motion(context, IqDurations.ringHold));
    if (!mounted) return;
    await ref.read(avatarProvider.notifier).choose(spec);
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _usePhoto() async {
    if (_closing) return;
    final photos = ref.read(photoServiceProvider);
    final source = photos.hasCamera
        ? await _chooseSource(context)
        : PhotoSource.library;
    if (source == null || !mounted) return;
    final image = await photos.pick(source);
    if (image == null || !mounted) return;
    final cropped = await context.push<Uint8List>(
      Routes.avatarPhoto,
      extra: image,
    );
    if (cropped == null || !mounted) return;
    await _pick(IqPhotoAvatar(cropped));
  }

  /// Online only: the photo goes from the account and from this phone.
  Future<void> _removePhoto() async {
    if (_closing) return;
    final remove = await showIqConfirmSheet(
      context,
      title: 'Remove this photo?',
      body: 'You will need to upload it again to use it.',
      confirmLabel: 'Remove photo',
    );
    if (!remove || !mounted) return;
    try {
      await ref.read(avatarProvider.notifier).removePhoto();
    } on Exception {
      if (!mounted) return;
      errorHaptic();
      IqToast.show(context, 'Couldn’t send. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ref.watch(avatarProvider);
    final photos = ref.watch(liveAvatarServiceProvider)?.photos ?? false;
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      type: MaterialType.transparency,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height - MediaQuery.viewPaddingOf(context).top - 55,
          ),
          child: IgnorePointer(
            ignoring: _closing,
            child: IqAvatarSheet(
              current: _picked ?? avatar.spec,
              photo: avatar.photo,
              onMakeYourOwn: () => Navigator.of(context).pop(true),
              onUsePhoto: _usePhoto,
              onPick: _pick,
              onRemovePhoto: photos ? _removePhoto : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Camera or library for Use a photo: the note says it opens either, and
/// no frame draws the choice, so it is the app's own sheet of two rows.
Future<PhotoSource?> _chooseSource(BuildContext context) {
  return showIqSheet<PhotoSource>(
    context,
    scrim: IqScrim.picker,
    (context) => Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          color: IqColors.bg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(IqAvatarSheet.radius),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s6,
          IqSpace.s4,
          IqSpace.s4 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: RowGroup(
          outlined: true,
          children: [
            IqListRow(
              label: 'Take a photo',
              showDescription: false,
              icon: IqIcons.camera,
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            IqListRow(
              label: 'Choose from your photos',
              showDescription: false,
              icon: IqIcons.background,
              divider: false,
              onTap: () => Navigator.of(context).pop(PhotoSource.library),
            ),
          ],
        ),
      ),
    ),
  );
}
