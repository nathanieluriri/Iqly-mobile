import 'package:flutter/material.dart';

import 'entry_widgets.dart';

/// The show or hide toggle the brief asks for. Figma has no frame for it, so
/// it borrows the screen's text action style.
class ShowPassword extends StatelessWidget {
  const ShowPassword({super.key, required this.shown, required this.onTap});

  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: shown,
      child: EntryLink(label: shown ? 'Hide' : 'Show', onTap: onTap),
    );
  }
}
