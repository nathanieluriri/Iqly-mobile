# Android 15 and Saved Brief Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct Android edge-to-edge system UI behavior and replace both phone Saved ticket lists with Discover's existing feature brief cards.

**Architecture:** Add one shared system UI module for startup mode and transparent overlay styles, then migrate existing screen annotations to it. Reuse `BriefFeatureCard` and extract the existing Discover feature-card skeleton so Saved loading and loaded states match the main feed.

**Tech Stack:** Flutter 3.50, Dart 3.14, Flutter widget tests, existing Riverpod providers and iQLY design tokens.

**Spec:** `docs/specs/2026-11-27-android15-saved-ui-design.md`

## Global Constraints

- Work only in `fix/android15-saved-ui`, created from `dev`.
- Use Flutter 3.50 or newer with Dart `^3.13.5` compatibility. No dependency changes.
- No AI attribution in code, docs, commits, pull requests, or comments.
- Every commit is authored by `nathanieluriri <uririnathaniel@gmail.com>` with signing disabled.
- Never use an em dash in code, comments, docs, commit messages, or pull requests.
- Use existing tokens and components. `Colors.transparent` is allowed for system bars.
- Keep existing copy, routes, persistence, accessibility behavior, motion, and payment or activation behavior unchanged.
- Do not add `android:windowOptOutEdgeToEdgeEnforcement`.
- Do not update unrelated goldens or rewrite baseline failures merely to pass.

## Review Focus

- Android 15 ignores system bar colors, so light navigation icons must not remain on light surfaces. Task 1 pins transparent bars and dark navigation icons.
- Landscape cutouts and three-button navigation create side and bottom insets. Task 4 pins Saved cards inside all safe insets.
- Keyboard insets must not move the bottom dock. Task 4 pins the dock against stable `viewPadding.bottom`.
- A saved brief unsaved during its collapse animation must be cancellable. Task 3 preserves and tests the existing re-save window.
- Saved briefs must remain available offline, including populated and empty local state. Task 3 tests both the Saved lens and More page.
- Large text must not clip the replacement cards. Task 3 verifies the existing feature card behavior at increased text scale.

---

### Task 1: Shared edge-to-edge system UI contract

**Files:**
- Create: `lib/core/system_ui.dart`
- Create: `test/core/system_ui_test.dart`
- Modify: `lib/main.dart:38-45`

**Interfaces:**
- Produces: `Future<void> configureEdgeToEdge()` and `class IqSystemUi` with `static const SystemUiOverlayStyle paper` and `static const SystemUiOverlayStyle ink`.
- `paper` uses transparent status and navigation bars, dark icons on both, `statusBarBrightness: Brightness.light`, and both contrast flags false.
- `ink` uses transparent status and navigation bars, light icons on both, `statusBarBrightness: Brightness.dark`, and both contrast flags false.

- [ ] **Step 1: Write failing tests**

Create `test/core/system_ui_test.dart` with tests named:

- `Android startup requests edge-to-edge mode`
- `other platforms keep their default system UI mode`
- `paper overlays keep dark icons on transparent bars`
- `ink overlays keep light icons on transparent bars`

For the startup tests, mock `SystemChannels.platform`, set `debugDefaultTargetPlatformOverride`, call `configureEdgeToEdge()`, and assert the method and argument. Assert Android sends `SystemChrome.setEnabledSystemUIMode` with `SystemUiMode.edgeToEdge.toString()`, while iOS and Windows send no method call.

For style tests, assert transparent `statusBarColor`, `systemNavigationBarColor`, and `systemNavigationBarDividerColor`, the expected icon brightness values, and false contrast flags.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/core/system_ui_test.dart`
Expected: FAIL because `core/system_ui.dart` does not exist.

- [ ] **Step 3: Implement the shared module**

Create `lib/core/system_ui.dart` with the exact interface above. Guard the startup call with `defaultTargetPlatform == TargetPlatform.android`. Call and await `configureEdgeToEdge()` in `main()` immediately after `WidgetsFlutterBinding.ensureInitialized()`.

- [ ] **Step 4: Run tests and verify pass**

Run: `flutter test test/core/system_ui_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/system_ui.dart lib/main.dart test/core/system_ui_test.dart
git commit -m "fix(mobile): configure Android edge-to-edge system UI"
```

### Task 2: Use surface-aware overlay styles across screens

**Files:**
- Create: `lib/core/system_ui.dart` is consumed from Task 1.
- Modify: all `lib/features/**/*.dart` files containing `SystemUiOverlayStyle.dark` or `SystemUiOverlayStyle.light`.
- Modify: `test/features/splash_motion_test.dart:130-216`

**Interfaces:**
- Consumes: `IqSystemUi.paper` and `IqSystemUi.ink` from Task 1.
- Light-surface annotations use `IqSystemUi.paper`; dark splash, update, and first-tip scrim annotations use `IqSystemUi.ink`.

- [ ] **Step 1: Update splash expectations to the new contract**

Replace the six `SystemUiOverlayStyle.light` and `.dark` expectations in `test/features/splash_motion_test.dart` with `IqSystemUi.ink` and `IqSystemUi.paper` respectively. Add the `core/system_ui.dart` import.

- [ ] **Step 2: Run splash tests and verify failure**

Run: `flutter test test/features/splash_motion_test.dart`
Expected: FAIL because screens still emit the framework overlay constants.

- [ ] **Step 3: Migrate screen annotations**

In every feature file that currently references `SystemUiOverlayStyle.dark`, import `core/system_ui.dart` and replace the value with `IqSystemUi.paper`. Replace `SystemUiOverlayStyle.light` with `IqSystemUi.ink` in splash, update, and first-tip scrim code. Remove `package:flutter/services.dart` imports only when no other services API remains in that file.

- [ ] **Step 4: Verify no framework constants remain in app code**

Run: `grep -R "SystemUiOverlayStyle\\.\\(dark\\|light\\)" lib`
Expected: no matches.

- [ ] **Step 5: Run overlay and splash tests**

Run: `flutter test test/core/system_ui_test.dart test/features/splash_motion_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features test/features/splash_motion_test.dart
git commit -m "fix(mobile): use transparent surface-aware system bars"
```

### Task 3: Replace Saved tickets with shared Discover feature cards

**Files:**
- Modify: `lib/features/discover/saved_briefs_screen.dart`
- Modify: `lib/features/more/saved_briefs_page.dart`
- Modify: `lib/features/discover/discover_widgets.dart`
- Modify: `lib/features/discover/home_screen.dart`
- Modify: `test/features/discover_flow_test.dart:67-132`
- Create: `test/features/saved_briefs_ui_test.dart`
- Modify: `test/golden/screens/discover_test.dart:212-239`
- Modify: Saved goldens under `test/golden/screens/goldens/` and `test/golden/goldens/` only after visual comparison.

**Interfaces:**
- Consumes: existing `BriefFeatureCard`, `savedBriefsProvider`, `discoverFeedProvider`, `AppShell.contentInset`, and `IqBriefCard`.
- Produces: `class BriefFeatureCardSkeleton extends StatelessWidget` in `discover_widgets.dart`, used by Home and Saved.

- [ ] **Step 1: Write failing Saved UI tests**

Add focused tests in `test/features/saved_briefs_ui_test.dart`:

- Phone Saved renders three `IqBriefCard` feature cards and zero `IqTicketCard` widgets for the standard saved fixture.
- More > Saved briefs renders `IqBriefCard` and zero `IqTicketCard` widgets.
- Each Saved card keeps its title, bookmark, reward, deadline, and navigation callback.
- Unsaving a card starts the collapse, and re-saving before removal completes cancels removal.
- Offline populated Saved still renders cards and the offline banner.
- Offline empty Saved still renders the existing empty state.
- At text scale 2.0, Saved cards lay out without exceptions or overflow.

Update the existing Discover flow assertion at line 108 from three tickets to three feature cards and assert zero tickets.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/features/saved_briefs_ui_test.dart test/features/discover_flow_test.dart`
Expected: FAIL because Saved still renders `BriefTicket`.

- [ ] **Step 3: Extract and reuse the feature-card skeleton**

Move the existing `_SkeletonCard` implementation from `home_screen.dart` into `discover_widgets.dart` as public `BriefFeatureCardSkeleton`. Replace Home's two `_SkeletonCard` uses with the shared widget. Use the shared skeleton in the phone Saved loading state with 24 pt gaps and the existing horizontal inset.

- [ ] **Step 4: Replace Saved ticket cards**

In `saved_briefs_screen.dart`, replace `BriefTicket(brief: brief)` with `BriefFeatureCard(brief: brief)` and change the bottom gap to `IqSpace.s6`.

In `saved_briefs_page.dart`, make the same replacement and gap change. Update its doc comment to state that Saved uses Discover's feature cards.

Keep `BriefTicket` unchanged for tablet For you closing-soon tickets.

- [ ] **Step 5: Run focused behavior tests**

Run: `flutter test test/features/saved_briefs_ui_test.dart test/features/discover_flow_test.dart test/features/discover_motion_test.dart test/ui/discover_components_motion_test.dart`
Expected: PASS.

- [ ] **Step 6: Regenerate only affected Saved goldens**

Run the Saved cases in `test/golden/screens/discover_test.dart` and the More Saved cases with `flutter test --update-goldens`. Compare `discover_saved.png`, `discover_saved_offline.png`, `more_saved_briefs.png`, and `more_saved_briefs_offline.png` at 390 x 844. Reject unrelated golden changes.

- [ ] **Step 7: Run affected golden tests**

Run the Saved and More Saved golden tests without update mode.
Expected: PASS with only intentional card and spacing differences.

- [ ] **Step 8: Commit**

```bash
git add lib/features/discover lib/features/more/saved_briefs_page.dart test/features test/golden
git commit -m "fix(mobile): use normal brief cards in Saved"
```

### Task 4: Prove edge-to-edge inset behavior and run full verification

**Files:**
- Create: `test/features/edge_to_edge_layout_test.dart`
- Modify: only files required if an inset regression exposes a real defect.

**Interfaces:**
- Consumes: `AppShell`, `SavedBriefsScreen`, `IqSystemUi`, and existing test harnesses from Tasks 1 through 3.

- [ ] **Step 1: Write failing inset tests**

Create tests named:

- `Saved content clears status, navigation, and landscape cutout insets`
- `dock stays anchored while the keyboard inset changes`
- `Saved system bars use paper overlay style`

Use `FakeViewPadding` with Android 15 representative values. Assert the top bar begins below the top inset, the first Saved card is horizontally inside left and right insets, the scroll bottom clearance includes `viewPadding.bottom`, and the dock bottom equals the stable bottom view inset. Change `viewInsets.bottom` and assert the dock position does not change.

- [ ] **Step 2: Run tests and verify current behavior**

Run: `flutter test test/features/edge_to_edge_layout_test.dart`
Expected: PASS if existing inset handling is correct. If a test fails, preserve the failure output and fix only the specific inset cause before continuing.

- [ ] **Step 3: Run formatting and static checks**

```bash
dart run tool/gen_tokens.dart --check
dart format lib test tool
flutter analyze
```

Expected: token check passes, formatting completes, and analyze reports no errors.

- [ ] **Step 4: Run focused regression suite**

```bash
flutter test test/core/system_ui_test.dart test/features/edge_to_edge_layout_test.dart test/features/saved_briefs_ui_test.dart test/features/discover_flow_test.dart test/features/discover_motion_test.dart test/features/splash_motion_test.dart test/features/more_flow_test.dart test/golden/screens/discover_test.dart
```

Expected: PASS. Record any pre-existing baseline failures separately and do not alter unrelated goldens.

- [ ] **Step 5: Run full suite**

Run: `flutter test`
Expected: all tests pass, or only explicitly documented pre-existing baseline failures remain with no new failures.

- [ ] **Step 6: Review the diff and commit**

Run `git diff --check`, inspect `git status`, and confirm no em dashes, AI attribution, unrelated files, or unrelated golden changes. Commit any inset fix or test additions:

```bash
git add lib test docs
git commit -m "test(mobile): cover Android edge-to-edge insets"
```

- [ ] **Step 7: Final verification record**

Run `git status --short --branch` and `git log -1 --format='%h %an <%ae> %s'`. Record the Flutter and Dart versions plus the exact passing test counts in the handoff.
