# Preview films

Each flow in `flows/` drives the real app (`IqlyApp`, demo data) as a widget test on iOS, one frame per 1/60 s, and streams every frame into ffmpeg: the phone at 390 x 844 on a dark stage, 1080 x 1920 at 60 fps, with the status bar, keyboard and touches drawn by `harness.dart`. `steps.dart` holds steps several flows share, such as `signIn`, the returning contributor's sign in from a cold open.

Needs Flutter and ffmpeg (with libx264) on `PATH`.

```
film/render.sh                      # every flow
film/render.sh first_open_signup    # one flow
flutter test film/flows/forgot_password_film.dart   # the video only
```

Output lands in `film/out/` (not committed): `<name>.mp4`, `<name>-sheet.png` (a frame every 0.5 s), `<name>-transitions/` (the second after each tap at 30 fps, cropped to the screen at 390 wide), `<name>.taps` (tap times), `<name>.haptics` (each haptic the app asked for, with the time and screen) and `<name>.errors` (errors the app reported, with the time and screen).

`film()` takes `prefs` for the device's saved state (`returning` in `steps.dart` is a signed-in contributor past onboarding), `activations` and `media` to swap in demo sources that fail or start elsewhere (`activations_errors`), and `link` to open the app from a link instead of the splash (`invite_signup`). The phone's own pickers cannot open under the test engine, so the films answer them with the demo pickers (photo access allowed unless a film passes its own `media`).

The status bar and home indicator are the Figma Mobile/StatusBar and Mobile/HomeIndicator exports in `assets/`. The drawn keyboard also sets the view's bottom inset, as iOS does, so a focused field scrolls clear of it.

## Clock

The status bar always reads 9:41, and the app's clock reads the same: the harness pins `clockProvider` to Friday 2 October 2026, 9:41, and builds the demo sources that date things on that moment too (the repository's `DemoData`, and the polls, wallet, help, notifications and activations services, through their `clock` parameters), so deadlines, ages, greetings and "Up to date" times agree with the status bar. The clock stands still for the whole film; the demo's timers run on the test's fake time.

No screen follows the machine clock: every screen reads `clockProvider` or one of those sources.
