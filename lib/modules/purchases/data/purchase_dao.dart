
import 'package:sqflite/sqflite.dart';
import 'purchase_models.dart';

class PurchaseDao {
  final Database db;
  PurchaseDao(this.db);

  Future<int> insertPurchase(Purchase p) =>
      db.insert('purchases', p.toMap(), conflictAlgorithm: ConflictAlgorithm.rollback);

  Future<void> insertItems(List<PurchaseItem> items) async {
    final batch = db.batch();
    for (final it in items) {
      batch.insert('purchase_items', it.toMap(), conflictAlgorithm: ConflictAlgorithm.rollback);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> fetchPurchasesSummary() async {
    return db.rawQuery('''
      SELECT p.id, p.date, p.payment_method, p.total,
            s.name AS supplier_name,
            (SELECT COUNT(*) FROM purchase_items pi WHERE pi.purchase_id = p.id) AS item_count
      FROM purchases p
      JOIN suppliers s ON s.id = p.supplier_id
      ORDER BY p.date DESC
    ''');
  }

  Future<List<Map<String, Object?>>> fetchPurchaseItems(int purchaseId) {
    return db.rawQuery('''
      SELECT pi.*, prod.name AS product_name
      FROM purchase_items pi
      JOIN products prod ON prod.id = pi.product_id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
    ''', [purchaseId]);
  }
}
