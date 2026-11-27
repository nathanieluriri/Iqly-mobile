# Android 15 edge-to-edge and Saved brief cards

Date: 2026-11-27
Branch: `fix/android15-saved-ui`
Base: `dev`

## Goal

Make the app behave correctly under Android's API 35 and later edge-to-edge contract, and replace the ticket cards in Saved with the same normal brief cards used in Discover.

## Product decision

The user chose Discover's existing feature card for Saved. This intentionally overrides the older Saved ticket frames in Figma. The main Discover feed, phone Saved lens, and More > Saved briefs page now share one card language.

## Saved experience

### Phone Saved lens

- Keep the existing Discover top bar, pinned lens chips, offline banner, empty state, arrival motion, and unsave collapse motion.
- Render each saved brief with `BriefFeatureCard`.
- Preserve the cover, business logo, business name, title, reward, time, deadline, urgent state, bookmark, draft progress, submitted state, and brief-detail navigation.
- Use the same 24 pt vertical rhythm as the main Discover brief list.
- Use a feature-card-shaped loading placeholder instead of a ticket skeleton.

### More > Saved briefs

- Render the same `BriefFeatureCard` list with the same 24 pt vertical rhythm.
- Keep the existing page top bar, offline banner, empty state, local-offline behavior, and Browse briefs action.

### Tablet

- Tablet Saved already uses the normal carousel/grid brief card and needs no layout change.
- The tablet For you closing-soon tickets are outside the Saved scope and remain unchanged.

## Android edge-to-edge contract

Android enforces edge-to-edge for apps targeting API 35 or later. The implementation embraces that behavior and does not add `windowOptOutEdgeToEdgeEnforcement`.

### System UI mode

- Explicitly request `SystemUiMode.edgeToEdge` on Android at startup so behavior is consistent on API 29 through 34 as well as API 35 and later.
- Leave iOS and Windows behavior unchanged.

### System bar appearance

Introduce shared light-surface and dark-surface overlay styles:

- Light surfaces: transparent status and navigation bars, dark status and navigation icons, no contrast scrim.
- Dark surfaces: transparent status and navigation bars, light status and navigation icons, no contrast scrim.

Replace the framework's `SystemUiOverlayStyle.dark` and `.light` constants in app screens with these shared styles. The framework's `.dark` constant uses light navigation icons because it assumes a black navigation bar. Android 15 ignores that black bar color in edge-to-edge mode, which can leave light icons on the app's light background.

### Insets

- Keep content inside `SafeArea` where it currently is.
- Keep the dock anchored using stable `viewPadding.bottom`, not keyboard-sensitive `padding.bottom`.
- Keep scroll content clearance based on `AppShell.contentInset`.
- Preserve left and right safe-area handling for landscape cutouts and three-button navigation.
- Preserve keyboard inset handling in forms and sheets.

## Accessibility

- Bookmarks remain semantic actions with the existing labels and touch targets.
- Card press, bookmark, and navigation behavior remain unchanged.
- Text scaling continues to use the existing card layout and wrapping.
- Status and navigation icons have contrast appropriate to the surface beneath them.

## Verification

Add focused regressions for:

1. Android startup requests `SystemUiMode.edgeToEdge`.
2. Light and dark overlay styles use transparent bars, correct icon brightness, and disabled contrast scrims.
3. The Saved route renders `IqBriefCard` and no `IqTicketCard`.
4. More > Saved briefs renders `IqBriefCard` and no `IqTicketCard`.
5. Saved content starts below the top inset, remains inside landscape side insets, and clears the bottom dock and navigation inset.
6. The dock stays anchored when the keyboard inset changes.
7. Existing unsave, offline, empty, bookmark, navigation, and reduced-motion behavior still passes.

Update only the Saved goldens affected by the intentional card change after visual comparison at 390 x 844. Do not update unrelated baseline goldens.

Run with the compatible Flutter 3.50 SDK:

- `dart run tool/gen_tokens.dart --check`
- `dart format lib test tool`
- `flutter analyze`
- Focused Saved, inset, overlay, splash, and More tests
- Full `flutter test`

## Rollback

Revert the branch as one unit. The edge-to-edge styles and Saved card replacement do not change data models, API contracts, saved persistence, routing, or payment behavior.
