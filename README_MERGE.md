
# Patch: Compras + Historial de compras + CSV a Descargas (Android) + Workflow ZIP

Este paquete **no reemplaza** tu repo; agrega carpetas/archivos nuevos y fragmentos
de código para integrar en `popperscuv4` **sin romper** funcionalidades actuales.

## Contenido
- `lib/modules/purchases/...` nuevos modelos, DAOs, repository, service y pantallas
- `lib/services/csv_exporter.dart` exporta CSV a **Descargas** usando MediaStore
- `lib/db/migrations/m_003_purchases.sql` migración de base de datos
- `.github/workflows/zip-project.yml` workflow para crear artefacto ZIP del repo

---

## Pasos de integración

1) **Copiar carpetas/archivos** de este ZIP dentro de tu repo `popperscuv4` respetando rutas.
   - Si ya tienes alguna ruta igual, respalda antes y compara.

2) **Dependencias en `pubspec.yaml`**:
   ```yaml
   dependencies:
     media_store_plus: ^2.3.0
   ```

3) **DB: registrar migración** en tu inicialización/manejador de `sqflite`.
   - Asegúrate de ejecutar `lib/db/migrations/m_003_purchases.sql` cuando `oldVersion < 3`.
   - Si usas un sistema de migraciones distinto, copia el SQL y ajústalo.

4) **Router / Menú**: registra rutas y acceso desde Home:
   - Ruta lista: `/purchases` (lista con expansión)
   - Ruta para crear: `/purchases/new`
   - Añade un botón "Compras" en el menú o `HomePage`.

5) **Historial**: agrega pestaña/segmento "Compras".
   - Puedes reusar `PurchaseListPage` dentro de una Tab o NavigationRail.

6) **Exportación CSV**: sustituye las escrituras a directorio interno por:
   ```dart
   final path = await CsvExporter().saveToDownloads(
     fileName: 'ventas_${DateTime.now().toIso8601String()}.csv',
     csvContent: csv,
   );
   ```
   - Repite para clientes y artículos (renombra `fileName` adecuadamente).

7) **Campos en `products`**: este patch espera columnas `stock`, `cost`, `last_cost`.
   - Si tus nombres difieren, ajusta en `purchase_repository.dart`:
     - `_applyInventoryChange()` → `SELECT/UPDATE products ...`

8) **GitHub Actions**: el workflow `zip-project.yml` sube:
   - **project-zip**: ZIP del repo completo (sin `.git`)
   - **app-debug-apk**: APK debug

9) **Probar**:
   - `flutter pub get`
   - Ejecuta migración (corre la app y verifica tablas).
   - Crea un proveedor, registra una compra con 1–2 productos.
   - Verifica que el stock sube y el costo promedio se actualiza.
   - Exporta CSVs y confirma que están en **Descargas/PopppersCUV**.

---

## Notas
- Android 10+: MediaStore evita pedir WRITE_EXTERNAL_STORAGE.
- Si necesitas selector de ruta, considera `flutter_file_dialog`.
- Las pantallas incluidas tienen UI mínima para integrarse rápido;
  adáptalas al estilo visual de tu app.
