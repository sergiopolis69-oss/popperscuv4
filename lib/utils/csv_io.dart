
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

  /// Importa productos NUEVOS desde CSV. Encabezados esperados: name,sku,cost,price,stock,category
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

  /// IMPORT MASIVO tipo UPSERT por SKU o ID. Si existe, actualiza; si no, inserta.
  /// Encabezados soportados: id, sku, name, cost, price, stock, category
  /// - Si incluye 'stock', se establece el stock a ese valor (no suma).
  static Future<int> importProductsUpsertFromCsv() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (picked == null || picked.files.isEmpty) return 0;

    final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes();
    final content = utf8.decode(bytes);
    final List<List<dynamic>> csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (csv.isEmpty) return 0;

    final headers = csv.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String k) => headers.indexOf(k);
    final iId = idx('id');
    final iSku = idx('sku');
    final iName = idx('name');
    final iCost = idx('cost');
    final iPrice = idx('price');
    final iStock = idx('stock');
    final iCategory = idx('category');

    final db = await AppDatabase().database;
    int affected = 0;
    for (int r = 1; r < csv.length; r++) {
      final row = csv[r];
      if (row.isEmpty) continue;

      final id = (iId >= 0) ? row[iId]?.toString().trim() : null;
      final sku = (iSku >= 0) ? row[iSku]?.toString().trim() : null;
      final name = (iName >= 0) ? row[iName]?.toString().trim() : null;
      final cost = (iCost >= 0) ? double.tryParse(row[iCost].toString()) : null;
      final price = (iPrice >= 0) ? double.tryParse(row[iPrice].toString()) : null;
      final stock = (iStock >= 0) ? int.tryParse(row[iStock].toString()) : null;
      final category = (iCategory >= 0) ? row[iCategory]?.toString().trim() : null;

      // Buscar producto existente
      Map<String, Object?>? existing;
      if ((id != null && id.isNotEmpty)) {
        final q = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
        if (q.isNotEmpty) existing = q.first;
      }
      if (existing == null && (sku != null && sku.isNotEmpty)) {
        final q = await db.query('products', where: 'sku = ?', whereArgs: [sku], limit: 1);
        if (q.isNotEmpty) existing = q.first;
      }

      if (existing != null) {
        // UPDATE
        final update = <String, Object?>{};
        if (name != null && name.isNotEmpty) update['name'] = name;
        if (sku != null && sku.isNotEmpty) update['sku'] = sku;
        if (category != null && category.isNotEmpty) update['category'] = category;
        if (cost != null) update['cost'] = cost;
        if (price != null) update['price'] = price;
        if (stock != null) update['stock'] = stock;
        update['updated_at'] = DateTime.now().toIso8601String();
        await db.update('products', update, where: 'id = ?', whereArgs: [existing['id']]);
        affected++;
      } else {
        // INSERT (requiere como mínimo name)
        if (name == null || name.isEmpty) continue;
        await db.insert('products', {
          'id': DateTime.now().microsecondsSinceEpoch.toString() + '_$r',
          'name': name,
          'sku': (sku == null || sku.isEmpty) ? null : sku,
          'category': (category == null || category.isEmpty) ? null : category,
          'cost': cost ?? 0,
          'price': price ?? 0,
          'stock': stock ?? 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': null,
        });
        affected++;
      }
    }
    return affected;
  }

  /// AGREGA AL INVENTARIO por CSV (suma al stock). Soporta SKU o ID.
  /// Encabezados mínimos: sku|id, quantity
  /// Opcionales: cost, price, name, category
  /// - Si el producto existe: stock += quantity; actualiza cost/price si vienen.
  /// - Si NO existe y hay 'name': crea el producto con ese stock inicial.
  /// Devuelve el número de filas afectadas (sumas + inserciones).
  static Future<int> importInventoryAddsFromCsv() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (picked == null || picked.files.isEmpty) return 0;

    final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes();
    final content = utf8.decode(bytes);
    final List<List<dynamic>> csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (csv.isEmpty) return 0;

    final headers = csv.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String k) => headers.indexOf(k);
    final iId = idx('id');
    final iSku = idx('sku');
    final iQty = idx('quantity');
    final iName = idx('name');
    final iCost = idx('cost');
    final iPrice = idx('price');
    final iCategory = idx('category');

    if (iQty < 0 || (iId < 0 && iSku < 0)) {
      // Formato mínimo no cumple
      return 0;
    }

    final db = await AppDatabase().database;
    int affected = 0;

    await db.transaction((txn) async {
      for (int r = 1; r < csv.length; r++) {
        final row = csv[r];
        if (row.isEmpty) continue;

        final id = (iId >= 0) ? row[iId]?.toString().trim() : null;
        final sku = (iSku >= 0) ? row[iSku]?.toString().trim() : null;
        final qty = int.tryParse(row[iQty].toString()) ?? 0;
        if (qty == 0) continue;

        final name = (iName >= 0) ? row[iName]?.toString().trim() : null;
        final cost = (iCost >= 0) ? double.tryParse(row[iCost].toString()) : null;
        final price = (iPrice >= 0) ? double.tryParse(row[iPrice].toString()) : null;
        final category = (iCategory >= 0) ? row[iCategory]?.toString().trim() : null;

        // Buscar producto
        Map<String, Object?>? existing;
        if (id != null && id.isNotEmpty) {
          final q = await txn.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
          if (q.isNotEmpty) existing = q.first;
        }
        if (existing == null && sku != null && sku.isNotEmpty) {
          final q = await txn.query('products', where: 'sku = ?', whereArgs: [sku], limit: 1);
          if (q.isNotEmpty) existing = q.first;
        }

        if (existing != null) {
          final newStock = (existing['stock'] as int) + qty;
          final update = <String, Object?>{
            'stock': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (cost != null) update['cost'] = cost;
          if (price != null) update['price'] = price;
          if (category != null && category.isNotEmpty) update['category'] = category;

          await txn.update('products', update, where: 'id = ?', whereArgs: [existing['id']]);

          await txn.insert('inventory_movements', {
            'id': DateTime.now().microsecondsSinceEpoch.toString() + '_$r',
            'product_id': existing['id'],
            'delta': qty,
            'reason': 'csv_import_add',
            'created_at': DateTime.now().toIso8601String(),
          });
          affected++;
        } else if (name != null && name.isNotEmpty) {
          // Crear producto nuevo
          final newId = DateTime.now().microsecondsSinceEpoch.toString() + '_$r';
          await txn.insert('products', {
            'id': newId,
            'name': name,
            'sku': (sku == null || sku.isEmpty) ? null : sku,
            'category': (category == null || category.isEmpty) ? null : category,
            'cost': cost ?? 0,
            'price': price ?? 0,
            'stock': qty,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': null,
          });

          await txn.insert('inventory_movements', {
            'id': DateTime.now().microsecondsSinceEpoch.toString() + '_$r',
            'product_id': newId,
            'delta': qty,
            'reason': 'csv_import_add_new',
            'created_at': DateTime.now().toIso8601String(),
          });
          affected++;
        } else {
          // No se pudo resolver producto y no hay nombre -> se omite
          continue;
        }
      }
    });

    return affected;
  }
}
