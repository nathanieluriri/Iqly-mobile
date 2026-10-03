# Preview films

Each flow in `flows/` drives the real app (`IqlyApp`, demo data) as a widget test on iOS, one frame per 1/60 s, and streams every frame into ffmpeg: the phone at 390 x 844 on a dark stage, 1080 x 1920 at 60 fps, with the status bar, keyboard and touches drawn by `harness.dart`.

Needs Flutter and ffmpeg (with libx264) on `PATH`.

```
film/render.sh                      # every flow
film/render.sh first_open_signup    # one flow
flutter test film/flows/forgot_password_film.dart   # the video only
```

Output lands in `film/out/` (not committed): `<name>.mp4`, `<name>-sheet.png` (a frame every 0.5 s), `<name>-transitions/` (the second after each tap at 30 fps, cropped to the screen at 390 wide), `<name>.taps` (tap times) and `<name>.errors` (errors the app reported, with the time and screen).

The status bar and home indicator are the Figma Mobile/StatusBar and Mobile/HomeIndicator exports in `assets/`.
