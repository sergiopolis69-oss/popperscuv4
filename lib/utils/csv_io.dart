import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/db.dart';
import '../utils/misc.dart';

class CsvIO {
  static String _s(dynamic v) => (v ?? '').toString().trim();
  static double _d(dynamic v) => toDouble(v);
  static int _i(dynamic v) => toInt(v);

  static Future<Uint8List?> _pickCsvBytes() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    return res?.files.single.bytes;
  }

  static List<List<dynamic>> _parseCsv(Uint8List bytes) {
    final csv = String.fromCharCodes(bytes);
    return const CsvToListConverter(eol: '\n').convert(csv);
  }

  static Map<String, int> _headerMap(List<dynamic> headerRow) {
    final map = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      map[_s(headerRow[i]).toLowerCase()] = i;
    }
    return map;
  }

  static dynamic _cell(List<dynamic> row, Map<String, int> h, String key) {
    final idx = h[key];
    if (idx == null || idx >= row.length) return null;
    return row[idx];
  }

  // ---------- EXPORT ----------
  static Future<String?> exportTable(String table, {String? fileName}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(table);
    if (rows.isEmpty) {
      final docs = await getApplicationDocumentsDirectory();
      final path = p.join(docs.path, (fileName ?? '$table.csv'));
      final headers = <String>[];
      if (table == 'products') {
        headers.addAll(['id','sku','name','price','cost','stock','category','created_at','updated_at']);
      } else if (table == 'customers') {
        headers.addAll(['id','name','phone','created_at','updated_at']);
      } else if (table == 'sales') {
        headers.addAll(['id','customer_id','total','discount','shipping_cost','profit','payment_method','created_at']);
      }
      final csv = const ListToCsvConverter().convert([headers]);
      await File(path).writeAsString(csv, flush: true);
      return path;
    }

    final headers = rows.first.keys.toList();
    final data = <List<dynamic>>[headers];
    for (final r in rows) {
      data.add(headers.map((h) => r[h]).toList());
    }

    final csv = const ListToCsvConverter().convert(data);
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, (fileName ?? '$table.csv'));
    await File(path).writeAsString(csv, flush: true);
    return path;
  }

  // ---------- IMPORT: UPSERT PRODUCTS ----------
  static Future<Map<String, int>> importProductsUpsertFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return {'inserted': 0, 'updated': 0, 'skipped': 0, 'errors': 0};

    final table = _parseCsv(bytes);
    if (table.isEmpty) return {'inserted': 0, 'updated': 0, 'skipped': 0, 'errors': 0};

    final h = _headerMap(table.first);
    final db = await AppDatabase.instance.database;

    int inserted = 0, updated = 0, skipped = 0, errors = 0;

    await db.transaction((txn) async {
      for (var r = 1; r < table.length; r++) {
        try {
          final row = table[r];
          final sku = _s(_cell(row, h, 'sku'));
          if (sku.isEmpty) { skipped++; continue; }

          final name     = _s(_cell(row, h, 'name'));
          final priceTxt = _s(_cell(row, h, 'price'));
          final costTxt  = _s(_cell(row, h, 'cost'));
          final price    = _d(priceTxt);
          final cost     = _d(costTxt);
          final stockAbs = _s(_cell(row, h, 'stock'));
          final qtyDelta = _s(_cell(row, h, 'qty'));
          final category = _s(_cell(row, h, 'category'));

          final found = await txn.query('products', where: 'sku = ?', whereArgs: [sku], limit: 1);
          if (found.isNotEmpty) {
            final id = found.first['id']?.toString();
            final patch = <String, Object?>{'updated_at': nowIso()};
            if (name.isNotEmpty) patch['name'] = name;
            if (priceTxt.isNotEmpty) patch['price'] = price;
            if (costTxt.isNotEmpty)  patch['cost']  = cost;
            if (category.isNotEmpty) patch['category'] = category;

            if (stockAbs.isNotEmpty) {
              patch['stock'] = _i(stockAbs);
            } else if (qtyDelta.isNotEmpty) {
              final current = (found.first['stock'] as num?)?.toInt() ?? 0;
              patch['stock'] = current + _i(qtyDelta);
            }

            if (patch.length > 1) {
              await txn.update('products', patch, where: 'id = ?', whereArgs: [id]);
              updated++;
            } else {
              skipped++;
            }
          } else {
            final hasAny = name.isNotEmpty || priceTxt.isNotEmpty || costTxt.isNotEmpty;
            if (!hasAny) { skipped++; continue; }

            final initialStock = stockAbs.isNotEmpty
                ? _i(stockAbs)
                : qtyDelta.isNotEmpty ? _i(qtyDelta) : 0;

            await txn.insert('products', {
              'id'        : genId(),
              'sku'       : sku,
              'name'      : name.isNotEmpty ? name : null,
              'price'     : price,
              'cost'      : cost,
              'stock'     : initialStock,
              'category'  : category.isNotEmpty ? category : null,
              'created_at': nowIso(),
              'updated_at': nowIso(),
            }, conflictAlgorithm: ConflictAlgorithm.abort);
            inserted++;
          }
        } catch (_) {
          errors++;
        }
      }
    });

    return {'inserted': inserted, 'updated': updated, 'skipped': skipped, 'errors': errors};
  }

  // ---------- IMPORT: AJUSTES (delta por qty) ----------
  static Future<Map<String, int>> importInventoryAddsFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return {'changed': 0, 'missing': 0, 'errors': 0};

    final table = _parseCsv(bytes);
    if (table.isEmpty) return {'changed': 0, 'missing': 0, 'errors': 0};

    final h = _headerMap(table.first);
    final db = await AppDatabase.instance.database;

    int changed = 0, missing = 0, errors = 0;

    String qtyKey = 'qty';
    for (final k in ['qty', 'cantidad', 'ajuste', 'delta', 'stock']) {
      if (h.containsKey(k)) { qtyKey = k; break; }
    }

    await db.transaction((txn) async {
      for (var r = 1; r < table.length; r++) {
        try {
          final row = table[r];
          final sku = _s(_cell(row, h, 'sku'));
          final delta = _i(_cell(row, h, qtyKey));
          if (sku.isEmpty || delta == 0) { missing++; continue; }

          final found = await txn.query('products', where: 'sku = ?', whereArgs: [sku], limit: 1);
          if (found.isEmpty) { missing++; continue; }

          final current = (found.first['stock'] as num?)?.toInt() ?? 0;
          final newStock = current + delta;
          await txn.update('products', {'stock': newStock, 'updated_at': nowIso()}, where: 'sku = ?', whereArgs: [sku]);
          changed++;
        } catch (_) {
          errors++;
        }
      }
    });

    return {'changed': changed, 'missing': missing, 'errors': errors};
  }

  // ---------- COMPAT: importProductsFromCsv (usado por reports_page.dart) ----------
  /// Devuelve cuántos registros fueron insertados/actualizados.
  static Future<int> importProductsFromCsv() async {
    final m = await importProductsUpsertFromCsv();
    return (m['inserted'] ?? 0) + (m['updated'] ?? 0);
  }
}