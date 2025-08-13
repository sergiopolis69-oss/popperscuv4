
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class ProductRepository {
  final _uuid = const Uuid();

  Future<List<Map<String, Object?>>> all() async {
    final db = await AppDatabase().database;
    return db.query('products', orderBy: 'created_at DESC');
  }

  Future<List<String>> categoriesDistinct() async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND TRIM(category) <> '' ORDER BY category"
    );
    return rows.map((r) => (r['category'] as String)).toList();
  }

  Future<String> upsertProduct({
    String? id,
    required String name,
    String? sku,
    String? category,
    required double cost,
    required double price,
    required int stock,
  }) async {
    final db = await AppDatabase().database;
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'id': id ?? _uuid.v4(),
      'name': name,
      'sku': (sku == null || sku.trim().isEmpty) ? null : sku.trim(),
      'category': (category == null || category.trim().isEmpty) ? null : category.trim(),
      'cost': cost,
      'price': price,
      'stock': stock,
      'updated_at': now,
    };
    if (id == null) data['created_at'] = now;

    await db.insert('products', data, conflictAlgorithm: ConflictAlgorithm.replace);
    return data['id'] as String;
  }

  Future<void> deleteById(String id) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      // limpia movimientos de inventario
      await txn.delete('inventory_movements', where: 'product_id = ?', whereArgs: [id]);
      // opcional: limpiar items de ventas que referencien (si existe la tabla)
      try {
        await txn.delete('sale_items', where: 'product_id = ?', whereArgs: [id]);
      } catch (_) {}
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }
}
