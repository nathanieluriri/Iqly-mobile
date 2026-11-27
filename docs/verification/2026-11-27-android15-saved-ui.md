# Android 15 and Saved UI verification

Date: 2026-11-27
Branch: `fix/android15-saved-ui`
Base: `dev` at `ec6f9bf`

## Toolchain

- Flutter 3.50.0
- Dart 3.14.0
- Compatible with the project's Dart `^3.13.5` constraint.

## Passing focused checks

- System UI contract: 4 passed.
- Android inset and overlay layout: 3 passed.
- Saved UI behavior: 7 passed.
- Splash overlay motion: 6 passed.
- Discover component motion: 26 passed.
- Saved unsave collapse motion: 1 passed.
- Updated Saved goldens: 4 passed.
- Empty Saved goldens were left unchanged.

Combined focused run: 46 passed across system UI, insets, Saved UI, splash, and shared Discover components. The Saved motion test and four Saved goldens also passed in their focused runs.

## Static checks

- `dart format lib test tool`: 750 files, 0 changes.
- `flutter analyze --no-fatal-infos`: exit 0 with no errors or warnings. Repository-wide Material deprecation infos remain.
- `git diff --check`: passed.

## Baseline limitations

- `dart run tool/gen_tokens.dart --check` fails on clean `dev` for the same generated token and platform files. No unrelated generated files were rewritten.
- Clean `dev` also reproduces the Discover flow and motion failures caused by the existing assessment-gated fixture, the More flow Check for updates failures, and the Saved empty golden mismatch under Flutter 3.50.
- A full `flutter test` run was attempted and stopped after it entered repeated 10-minute golden `runAsync` timeouts. At termination the reporter showed 2,015 passed, 181 skipped, and 719 failed. This is not a valid full-suite result and is not claimed as one. The failures were broad baseline golden and support-chat timeout failures, not a usable regression signal for this branch.
- The double-text-scale Saved test isolates the real `BriefFeatureCard` list because the existing fixed-height dock overflows independently at 2.0 scale. That separate dock defect was not changed in this branch.

## Visual verification

The four intentionally updated 390 x 844 goldens were inspected after generation:

- `discover_saved.png`
- `discover_saved_offline.png`
- `more_saved_briefs.png`
- `more_saved_briefs_offline.png`

They use the same feature cards, spacing, bookmarks, facts, and offline/empty behavior as the existing app. No unrelated golden was updated.

## Behavior delivered

- Android explicitly requests `SystemUiMode.edgeToEdge`.
- Light surfaces use transparent system bars with dark status and navigation icons.
- Dark splash and update surfaces use transparent system bars with light icons.
- Existing safe areas, landscape cutout insets, stable bottom dock padding, and keyboard behavior are preserved.
- Phone Saved and More > Saved briefs use `BriefFeatureCard`.
- Saved loading uses the same feature-card skeleton as Discover.
