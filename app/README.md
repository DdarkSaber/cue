# Cue app (Flutter)

Android and web client for Cue. See the root `README.md` for what Cue does, where keys live and how to run everything.

```sh
flutter pub get
flutter run -d chrome --web-port 7357
flutter analyze && flutter test
flutter test --tags golden --update-goldens   # after an intended visual change
flutter build web --release --no-web-resources-cdn
```

No API keys belong in this app. It only talks to the Cue Worker.
