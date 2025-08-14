import 'package:sqflite/sqflite.dart';
import '../db/db.dart';

class CustomerRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Map<String, Object?>>> all() async {
    final db = await _db;
    return db.query('customers', orderBy: 'updated_at DESC, name ASC');
  }

  Future<List<Map<String, Object?>>> searchByNameOrPhone(String q) async {
    final db = await _db;
    final like = '%${q.trim()}%';
    return db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: [like, like],
      orderBy: 'name ASC',
      limit: 50,
    );
  }

  Future<void> upsertCustomer(Map<String, Object?> data) async {
    final db = await _db;
    final String id = (data['id']?.toString().trim().isNotEmpty ?? false)
        ? data['id'].toString()
        : (data['phone']?.toString() ?? genId());
    final now = nowIso();
    final row = {
      'id': id,
      'name': data['name'],
      'phone': data['phone'],
      'notes': data['notes'],
      'updated_at': now,
      'created_at': data['created_at'] ?? now,
    };
    await db.insert('customers', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertCustomerNamed({
    String? id,
    required String name,
    String? phone,
    String? notes,
  }) async {
    await upsertCustomer({
      'id': id ?? phone,
      'name': name,
      'phone': phone,
      'notes': notes,
    });
  }

  Future<void> deleteById(String id) async {
    final db = await _db;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
    };
    await db.insert('customers', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Firma que llama tu UI
  Future<void> upsertCustomerNamed({
    String? id,
    required String name,
    String? phone,
    String? notes,
  }) async {
    await upsertCustomer({
      'id': id ?? phone,
      'name': name,
      'phone': phone,
      'notes': notes,
    });
  }

  Future<void> deleteById(String id) async {
    final db = await _db;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
