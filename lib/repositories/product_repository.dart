import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/misc.dart';

class ProductRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Map<String, Object?>>> listFiltered({String? q, String? category}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (q != null && q.trim().isNotEmpty) {
      final s = '%${q.toLowerCase()}%';
      where.add('(LOWER(name) LIKE ? OR LOWER(sku) LIKE ?)');
      args..add(s)..add(s);
    }
    if (category != null && category.isNotEmpty && category != 'Todas') {
      where.add('category = ?');
      args.add(category);
    }

    return db.query(
      'products',
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: args,
      orderBy: 'name IS NULL, name, sku',
    );
  }

  Future<List<String>> categoriesDistinct() async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND TRIM(category) <> '' ORDER BY category",
    );
    return rows.map((e) => e['category']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  Future<Map<String, Object?>?> byId(String id) async {
    final db = await _db;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> bySku(String sku) async {
    final db = await _db;
    final rows = await db.query('products', where: 'sku = ?', whereArgs: [sku], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteById(String id) async {
    final db = await _db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertProduct(Map<String, Object?> data) async {
    final db = await _db;
    final id = (toStr(data['id']).isNotEmpty) ? toStr(data['id']) : genId();
    final now = nowIso();
    final row = <String, Object?>{
      'id'        : id,
      'sku'       : toStr(data['sku']).isNotEmpty ? toStr(data['sku']) : null,
      'name'      : toStr(data['name']).isNotEmpty ? toStr(data['name']) : null,
      'price'     : toDouble(data['price']),
      'cost'      : toDouble(data['cost']),
      'stock'     : toInt(data['stock']),
      'category'  : toStr(data['category']).isNotEmpty ? toStr(data['category']) : null,
      'created_at': toStr(data['created_at']).isNotEmpty ? toStr(data['created_at']) : now,
      'updated_at': now,
    };
    await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}