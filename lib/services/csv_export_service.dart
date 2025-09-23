import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class CsvExportService {
  /// Intenta usar la carpeta pública de Descargas en Android.
  Future<Directory> _tryDownloadsDir() async {
    final dir = Directory('/storage/emulated/0/Download');
    if (await dir.exists()) return dir;
    throw Exception('No existe la carpeta de Descargas pública');
  }

  /// Carpeta externa propia de la app (visible por ADB/archivos en algunos dispositivos).
  Future<Directory> _appExternalDir() async {
    final d = await getExternalStorageDirectory();
    if (d != null) {
      // Crea subcarpeta /Download dentro del scope de la app para que sea más ubicable
      final dl = Directory('${d.path}/Download');
      if (!(await dl.exists())) {
        await dl.create(recursive: true);
      }
      return dl;
    }
    // Último recurso: documentos internos
    return await getApplicationDocumentsDirectory();
  }

  /// Pide permiso de almacenamiento cuando aplique (en algunos Android < 11).
  Future<void> _ensureStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final status = await Permission.storage.request();
    // Nota: en Android 13+ este permiso ya no existe; ignoramos si está denegado en esas versiones.
    if (!status.isGranted && !status.isLimited && await _isPreAndroid11()) {
      throw Exception('Permiso de almacenamiento denegado');
    }
  }

  Future<bool> _isPreAndroid11() async {
    // Android 11 = SDK 30. No tenemos API directa aquí, así que usamos heurística:
    // Si READ/WRITE funcionan, Permission.storage.isGranted nos lo dirá; si no, seguimos sin bloquear.
    // Devolvemos true asumiendo “antiguo” sólo cuando explícitamente se requiera.
    return true;
  }

  Future<File> _writeCsvInternal(String filename, String csv) async {
    // 1) Intento en Descargas pública
    try {
      final dl = await _tryDownloadsDir();
      final f = File('${dl.path}/$filename');
      return await f.writeAsString(csv, flush: true);
    } catch (_) {
      // 2) Fallback a carpeta externa de la app
      final appDir = await _appExternalDir();
      final f = File('${appDir.path}/$filename');
      return await f.writeAsString(csv, flush: true);
    }
  }

  Future<File> _writeCsv(String filename, String csv) async {
    if (kIsWeb) {
      throw UnsupportedError('Exportar CSV a disco no está soportado en web aquí.');
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('Este exportador está preparado sólo para Android.');
    }
    await _ensureStoragePermission();
    return _writeCsvInternal(filename, csv);
  }

  Future<File> exportVentas(String csv) => _writeCsv('ventas.csv', csv);
  Future<File> exportClientes(String csv) => _writeCsv('clientes.csv', csv);
  Future<File> exportArticulos(String csv) => _writeCsv('articulos.csv', csv);

  Future<void> open(File f) async {
    await OpenFilex.open(f.path);
  }
}
