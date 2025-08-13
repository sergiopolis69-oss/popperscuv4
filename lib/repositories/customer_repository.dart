import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/db.dart';

class CustomerRepository {
  final _uuid = const Uuid();
  Future<Database> _db() => AppDatabase().database;

  Future<List<Map<String, Object?>>> all() async {
    final db = await _db();
    return db.query('customers', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> deleteById(String id) async {
    final db = await _db();
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  /// Si usas el teléfono como identificador, pásalo en `id` y guarda `phone` opcional.
  Future<void> upsertCustomer(Map<String, Object?> data) async {
    T? _get<T>(Map m, String a, String b) =>
        (m[a] as T?) ?? (m[b] as T?);

    final db = await _db();
    // id: si no viene, usamos phone; si tampoco hay, generamos uuid
    final id = _get<String>(data, 'id', 'id') ??
        _get<String>(data, 'phone', 'phone') ??
        _uuid.v4();

    final name = _get<String>(data, 'name', 'name') ?? '';
    final phone = _get<String>(data, 'phone', 'phone');
    final notes = _get<String>(data, 'notes', 'notes');

    await db.insert(
      'customers',
      {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> searchByNameOrPhone(String query) async {
    final db = await _db();
    final q = '%${query.trim()}%';
    return db.query(
      'customers',
      where: '(name LIKE ? OR phone LIKE ?)',
      whereArgs: [q, q],
      orderBy: 'name COLLATE NOCASE',
      limit: 50,
    );
  }
}