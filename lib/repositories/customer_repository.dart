
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class CustomerRepository {
  final _uuid = const Uuid();

  Future<List<Map<String, Object?>>> all() async {
    final db = await AppDatabase().database;
    return db.query('customers', orderBy: 'created_at DESC');
  }

  Future<String> upsertCustomer({
    String? id,
    required String name,
    String? phone,
    String? email,
  }) async {
    final db = await AppDatabase().database;
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'id': id ?? _uuid.v4(),
      'name': name,
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'created_at': now,
    };
    await db.insert('customers', data, conflictAlgorithm: ConflictAlgorithm.replace);
    return data['id'] as String;
  }

  Future<void> deleteById(String id) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      // Si la tabla sales tiene customer_id nullable, setéalo a null para no perder historial
      try {
        await txn.update('sales', {'customer_id': null}, where: 'customer_id = ?', whereArgs: [id]);
      } catch (_) {}
      await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }
}
