
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class CsvIO {
  static Future<String> exportTable(String table) async {
    final db = await AppDatabase().database;
    final rows = await db.query(table);
    if (rows.isEmpty) {
      final List<String> headers = <String>[];
      final csv = const ListToCsvConverter().convert(<List<dynamic>>[headers]);
      return await _saveCsvBytes(csv, 'export_${table}.csv');
    }
    final List<String> headers = rows.first.keys.toList();
    final List<List<dynamic>> data = <List<List<dynamic>>>[
      headers,
      ...rows.map((m) => headers.map((h) => m[h]).toList()).toList(),
    ];
    final csv = const ListToCsvConverter().convert(data);
    return await _saveCsvBytes(csv, 'export_${table}.csv');
  }

  static Future<String> _saveCsvBytes(String csv, String filename) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    // Intento 1: API nueva con named params (dinámico para evitar error de compilación si cambia la firma)
    try {
      final dynamic saver = FileSaver.instance;
      final dynamic res = await saver.saveAs(name: filename, bytes: bytes, ext: 'csv', mimeType: MimeType.text);
      return res as String;
    } catch (_) {
      try {
        final dynamic saver = FileSaver.instance;
        final dynamic res = await saver.saveFile(name: filename, bytes: bytes, ext: 'csv', mimeType: MimeType.text);
        return res as String;
      } catch (_) {
        // Fallback: Documents directory
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
    }
  }

  /// Espera encabezados para products: name,sku,cost,price,stock,category
  static Future<int> importProductsFromCsv() async {
    final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (file == null || file.files.isEmpty) return 0;
    final bytes = file.files.single.bytes ?? await File(file.files.single.path!).readAsBytes();
    final csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(utf8.decode(bytes));
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

  /// Espera encabezados para customers: name,phone,email
  static Future<int> importCustomersFromCsv() async {
    final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (file == null || file.files.isEmpty) return 0;
    final bytes = file.files.single.bytes ?? await File(file.files.single.path!).readAsBytes();
    final csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(utf8.decode(bytes));
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
