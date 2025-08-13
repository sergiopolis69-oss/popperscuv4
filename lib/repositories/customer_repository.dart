
import 'package:uuid/uuid.dart';
import '../services/db.dart';

class CustomerRepository {
  final _uuid = const Uuid();

  Future<List<Map<String, Object?>>> all() async {
    final db = await AppDatabase().database;
    return db.query('customers', orderBy: 'name ASC');
  }

  Future<Map<String, Object?>> upsertCustomer(Map<String, Object?> data) async {
    final db = await AppDatabase().database;
    final id = (data['id'] ?? _uuid.v4()) as String;
    final now = DateTime.now().toIso8601String();

    final row = {
      'id': id,
      'name': (data['name'] ?? '') as String,
      'phone': data['phone'],
      'created_at': (data['created_at'] ?? now) as String,
      'updated_at': now,
    };

    final updated = await db.update('customers', row, where: 'id = ?', whereArgs: [id]);
    if (updated == 0) {
      await db.insert('customers', row);
    }
    return row;
  }
}
