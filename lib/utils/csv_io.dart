import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:popperscuv/db/db.dart';
import 'package:popperscuv/repositories/product_repository.dart';

class CsvIO {
  // ===== EXPORT =====
  static Future<String> exportTable(String table) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(table);
    final headers =
        rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
    final data = <List<dynamic>>[
      headers,
      ...rows.map((m) => headers.map((h) => m[h]).toList()),
    ];
    final csv = const ListToCsvConverter().convert(data);

    final dir = await getDatabasesPath();
    final outDir = p.join(dir, 'exports');
    await Directory(outDir).create(recursive: true);
    final path = p.join(
        outDir, '${table}_${DateTime.now().millisecondsSinceEpoch}.csv');
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  static Future<String> exportTableLocal(String table) => exportTable(table);
  static Future<String> exportTableToDownloads(String table) =>
      exportTable(table);

  // ===== IMPORTS =====

  /// Ajuste de inventarios: columnas (id o sku), delta, note(opcional)
  static Future<int> importInventoryAddsFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return 0;
    final csv = utf8.decode(bytes);
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csv, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;

    final headers = rows.first.map((e) => e.toString()).toList();
    int idx(String k) => headers.indexOf(k);

    final db = await AppDatabase.instance.database;
    int count = 0;

    await db.transaction((txn) async {
      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        final id = _cell(r, idx('id'));
        final sku = _cell(r, idx('sku'));
        final delta = _num(_cell(r, idx('delta')), 0).toInt();
        final note = _cell(r, idx('note')) ?? 'csv import';
        if (delta == 0) continue;

        String? productId = id;
        if ((productId == null || productId.isEmpty) &&
            sku != null &&
            sku.isNotEmpty) {
          final found = await txn.query('products',
              where: 'sku = ?', whereArgs: [sku], limit: 1);
          if (found.isNotEmpty) productId = found.first['id'] as String?;
        }
        if (productId == null || productId.isEmpty) continue;

        final cur = await txn.query('products',
            where: 'id = ?', whereArgs: [productId], limit: 1);
        if (cur.isEmpty) continue;

        final current = (cur.first['stock'] as int);
        final newStock = current + delta;

        await txn.update('products', {'stock': newStock, 'updated_at': nowIso()},
            where: 'id = ?', whereArgs: [productId]);

        await txn.insert('inventory_movements', {
          'id': genId(),
          'product_id': productId,
          'delta': delta,
          'note': note,
          'created_at': nowIso(),
        });
        count++;
      }
    });

    return count;
  }

  /// Upsert de productos. Columnas: id,name,sku,category,price,cost,stock
  static Future<int> importProductsUpsertFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return 0;
    final csv = utf8.decode(bytes);
    return importProductsFromCsvString(csv);
  }

  /// Compatibilidad: igual a upsert.
  static Future<int> importProductsFromCsv() => importProductsUpsertFromCsv();

  // ---- Helpers
  static Future<int> importProductsFromCsvString(String csv) async {
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csv, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    int idx(String k) => headers.indexOf(k);

    final repo = ProductRepository();
    int count = 0;

    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      await repo.upsertProduct({
        'id': _cell(r, idx('id')),
        'name': _cell(r, idx('name')) ?? '',
        'sku': _cell(r, idx('sku')),
        'category': _cell(r, idx('category')),
        'price': _num(_cell(r, idx('price')), 0).toDouble(),
        'cost': _num(_cell(r, idx('cost')), 0).toDouble(),
        'stock': _num(_cell(r, idx('stock')), 0).toInt(),
      });
      count++;
    }
    return count;
  }

  static Future<Uint8List?> _pickCsvBytes() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    return res.files.single.bytes;
  }

  static String? _cell(List row, int index) =>
      (index >= 0 && index < row.length) ? row[index]?.toString() : null;

  static num _num(String? s, num fallback) {
    if (s == null) return fallback;
    return num.tryParse(s.trim().replaceAll(',', '')) ?? fallback;
  }
}
