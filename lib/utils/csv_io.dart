
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class CsvIO {
  /// Exporta una tabla a CSV en la carpeta de Documentos de la app.
  /// Retorna la ruta completa del archivo.
  static Future<String> exportTable(String table) async {
    final db = await AppDatabase().database;
    final rows = await db.query(table);

    // Encabezados
    final List<String> headers = rows.isEmpty ? <String>[] : rows.first.keys.toList();

    // Construimos data: List<List<dynamic>>
    final List<List<dynamic>> data = <List<dynamic>>[];
    data.add(List<dynamic>.from(headers));
    for (final m in rows) {
      final List<dynamic> row = headers.map<dynamic>((h) => m[h]).toList();
      data.add(row);
    }

    final csv = const ListToCsvConverter().convert(data);
    return await _saveCsvToDocuments(csv, 'export_${table}.csv');
  }

  // Compat wrappers para no tocar UI existente
  static Future<String> exportTableToDownloads(String table) => exportTable(table);
  static Future<String> exportTableLocal(String table) => exportTable(table);

  static Future<String> _saveCsvToDocuments(String csv, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  /// Importa productos desde CSV. Encabezados esperados: name,sku,cost,price,stock,category
  static Future<int> importProductsFromCsv() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (picked == null || picked.files.isEmpty) return 0;

    final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes();
    final content = utf8.decode(bytes);
    final List<List<dynamic>> csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (csv.isEmpty) return 0;

    final headers = csv.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String k) => headers.indexOf(k);
    final iName = idx('name');
    final iSku = idx('sku');
    final iCost = idx('cost');
    final iPrice = idx('price');
    final iStock = idx('stock');
    final iCategory = idx('category');

    final db = await AppDatabase().database;
    int inserted = 0;
    for (int r = 1; r < csv.length; r++) {
      final row = csv[r];
      if (row.isEmpty) continue;
      final name = (iName >= 0) ? row[iName].toString() : null;
      if (name == null || name.trim().isEmpty) continue;
      final sku = (iSku >= 0) ? (row[iSku]?.toString()) : null;
      final cost = (iCost >= 0) ? double.tryParse(row[iCost].toString()) ?? 0 : 0;
      final price = (iPrice >= 0) ? double.tryParse(row[iPrice].toString()) ?? 0 : 0;
      final stock = (iStock >= 0) ? int.tryParse(row[iStock].toString()) ?? 0 : 0;
      final category = (iCategory >= 0) ? (row[iCategory]?.toString()) : null;

      await db.insert('products', {
        'id': DateTime.now().microsecondsSinceEpoch.toString() + '_$r',
        'name': name.trim(),
        'sku': (sku == null || sku.trim().isEmpty) ? null : sku.trim(),
        'category': (category == null || category.trim().isEmpty) ? null : category.trim(),
        'cost': cost,
        'price': price,
        'stock': stock,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': null,
      });
      inserted++;
    }
    return inserted;
  }

  /// Importa clientes desde CSV. Encabezados esperados: name,phone,email
  static Future<int> importCustomersFromCsv() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (picked == null || picked.files.isEmpty) return 0;

    final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes();
    final content = utf8.decode(bytes);
    final List<List<dynamic>> csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (csv.isEmpty) return 0;

    final headers = csv.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String k) => headers.indexOf(k);
    final iName = idx('name');
    final iPhone = idx('phone');
    final iEmail = idx('email');

    final db = await AppDatabase().database;
    int inserted = 0;
    for (int r = 1; r < csv.length; r++) {
      final row = csv[r];
      if (row.isEmpty) continue;
      final name = (iName >= 0) ? row[iName].toString() : null;
      if (name == null || name.trim().isEmpty) continue;
      final phone = (iPhone >= 0) ? row[iPhone]?.toString() : null;
      final email = (iEmail >= 0) ? row[iEmail]?.toString() : null;

      await db.insert('customers', {
        'id': DateTime.now().microsecondsSinceEpoch.toString() + '_$r',
        'name': name.trim(),
        'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      inserted++;
    }
    return inserted;
  }
}
