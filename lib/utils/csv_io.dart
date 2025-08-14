import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/db/db.dart';

class CsvIO {
  static Future<String> exportTableLocal(String table) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(table);
    final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
    final data = <List<dynamic>>[
      headers,
      ...rows.map((m) => headers.map((h) => m[h]).toList()),
    ];
    final csv = const ListToCsvConverter().convert(data);
    final dir = await getDatabasesPath(); // carpeta segura disponible
    final path = '$dir/$table.csv';
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  static Future<String> exportTableToDownloads(String table) =>
      exportTableLocal(table);

  /// Importa productos desde CSV (encabezados: id,name,sku,category,price,cost,stock)
  static Future<int> importProductsFromCsvString(String csv) async {
    final db = await AppDatabase.instance.database;
    final rows = const CsvToListConverter(eol: '\n').convert(csv, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    final idx = (String k) => headers.indexOf(k);
    int count = 0;
    await db.transaction((txn) async {
      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        final map = {
          'id': _cell(r, idx('id')),
          'name': _cell(r, idx('name')),
          'sku': _cell(r, idx('sku')),
          'category': _cell(r, idx('category')),
          'price': _num(_cell(r, idx('price')), 0).toDouble(),
          'cost': _num(_cell(r, idx('cost')), 0).toDouble(),
          'stock': _num(_cell(r, idx('stock')), 0).toInt(),
          'created_at': nowIso(),
          'updated_at': nowIso(),
        };
        await txn.insert('products', map, conflictAlgorithm: ConflictAlgorithm.replace);
        count++;
      }
    });
    return count;
  }

  /// Importa clientes desde CSV (encabezados: id,name,phone,notes)
  static Future<int> importCustomersFromCsvString(String csv) async {
    final db = await AppDatabase.instance.database;
    final rows = const CsvToListConverter(eol: '\n').convert(csv, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    final idx = (String k) => headers.indexOf(k);
    int count = 0;
    await db.transaction((txn) async {
      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        final id = _cell(r, idx('id'));
        final phone = _cell(r, idx('phone'));
        final map = {
          'id': (id?.isNotEmpty ?? false) ? id : (phone?.isNotEmpty ?? false) ? phone : genId(),
          'name': _cell(r, idx('name')),
          'phone': phone,
          'notes': _cell(r, idx('notes')),
          'created_at': nowIso(),
          'updated_at': nowIso(),
        };
        await txn.insert('customers', map, conflictAlgorithm: ConflictAlgorithm.replace);
        count++;
      }
    });
    return count;
  }

  static String? _cell(List row, int index) =>
      (index >= 0 && index < row.length) ? (row[index]?.toString()) : null;

  static num _num(String? s, num fallback) {
    if (s == null) return fallback;
    return num.tryParse(s.trim().replaceAll(',', '')) ?? fallback;
    }
}