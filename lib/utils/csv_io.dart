import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class CsvIO {
  static Future<String> exportTableToDownloads(String table) async {
    final db = await AppDatabase().database;
    final rows = await db.query(table);
    final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
    final data = <List<dynamic>>[headers];
    for (final r in rows) { data.add(headers.map((h) => r[h]).toList()); }
    final csv = const ListToCsvConverter().convert(data);
    final savedPath = await FileSaver.instance.saveFile(
      name: '$table.csv',
      bytes: utf8.encode(csv),
      mimeType: MimeType.csv,
    );
    return savedPath ?? 'Descargas';
  }

  static Future<String> exportTableLocal(String table) async {
    final db = await AppDatabase().database;
    final rows = await db.query(table);
    final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
    final data = <List<dynamic>>[headers];
    for (final r in rows) { data.add(headers.map((h) => r[h]).toList()); }
    final csv = const ListToCsvConverter().convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$table.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  static Future<int> importProductsFromCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.isEmpty) return 0;
    final path = result.files.single.path!;
    final text = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(text);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    int count = 0;
    final db = await AppDatabase().database;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      final m = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < r.length; j++) {
        m[headers[j]] = r[j];
      }
      try { await db.insert('products', Map<String, dynamic>.from(m)); count++; } catch (_) {}
    }
    return count;
  }

  static Future<int> importCustomersFromCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.isEmpty) return 0;
    final path = result.files.single.path!;
    final text = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(text);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    int count = 0;
    final db = await AppDatabase().database;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      final m = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < r.length; j++) {
        m[headers[j]] = r[j];
      }
      try { await db.insert('customers', Map<String, dynamic>.from(m)); count++; } catch (_) {}
    }
    return count;
  }
}
