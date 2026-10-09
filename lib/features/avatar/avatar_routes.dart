import 'dart:typed_data';

import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'avatar_editor_screen.dart';
import 'avatar_photo_screen.dart';

/// The avatar editor and the photo crop push over their opener: More, Your
/// profile, onboarding's Your avatar, or the picker sheet. The crop needs
/// the picked photo, so a bare link to it goes to the editor.
final avatarRoutes = <RouteBase>[
  GoRoute(
    path: Routes.avatarEditor,
    pageBuilder: (context, state) =>
        pushPage(state, const AvatarEditorScreen()),
  ),
  GoRoute(
    path: Routes.avatarPhoto,
    redirect: (context, state) =>
        state.extra is Uint8List ? null : Routes.avatarEditor,
    pageBuilder: (context, state) =>
        pushPage(state, AvatarPhotoScreen(image: state.extra! as Uint8List)),
  ),
];
