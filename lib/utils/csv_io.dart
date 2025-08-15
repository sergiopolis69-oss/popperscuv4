import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:popperscuv/utils/db.dart';
import 'package:popperscuv/utils/helpers.dart';
import 'package:popperscuv/repositories/product_repository.dart';

class CsvIO {
  /// Exporta una tabla completa a CSV en la carpeta de documentos de la app.
  /// Retorna la ruta del archivo.
  static Future<String> exportTable(String table) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(table);
    if (rows.isEmpty) {
      final outPath = await _writeToAppDocs(
        '${table}_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv',
        const ListToCsvConverter().convert(<List<dynamic>>[]),
      );
      return outPath;
    }

    // encabezados en el orden de las claves del primer row
    final headers = rows.first.keys.toList();
    final data = <List<dynamic>>[
      headers,
      ...rows.map((r) => headers.map((h) => r[h]).toList()),
    ];

    final csv = const ListToCsvConverter().convert(data);
    final outPath = await _writeToAppDocs(
      '${table}_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv',
      csv,
    );
    return outPath;
  }

  /// Importa productos (insert o replace) desde CSV.
  /// Columnas soportadas: id, name, sku, category, price, cost, stock
  /// Retorna cuántos registros procesó.
  static Future<int> importProductsFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return 0;

    final lines = const Utf8Decoder().convert(bytes).split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return 0;

    final parsed = const CsvToListConverter(eol: '\n').convert(lines.join('\n'), shouldParseNumbers: false);
    if (parsed.isEmpty) return 0;

    final headers = parsed.first.map((e) => e.toString().trim()).toList();
    final idx = Map.fromEntries(headers.asMap().entries.map((e) => MapEntry(e.value.toLowerCase(), e.key)));

    int count = 0;
    final repo = ProductRepository();

    for (int i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      if (row.isEmpty) continue;

      String? id       = _get(row, idx, 'id');
      final name       = _get(row, idx, 'name');
      final sku        = _get(row, idx, 'sku');
      final category   = _get(row, idx, 'category');
      final price      = _getDouble(row, idx, 'price');
      final cost       = _getDouble(row, idx, 'cost');
      final stock      = _getInt(row, idx, 'stock');

      if ((name == null || name.isEmpty) && (sku == null || sku.isEmpty)) {
        continue; // necesita al menos name o sku
      }
      id = (id != null && id.isNotEmpty) ? id : genId();

      await repo.upsertProduct({
        'id': id,
        'name': name ?? sku,
        'sku': sku,
        'category': category,
        'price': price ?? 0.0,
        'cost': cost ?? 0.0,
        'stock': stock ?? 0,
      });
      count++;
    }
    return count;
  }

  /// Importa (upsert) productos desde CSV — alias más explícito.
  static Future<int> importProductsUpsertFromCsv() => importProductsFromCsv();

  /// Importa movimientos de inventario (suma stock) desde CSV.
  /// Columnas esperadas: product_id (o sku), delta, reason
  /// Si no trae product_id pero sí sku, buscará el id por sku.
  static Future<int> importInventoryAddsFromCsv() async {
    final bytes = await _pickCsvBytes();
    if (bytes == null) return 0;

    final rows = const CsvToListConverter(eol: '\n').convert(const Utf8Decoder().convert(bytes), shouldParseNumbers: false);
    if (rows.isEmpty) return 0;

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final idx = Map.fromEntries(headers.asMap().entries.map((e) => MapEntry(e.value.toLowerCase(), e.key)));

    final repo = ProductRepository();
    final db = await AppDatabase.instance.database;

    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;

      String? productId = _get(r, idx, 'product_id');
      final sku = _get(r, idx, 'sku');
      final delta = _getInt(r, idx, 'delta') ?? 0;
      final reason = _get(r, idx, 'reason') ?? 'csv_import';

      if ((productId == null || productId.isEmpty) && (sku != null && sku.isNotEmpty)) {
        final found = await db.query('products', columns: ['id'], where: 'LOWER(COALESCE(sku,"")) = LOWER(?)', whereArgs: [sku], limit: 1);
        if (found.isNotEmpty) productId = found.first['id']?.toString();
      }

      if (productId == null || productId.isEmpty) continue;
      if (delta == 0) continue;

      await repo.adjustStock(productId, delta, reason: reason);
      count++;
    }

    return count;
  }

  // ---------- helpers CSV ----------
  static String? _get(List<dynamic> row, Map<String, int> idx, String col) {
    final i = idx[col.toLowerCase()];
    if (i == null || i >= row.length) return null;
    final v = row[i];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
    }

  static double? _getDouble(List<dynamic> row, Map<String, int> idx, String col) {
    final s = _get(row, idx, col);
    return s == null ? null : double.tryParse(s);
  }

  static int? _getInt(List<dynamic> row, Map<String, int> idx, String col) {
    final s = _get(row, idx, col);
    return s == null ? null : int.tryParse(s);
  }

  static Future<Uint8List?> _pickCsvBytes() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final f = res?.files.first;
    return f?.bytes;
  }

  static Future<String> _writeToAppDocs(String filename, String csv) async {
    final dir = await getApplicationDocumentsDirectory();
    final outPath = p.join(dir.path, filename);
    final file = File(outPath);
    await file.writeAsString(csv, flush: true);
    return outPath;
  }
}