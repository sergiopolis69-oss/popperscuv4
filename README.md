# PoppersCU v2 — v0.9 (Android embedding v2, NDK 27)

## Local
```bash
./tooling/regen_android.sh
flutter pub get
flutter build apk --debug
```
## CI
Usa `.github/workflows/android-debug.yml` para regenerar `android/` (embedding v2),
forzar **NDK 27.0.12077973**, y publicar `app-debug.apk`.
