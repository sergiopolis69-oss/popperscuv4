import 'package:sqflite/sqflite.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final Database db;
  SupplierRepository(this.db);

  Future<int> upsert(Supplier s) async {
    if (s.id == null) {
      return await db.insert('suppliers', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update('suppliers', s.toMap(), where: 'id=?', whereArgs: [s.id]);
      return s.id!;
    }
  }

  Future<List<Supplier>> all() async {
    final rows = await db.query('suppliers', orderBy: 'name ASC');
    return rows.map(Supplier.fromMap).toList();
  }
}
