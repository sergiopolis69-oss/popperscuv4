// lib/services/csv_export_service.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class CsvExportService {
  Future<Directory> _tryDownloadsDir() async {
    final dir = Directory('/storage/emulated/0/Download');
    if (await dir.exists()) return dir;
    throw Exception('No existe Descargas pública');
  }

  Future<Directory> _appExternalDir() async {
    final d = await getExternalStorageDirectory();
    if (d != null) {
      final dl = Directory('${d.path}/Download');
      if (!(await dl.exists())) await dl.create(recursive: true);
      return dl;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _ensureStoragePermission() async {
    final status = await Permission.storage.request();
    if (!status.isGranted && !status.isLimited) {
      // En Android 11+ este permiso puede ser irrelevante; no bloquear si falla en 13+.
    }
  }

  Future<File> _writeCsv(String filename, String csv) async {
    await _ensureStoragePermission();
    try {
      final dl = await _tryDownloadsDir();
      return File('${dl.path}/$filename').writeAsString(csv, flush: true);
    } catch (_) {
      final alt = await _appExternalDir();
      return File('${alt.path}/$filename').writeAsString(csv, flush: true);
    }
  }

  Future<File> exportVentas(String csv) => _writeCsv('ventas.csv', csv);
  Future<File> exportClientes(String csv) => _writeCsv('clientes.csv', csv);
  Future<File> exportArticulos(String csv) => _writeCsv('articulos.csv', csv);
  Future<void> open(File f) async => OpenFilex.open(f.path);
}
