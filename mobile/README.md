# EssayPad Mobile

Flutter mobile MVP for EssayPad. Notes are stored locally with `shared_preferences`; mobile-to-desktop sync is intentionally outside this first milestone.

## Initialize platform shells

After Flutter SDK installation, run from this directory:

```bash
flutter create --platforms=ios,android .
flutter pub get
flutter test
flutter run
```

The existing source files remain intact when Flutter creates the iOS and Android platform folders.
