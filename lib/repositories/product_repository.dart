import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/db.dart';

class ProductRepository {
  final _uuid = const Uuid();
  Future<Database> _db() => AppDatabase().database;

  Future<List<Map<String, Object?>>> all() async {
    final db = await _db();
    return db.query('products', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> deleteById(String id) async {
    final db = await _db();
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserta o actualiza (por id). Map tolerante con camelCase/snake_case.
  Future<void> upsertProduct(Map<String, Object?> data) async {
    T? _get<T>(Map m, String a, String b) =>
        (m[a] as T?) ?? (m[b] as T?);

    final db = await _db();
    final id = _get<String>(data, 'id', 'id') ?? _uuid.v4();
    final name = _get<String>(data, 'name', 'name') ?? '';
    final sku = _get<String>(data, 'sku', 'sku');
    final category = _get<String>(data, 'category', 'category');
    final price = (_get<num>(data, 'price', 'price') ?? 0).toDouble();
    final cost = (_get<num>(data, 'cost', 'cost') ?? 0).toDouble();
    final stock = (_get<num>(data, 'stock', 'stock') ?? 0).toInt();

    await db.insert(
      'products',
      {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'price': price,
        'cost': cost,
        'stock': stock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> categoriesDistinct() async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND TRIM(category) <> '' ORDER BY category COLLATE NOCASE
    ''');
    return rows.map((r) => (r['category'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
  }

  Future<List<Map<String, Object?>>> searchByNameOrSku(String query) async {
    final db = await _db();
    final q = '%${query.trim()}%';
    return db.query(
      'products',
      where: '(name LIKE ? OR sku LIKE ?)',
      whereArgs: [q, q],
      orderBy: 'name COLLATE NOCASE',
      limit: 50,
    );
  }
}