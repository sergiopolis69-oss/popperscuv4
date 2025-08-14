import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/db/db.dart'; // <— usa import por paquete

class ProductRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Map<String, Object?>>> all() async {
    final db = await _db;
    return db.query('products', orderBy: 'updated_at DESC, name ASC');
  }

  Future<List<Map<String, Object?>>> searchByNameOrSku(String q) async {
    final db = await _db;
    final like = '%${q.trim()}%';
    return db.query(
      'products',
      where: 'name LIKE ? OR sku LIKE ?',
      whereArgs: [like, like],
      orderBy: 'name ASC',
      limit: 50,
    );
  }

  Future<List<String>> categoriesDistinct() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT DISTINCT category FROM products
      WHERE category IS NOT NULL AND TRIM(category) <> ''
      ORDER BY category COLLATE NOCASE
    ''');
    return rows.map((e) => (e['category'] as String)).toList();
  }

  Future<void> upsertProduct(Map<String, Object?> data) async {
    final db = await _db;
    final id = (data['id']?.toString() ?? genId());
    final now = nowIso();
    final row = {
      'id': id,
      'name': data['name'],
      'sku': data['sku'],
      'category': data['category'],
      'price': (data['price'] as num).toDouble(),
      'cost': (data['cost'] as num).toDouble(),
      'stock': (data['stock'] as num).toInt(),
      'updated_at': now,
      'created_at': data['created_at'] ?? now,
    };
    await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Wrapper compatible con la UI (argumentos con nombre)
  Future<void> upsertProductNamed({
    String? id,
    required String name,
    String? sku,
    String? category,
    required double price,
    required double cost,
    required int stock,
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

  Future<void> deleteById(String id) async {
    final db = await _db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock(String productId, int delta, {String? note}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final cur = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      if (cur.isEmpty) return;
      final current = (cur.first['stock'] as int);
      final newStock = current + delta;
      await txn.update('products', {'stock': newStock, 'updated_at': nowIso()},
          where: 'id = ?', whereArgs: [productId]);
      await txn.insert('inventory_movements', {
        'id': genId(),
        'product_id': productId,
        'delta': delta,
        'note': note ?? 'ajuste',
        'created_at': nowIso(),
      });
    });
  }
}