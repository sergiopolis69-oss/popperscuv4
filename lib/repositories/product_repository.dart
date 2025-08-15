// lib/repositories/product_repository.dart
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/utils/db.dart';
import 'package:popperscuv/utils/helpers.dart';

// Helpers locales (por si tu db.dart no los expone)
String nowIso() => DateTime.now().toIso8601String();
String genId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(100000)}';

class ProductRepository {
  // Acceso a la BD usando tu singleton en utils/db.dart
  Future<Database> get _db async => AppDatabase.instance.database;

  /// Lista todos los productos
  Future<List<Map<String, Object?>>> all({String orderBy = 'LOWER(name) ASC'}) async {
    final db = await _db;
    return db.query('products', orderBy: orderBy);
  }

  /// Lista filtrada por texto (nombre o SKU) y/o categoría
  Future<List<Map<String, Object?>>> listFiltered({
    String? q,
    String? category,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (q != null && q.trim().isNotEmpty) {
      final like = '%${q.trim()}%';
      where.add('(LOWER(name) LIKE LOWER(?) OR LOWER(sku) LIKE LOWER(?))');
      args.addAll([like, like]);
    }

    if (category != null && category.trim().isNotEmpty) {
      where.add('category = ?');
      args.add(category.trim());
    }

    return db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'LOWER(name) ASC',
    );
  }

  /// Inserta o actualiza un producto
  ///
  /// Campos esperados en [data]: id?, name, sku, category, price, cost, stock
  Future<String> upsertProduct(Map<String, Object?> data) async {
    final db = await _db;

    final providedId = data['id']?.toString();
    final id = (providedId != null && providedId.isNotEmpty) ? providedId : genId();

    final now = nowIso();

    double? _toDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int? _toInt(Object? v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

    final row = <String, Object?>{
      'id': id,
      'name': data['name']?.toString().trim(),
      'sku': data['sku']?.toString().trim(),
      'category': data['category']?.toString().trim(),
      'price': _toDouble(data['price']) ?? 0.0,
      'cost': _toDouble(data['cost']) ?? 0.0,
      'stock': _toInt(data['stock']) ?? 0,
      'created_at': data['created_at'] ?? now,
      'updated_at': now,
    };

    await db.insert(
      'products',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  /// Borra producto por id
  Future<int> deleteById(String id) async {
    final db = await _db;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Devuelve categorías distintas (no nulas ni vacías)
  Future<List<String>> categoriesDistinct() async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND TRIM(category) <> '' ORDER BY LOWER(category) ASC",
    );
    return rows
        .map((m) => (m['category'] ?? '').toString())
        .where((c) => c.trim().isNotEmpty)
        .toList();
  }

  /// Ajusta stock e inserta movimiento de inventario
  ///
  /// [delta]: cantidad a sumar (puede ser negativa).
  /// [reason]: motivo (ej. 'csv import', 'venta', 'ajuste manual').
  /// Si provees [txn], opera dentro de esa transacción; si no, crea una nueva.
  Future<void> adjustStock(
    String productId,
    int delta, {
    String? reason,
    Transaction? txn,
  }) async {
    final run = (Transaction t) async {
      final cur = await t.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final currentStock = cur.isNotEmpty ? (cur.first['stock'] as int? ?? 0) : 0;
      final newStock = currentStock + delta;

      await t.update(
        'products',
        {'stock': newStock, 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await t.insert('inventory_movements', {
        'id': genId(),
        'product_id': productId,
        'delta': delta,
        'reason': (reason ?? 'ajuste').toString(),
        'created_at': nowIso(),
      });
    };

    if (txn != null) {
      await run(txn);
    } else {
      final db = await _db;
      await db.transaction(run);
    }
  }
}