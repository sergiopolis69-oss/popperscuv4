
import 'package:sqflite/sqflite.dart';
import 'purchase_models.dart';

class SupplierDao {
  final Database db;
  SupplierDao(this.db);

  Future<int> insert(Supplier s) => db.insert('suppliers', s.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort);

  Future<List<Supplier>> all() async {
    final rows = await db.query('suppliers', orderBy: 'name COLLATE NOCASE');
    return rows.map(Supplier.fromMap).toList();
  }
}
