import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:popperscuv/db/app_database.dart';
import 'package:popperscuv/repositories/product_repository.dart';

/// Helpers por si tu proyecto no los expone globalmente.
/// Si ya tienes nowIso() / genId() globales, puedes borrar estas dos funciones.
String nowIso() => DateTime.now().toIso8601String();
String genId() => DateTime.now().microsecondsSinceEpoch.toString();

class CsvIO {
  // ========================= EXPORTS =========================

  static Future<String> exportTable(String table) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(table);
    final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];

    final data = <List<dynamic>>[
      headers,
      ...rows.map((m) => headers.map((h) => m[h]).toList()),
    ];
    final csv = const ListToCsvConverter().convert(data);

    final dir = await _exportsDir();
    final path =
        p.join(dir.path, '${table}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await File(path).writeAsString(csv);
    // ignore: avoid_print
    print('CSV exportado: $path');
    return path;
  }

  static Future<String> exportTableLocal(String table) => exportTable(table);
  static Future<String> exportTableToDownloads(String table) => exportTable(table);

  /// Ruta exacta que se usa para exportar.
  static Future<String> whereAreExports() async => (await _exportsDir()).path;

  /// Lista de CSVs exportados, más recientes primero.
  static Future<List<String>> listExportedFiles() async {
    final d = await _exportsDir();
    final files = d
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.csv'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.map((f) => f.path).toList();
  }

  // ========================= IMPORTS =========================

  /// Ajuste de inventario desde CSV.
  ///
  /// Acepta encabezados (case-insensitive) con sinónimos:
  /// id: [id, product_id, codigo_interno]
  /// sku: [sku, code, codigo]
  /// delta: [delta, qty, cantidad, ajuste]
  /// stock absoluto: [stock, existencias]
  /// note: [note, nota, comment, comentario]
  ///
  /// Reglas:
  /// - Si hay 'stock', se ajusta a ese valor absoluto (delta = stock - actual).
  /// - Si no hay 'stock' pero hay 'delta', se suma ese delta al stock actual.
  /// - Si no se resuelve 'id' ni 'sku', la fila se omite.
  static Future<int> importInventoryAddsFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return 0;

    final csv = utf8.decode(bytes);
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csv, shouldParseNumbers: false);

    if (rows.isEmpty) return 0;

    // ---------- Mapeo flexible de encabezados ----------
    final headers = rows.first.map((e) => (e?.toString() ?? '').trim()).toList();
    int idxOf(Set<String> names) {
      final lower = headers.map((h) => h.toLowerCase()).toList();
      for (var i = 0; i < lower.length; i++) {
        if (names.contains(lower[i])) return i;
      }
      return -1;
    }

    final idIdx = idxOf({'id', 'product_id', 'codigo_interno'});
    final skuIdx = idxOf({'sku', 'code', 'codigo'});
    final deltaIdx = idxOf({'delta', 'qty', 'cantidad', 'ajuste'});
    final stockIdx = idxOf({'stock', 'existencias'});
    final noteIdx = idxOf({'note', 'nota', 'comment', 'comentario'});

    final db = await AppDatabase.instance.database;

    int applied = 0;
    await db.transaction((txn) async {
      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];

        String? id =
            (idIdx >= 0 && idIdx < r.length) ? _str(r[idIdx]) : null;
        String? sku =
            (skuIdx >= 0 && skuIdx < r.length) ? _str(r[skuIdx]) : null;
        final note =
            (noteIdx >= 0 && noteIdx < r.length) ? _str(r[noteIdx]) : null;

        // Resolver productId por id o por sku
        String? productId = id;
        if ((productId == null || productId.isEmpty) &&
            sku != null &&
            sku.isNotEmpty) {
          final found = await txn.query('products',
              where: 'sku = ?', whereArgs: [sku], limit: 1);
          if (found.isNotEmpty) productId = found.first['id'] as String?;
        }
        if (productId == null || productId.isEmpty) {
          // Fila no usable
          continue;
        }

        // Leer stock actual
        final cur = await txn.query('products',
            where: 'id = ?', whereArgs: [productId], limit: 1);
        if (cur.isEmpty) continue;

        final current =
            (cur.first['stock'] is int) ? cur.first['stock'] as int : int.tryParse(cur.first['stock'].toString()) ?? 0;

        // Calcular nuevoStock vía stock absoluto o vía delta
        int? stockAbs;
        if (stockIdx >= 0 && stockIdx < r.length) {
          stockAbs = _toInt(r[stockIdx]);
        }

        int delta = 0;
        if (stockAbs != null) {
          delta = stockAbs - current; // ajustar a valor absoluto
        } else if (deltaIdx >= 0 && deltaIdx < r.length) {
          delta = _toInt(r[deltaIdx]) ?? 0;
        }

        if (delta == 0) {
          // Nada que hacer
          continue;
        }

        final newStock = current + delta;

        await txn.update('products', {'stock': newStock, 'updated_at': nowIso()},
            where: 'id = ?', whereArgs: [productId]);

        await txn.insert('inventory_movements', {
          'id': genId(),
          'product_id': productId,
          'delta': delta,
          'note': note ?? 'csv import',
          'created_at': nowIso(),
        });

        applied++;
      }
    });

    // ignore: avoid_print
    print('CSV inventario aplicado en $applied renglones.');
    return applied;
  }

  /// Upsert de productos. Columnas: id,name,sku,category,price,cost,stock
  static Future<int> importProductsUpsertFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return 0;
    final csv = utf8.decode(bytes);
    return importProductsFromCsvString(csv);
  }

  static Future<int> importProductsFromCsv() => importProductsUpsertFromCsv();

  static Future<int> importProductsFromCsvString(String csv) async {
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csv, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;

    final headers = rows.first.map((e) => (e?.toString() ?? '').trim()).toList();
    int idx(String k) => headers.map((h) => h.toLowerCase()).toList().indexOf(k.toLowerCase());

    final repo = ProductRepository();
    int count = 0;

    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      await repo.upsertProduct({
        'id': _strAt(r, idx('id')),
        'name': _strAt(r, idx('name')) ?? '',
        'sku': _strAt(r, idx('sku')),
        'category': _strAt(r, idx('category')),
        'price': _numAt(r, idx('price'), 0).toDouble(),
        'cost': _numAt(r, idx('cost'), 0).toDouble(),
        'stock': _numAt(r, idx('stock'), 0).toInt(),
      });
      count++;
    }
    return count;
  }

  // ========================= HELPERS =========================

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

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _strAt(List row, int index) =>
      (index >= 0 && index < row.length) ? _str(row[index]) : null;

  static num _numAt(List row, int index, num fallback) {
    if (index < 0 || index >= row.length) return fallback;
    return _toNum(row[index]) ?? fallback;
  }

  static int? _toInt(dynamic v) {
    final n = _toNum(v);
    return n?.round();
  }

  static num? _toNum(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }

  static Future<Directory> _exportsDir() async {
    final ext = await getExternalStorageDirectory(); // Android: .../Android/data/<pkg>/files
    if (ext != null) {
      final d = Directory(p.join(ext.path, 'exports'));
      await d.create(recursive: true);
      return d;
    }
    final dbDir = await getDatabasesPath();
    final d = Directory(p.join(dbDir, 'exports'));
    await d.create(recursive: true);
    return d;
  }
}