# iQLY mobile

The iQLY contributor app for Android and iOS, with a responsive Windows build. iQLY (iqly.net) is challenge-based crowdsourcing for Africa: businesses post briefs with a reward pool, contributors submit ideas, winners are paid to their bank.

## Run

```
flutter pub get
dart run tool/gen_tokens.dart
flutter run
```

The app runs on the sample dataset in `lib/data/demo_data.dart` until the API is wired.

## Checks

```
dart run tool/gen_tokens.dart --check
dart format lib test tool
flutter analyze
flutter test
```

## Native splash

`flutter_native_splash.yaml` holds the config. After changing it or the PNGs in `assets/splash/`, regenerate the platform files:

```
dart run flutter_native_splash:create
```

See `CLAUDE.md` for the working rules and the project layout.
