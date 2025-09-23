import 'package:sqflite/sqflite.dart';

class ProductRepository {
  final Database db;
  ProductRepository(this.db);

  Future<void> increaseStock(int productId, double qty) async {
    await db.rawUpdate('UPDATE products SET stock = COALESCE(stock,0) + ? WHERE id = ?', [qty, productId]);
  }

  Future<void> decreaseStock(int productId, double qty) async {
    await db.rawUpdate('UPDATE products SET stock = COALESCE(stock,0) - ? WHERE id = ?', [qty, productId]);
  }

  Future<void> updateCosts({ required int productId, required int supplierId, required double unitCost, }) async {
    final existing = await db.query('product_supplier_costs', where: 'product_id=? AND supplier_id=?', whereArgs: [productId, supplierId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('product_supplier_costs', {
        'product_id': productId,
        'supplier_id': supplierId,
        'last_cost': unitCost,
        'average_cost': unitCost,
        'samples': 1,
      });
    } else {
      final row = existing.first;
      final samples = (row['samples'] as int);
      final avg = (row['average_cost'] as num).toDouble();
      final newAvg = ((avg * samples) + unitCost) / (samples + 1);
      await db.update('product_supplier_costs', {
        'last_cost': unitCost,
        'average_cost': newAvg,
        'samples': samples + 1,
      }, where: 'id=?', whereArgs: [row['id']]);
    }
    await db.rawUpdate('UPDATE products SET last_cost = ? WHERE id = ?', [unitCost, productId]);
  }
}
