import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:open_filex/open_filex.dart';

class CsvExportService {
  Future<Directory> _downloadsDir() async {
    final dir = await DownloadsPathProvider.downloadsDirectory;
    if (dir == null) {
      throw Exception('No se pudo encontrar la carpeta Descargas');
    }
    return dir;
  }

  Future<File> _writeCsv(String filename, String csv) async {
    final status = await Permission.storage.request();
    if (!status.isGranted && !status.isLimited) {
      throw Exception('Permiso de almacenamiento denegado');
    }
    final dir = await _downloadsDir();
    final file = File('${dir.path}/$filename');
    return file.writeAsString(csv, flush: true);
  }

  Future<File> exportVentas(String csv) => _writeCsv('ventas.csv', csv);
  Future<File> exportClientes(String csv) => _writeCsv('clientes.csv', csv);
  Future<File> exportArticulos(String csv) => _writeCsv('articulos.csv', csv);

  Future<void> open(File f) async => OpenFilex.open(f.path);
}
