import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/misc.dart';

class CustomerRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> upsertCustomer(Map<String, Object?> data) async {
    final db = await _db;
    final id = toStr(data['id']).isNotEmpty
        ? toStr(data['id'])
        : (toStr(data['phone']).isNotEmpty ? toStr(data['phone']) : genId());
    final now = nowIso();
    await db.insert(
      'customers',
      {
        'id'        : id,
        'name'      : toStr(data['name']).isNotEmpty ? toStr(data['name']) : null,
        'phone'     : toStr(data['phone']).isNotEmpty ? toStr(data['phone']) : null,
        'created_at': toStr(data['created_at']).isNotEmpty ? toStr(data['created_at']) : now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> all({String? q}) async {
    final db = await _db;
    if (q != null && q.trim().isNotEmpty) {
      final s = '%${q.toLowerCase()}%';
      return db.query(
        'customers',
        where: 'LOWER(name) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(id) LIKE ?',
        whereArgs: [s, s, s],
        orderBy: 'name',
      );
    }
    return db.query('customers', orderBy: 'name');
  }

  Future<Map<String, Object?>?> byId(String id) async {
    final db = await _db;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}