
import 'dart:convert';
import 'dart:typed_data';
import 'package:media_store_plus/media_store_plus.dart';

class CsvExporter {
  final MediaStore _ms = MediaStore();

  Future<String> saveToDownloads({
    required String fileName,
    required String csvContent,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    final entity = await _ms.saveFile(
      fileNameWithExtension: fileName,
      dirType: DirType.download,
      dirName: 'PoppersCUV',
      bytes: bytes,
      mimeType: 'text/csv',
    );
    return entity?.path ?? fileName;
  }
}
