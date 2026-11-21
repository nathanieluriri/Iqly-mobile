# iOS setup for the OS surfaces

The widget extension is now part of `ios/Runner.xcodeproj`: `tool/ios_surfaces_target.rb` added it (run it again on a fresh project with `gem install xcodeproj` first; it does nothing when the target is there). The `ios` workflow builds the app with the extension, unsigned, on every pull request that touches `ios/`.

## What the script set up

- Target `IqlySurfaces` (bundle id `net.iqly.app.IqlySurfaces`, iOS 16.1), with the Swift in `ios/IqlySurfaces`, its asset catalog, `IqlySurfaces/Info.plist` (merged with generated keys), `IqlySurfaces/IqlySurfaces.entitlements`, and the three fonts the widgets use from `assets/fonts`. Its version and build number come from Flutter's xcconfig, as the app's do.
- `ios/IqlySurfaces/Shared/SurfaceShared.swift` in both targets; `ios/RunnerSurfaces/SurfacesChannel.swift` in Runner only.
- Runner embeds `IqlySurfaces.appex` in an Embed Foundation Extensions phase placed before Thin Binary, and points `CODE_SIGN_ENTITLEMENTS` at `Runner/Runner.entitlements` (push, App Group, Sign in with Apple). Without that setting the app is signed with none of them, so OneSignal cannot register on iPhone.
- `AppDelegate.swift` registers the channel, which also listens to the scene for `iqly://` links from widgets and the Live Activity (other links pass on to the plugins), and sets the notification centre delegate so banners show while the app is open.

## Still to do in the Apple Developer account

1. Create the App Group `group.net.iqly.app` and enable it for `net.iqly.app` and `net.iqly.app.IqlySurfaces`.
2. Turn on Sign in with Apple and Push Notifications for `net.iqly.app`.
3. Choose the signing team for both targets in Xcode (Signing & Capabilities), or set `DEVELOPMENT_TEAM`, before the first signed build.

## Check on device

- Long press the icon: Answer a quick poll, Continue my draft, My submissions with their icons (347:16322).
- Add the Medium and Small widgets (347:16187). Tap a brief row: the app opens that brief after splash.
- Ask for a withdrawal (once the Wallet lane calls `Surfaces.payoutChanged`): the Live Activity shows on the lock screen and in the Dynamic Island with "On its way" (347:16446, 347:16489).
- Withdraw confirm (Wallet lane, local_auth): Face ID prompt uses NSFaceIDUsageDescription.
