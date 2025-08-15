import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/utils/db.dart';
import 'package:popperscuv/utils/helpers.dart';

class CustomerRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Map<String, Object?>>> all() async {
    final db = await _db;
    return db.query('customers', orderBy: 'LOWER(name)');
  }

  Future<List<Map<String, Object?>>> listFiltered({String? q}) async {
    final db = await _db;
    if (q == null || q.trim().isEmpty) {
      return db.query('customers', orderBy: 'LOWER(name)');
    }
    return db.query(
      'customers',
      where: 'LOWER(COALESCE(name,"")) LIKE LOWER(?) OR LOWER(COALESCE(id,"")) LIKE LOWER(?) OR LOWER(COALESCE(phone,"")) LIKE LOWER(?)',
      whereArgs: ['%${q.trim()}%', '%${q.trim()}%', '%${q.trim()}%'],
      orderBy: 'LOWER(name)',
    );
  }

  Future<void> deleteById(String id) async {
    final db = await _db;
    await db.delete('customers', where: 'id=?', whereArgs: [id]);
  }

  Future<void> upsertCustomer(Map<String, Object?> data) async {
    final db = await _db;
    // Usamos id explícito, si no, phone como id, si no, genId()
    final providedId = data['id']?.toString().trim();
    final phone = data['phone']?.toString().trim();
    final id = (providedId?.isNotEmpty ?? false)
        ? providedId!
        : ((phone?.isNotEmpty ?? false) ? phone! : genId());

    final now = nowIso();
    final row = <String, Object?>{
      'id': id,
      'name': data['name']?.toString(),
      'phone': phone,
      'email': data['email']?.toString(),
      'updated_at': now,
    };

    final exists = await db.query('customers', columns: ['id'], where: 'id=?', whereArgs: [id], limit: 1);
    if (exists.isEmpty) row['created_at'] = now;

    await db.insert('customers', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertCustomerNamed({
    String? id,
    required String name,
    String? phone,
    String? email,
  }) async {
    await upsertCustomer({
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
    });
  }
}