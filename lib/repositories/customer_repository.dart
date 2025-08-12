import '../services/db.dart';
import '../models/customer.dart';

class CustomerRepository {
  Future<List<Customer>> all() async {
    final db = await AppDatabase().database;
    final rows = await db.query('customers', orderBy: 'created_at DESC');
    return rows.map((e) => Customer.fromMap(e)).toList();
  }

  Future<Customer> create(Customer c) async {
    final db = await AppDatabase().database;
    await db.insert('customers', c.toMap());
    return c;
  }

  Future<void> update(Customer c) async {
    final db = await AppDatabase().database;
    await db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase().database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
