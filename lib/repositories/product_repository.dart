
import 'package:uuid/uuid.dart';
import '../services/db.dart';

class ProductRepository {
  final _uuid = const Uuid();

  Future<List<Map<String, Object?>>> all() async {
    final db = await AppDatabase().database;
    return db.query('products', orderBy: 'name ASC');
  }

  Future<Map<String, Object?>> upsertProduct(Map<String, Object?> data) async {
    final db = await AppDatabase().database;
    final id = (data['id'] ?? _uuid.v4()) as String;
    final now = DateTime.now().toIso8601String();

    final row = {
      'id': id,
      'name': (data['name'] ?? '') as String,
      'sku': data['sku'],
      'category': data['category'],
      'cost': (data['cost'] ?? 0) as Object?,
      'price': (data['price'] ?? 0) as Object?,
      'stock': (data['stock'] ?? 0) as Object?,
      'created_at': (data['created_at'] ?? now) as String,
      'updated_at': now,
    };

    // Intento de update, si no actualiza => insert
    final updated = await db.update('products', row, where: 'id = ?', whereArgs: [id]);
    if (updated == 0) {
      await db.insert('products', row);
    }
    return row;
  }

  Future<void> updateStock(String productId, int delta) async {
    final db = await AppDatabase().database;
    await db.rawUpdate('UPDATE products SET stock = stock + ? WHERE id = ?', [delta, productId]);
  }

  Future<List<String>> categories() async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category <> "" ORDER BY category');
    return rows.map((e) => (e['category'] ?? '') as String).where((s) => s.isNotEmpty).toList();
  }
}
