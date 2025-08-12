import '../services/db.dart';
import '../models/product.dart';

class ProductRepository {
  Future<List<Product>> all() async {
    final db = await AppDatabase().database;
    final rows = await db.query('products', orderBy: 'created_at DESC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product> create(Product p) async {
    final db = await AppDatabase().database;
    await db.insert('products', p.toMap());
    return p;
  }

  Future<void> update(Product p) async {
    final db = await AppDatabase().database;
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase().database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> categories() async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery("SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category <> '' ORDER BY category COLLATE NOCASE");
    return rows.map((e) => (e['category'] as String)).toList();
  }
}
