
import 'package:uuid/uuid.dart';
import '../services/db.dart';

class ProductRepository {
  final _uuid = const Uuid();

  Future<List<Map<String, Object?>>> all() async {
    final db = await AppDatabase().database;
    return db.query('products', orderBy: 'name ASC');
  }

  // API 1: llamada por UI (map)
  Future<Map<String, Object?>> upsertProduct(Map<String, Object?> data) async {
    final db = await AppDatabase().database;
    final id = (data['id'] ?? const Uuid().v4()) as String;
    final now = DateTime.now().toIso8601String();

    final row = {
      'id': id,
      'name': (data['name'] ?? '') as String,
      'sku': data['sku'],
      'category': data['category'],
      'cost': (data['cost'] as num?)?.toDouble() ?? 0.0,
      'price': (data['price'] as num?)?.toDouble() ?? 0.0,
      'stock': (data['stock'] as num?)?.toInt() ?? 0,
      'created_at': (data['created_at'] ?? now) as String,
      'updated_at': now,
    };

    final updated = await db.update('products', row, where: 'id = ?', whereArgs: [id]);
    if (updated == 0) {
      await db.insert('products', row);
    }
    return row;
  }

  // API 2: compat con pantallas viejas (parámetros con nombre)
  Future<Map<String, Object?>> upsertProductNamed({
    String? id,
    required String name,
    String? sku,
    String? category,
    double cost = 0,
    double price = 0,
    int stock = 0,
  }) async {
    return upsertProduct({
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'cost': cost,
      'price': price,
      'stock': stock,
    });
  }

  Future<void> deleteById(String id) async {
    final db = await AppDatabase().database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStock(String productId, int delta) async {
    final db = await AppDatabase().database;
    await db.rawUpdate('UPDATE products SET stock = stock + ? WHERE id = ?', [delta, productId]);
  }

  Future<List<String>> categoriesDistinct() async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category <> "" ORDER BY category');
    return rows.map((e) => (e['category'] ?? '') as String).where((s) => s.isNotEmpty).toList();
  }

  Future<List<String>> categories() => categoriesDistinct();
}
