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

> v0.9.1: Se elimina el uso de `ndk.dir`. Gradle selecciona el NDK por **versión** (`ndkVersion`).
# popperscuv4 — Android-only patch kit

Este paquete contiene **lib/** completa (modelos, repos, UI y DB bootstrap), `pubspec.yaml` y un fragmento de `AndroidManifest.xml` para permisos.
Úsalo de dos formas:

## A) Integrarlo a tu repo existente
1. Copia **lib/** encima de tu `lib/` (conserva tus páginas si necesitas; renombra conflictos).
2. Copia `pubspec.yaml` y fusiona dependencias (no pierdas tus paquetes actuales).
3. Agrega los permisos del archivo `android/AndroidManifest.additions.xml` a tu `android/app/src/main/AndroidManifest.xml`.
4. Sube `dbVersion` y corre la app para que ejecute **migraciones**.
5. Asegura rutas de navegación a:
   - `PurchasesListPage(repo: purchaseRepo)`
   - `SaleDetailPage(saleId: id, repo: saleRepo)`

## B) Crear un proyecto nuevo rápido
1. `flutter create popperscuv4_android`
2. Copia **lib/** y `pubspec.yaml` de este paquete sobre el nuevo proyecto.
3. Pega los permisos de `android/AndroidManifest.additions.xml`.
4. `flutter pub get`
5. `flutter run` (Android).

> Este kit es **Android-only** y no incluye iOS/web/desktop.
