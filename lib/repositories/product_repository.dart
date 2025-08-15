import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/utils/db.dart';
import 'package:popperscuv/utils/helpers.dart';

class ProductRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Map<String, Object?>>> all() async {
    final db = await _db;
    return db.query('products', orderBy: 'LOWER(name)');
  }

  Future<List<Map<String, Object?>>> listFiltered({
    String? category,
    String? q,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (category != null && category.trim().isNotEmpty) {
      where.add('LOWER(COALESCE(category,"")) = LOWER(?)');
      args.add(category.trim());
    }
    if (q != null && q.trim().isNotEmpty) {
      where.add('(LOWER(COALESCE(name,"")) LIKE LOWER(?) OR LOWER(COALESCE(sku,"")) LIKE LOWER(?))');
      args.add('%${q.trim()}%');
      args.add('%${q.trim()}%');
    }

    return db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'LOWER(name)',
    );
  }

  Future<List<String>> categoriesDistinct() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT COALESCE(category,"") AS category FROM products WHERE COALESCE(category,"") <> "" ORDER BY LOWER(category)'
    );
    return rows.map((e) => (e['category'] ?? '').toString()).toList();
  }

  Future<void> deleteById(String id) async {
    final db = await _db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Versión por mapa (compatibilidad con pantallas existentes)
  Future<void> upsertProduct(Map<String, Object?> data) async {
    final db = await _db;
    final id = (data['id']?.toString().trim().isNotEmpty ?? false)
        ? data['id']!.toString()
        : genId();
    final now = nowIso();

    final row = <String, Object?>{
      'id': id,
      'name': data['name']?.toString(),
      'sku': data['sku']?.toString(),
      'category': data['category']?.toString(),
      'price': (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse('${data['price']}') ?? 0.0,
      'cost': (data['cost'] is num) ? (data['cost'] as num).toDouble() : double.tryParse('${data['cost']}') ?? 0.0,
      'stock': (data['stock'] is num) ? (data['stock'] as num).toInt() : int.tryParse('${data['stock']}') ?? 0,
      'updated_at': now,
    };

    // created_at solo si insert
    final exists = await db.query('products', columns: ['id'], where: 'id=?', whereArgs: [id], limit: 1);
    if (exists.isEmpty) row['created_at'] = now;

    await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Versión con parámetros nombrados (alias usado por algunas UIs)
  Future<void> upsertProductNamed({
    String? id,
    required String name,
    String? sku,
    String? category,
    required double price,
    required double cost,
    int stock = 0,
  }) async {
    await upsertProduct({
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
    });
  }

  Future<Map<String, Object?>> findById(String id) async {
    final db = await _db;
    final rows = await db.query('products', where: 'id=?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? <String, Object?>{} : rows.first;
  }

  Future<void> adjustStock(String productId, int delta, {String reason = 'import'}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final curRows = await txn.query('products', columns: ['stock'], where: 'id=?', whereArgs: [productId], limit: 1);
      final cur = curRows.isEmpty ? 0 : (curRows.first['stock'] as num?)?.toInt() ?? 0;
      final newStock = cur + delta;
      await txn.update(
        'products',
        {'stock': newStock, 'updated_at': nowIso()},
        where: 'id=?',
        whereArgs: [productId],
      );
      await txn.insert('inventory_movements', {
        'id': genId(),
        'product_id': productId,
        'delta': delta,
        'reason': reason,
        'created_at': nowIso(),
      });
    });
  }
}