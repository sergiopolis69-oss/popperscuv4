import 'package:sqflite/sqflite.dart';

class SaleRepository {
  final Database db;
  SaleRepository(this.db);

  Future<Map<String, dynamic>?> getWithItems(int saleId) async {
    final header = await db.query('sales', where: 'id=?', whereArgs: [saleId], limit: 1);
    if (header.isEmpty) return null;
    final items = await db.rawQuery('''
      SELECT si.*, p.name AS product_name, p.sku
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
    ''', [saleId]);
    return {'header': header.first, 'items': items};
  }

  Future<void> deleteSale(int saleId) async {
    await db.transaction((txn) async {
      final items = await txn.query('sale_items', columns: ['product_id', 'quantity'], where: 'sale_id=?', whereArgs: [saleId]);
      for (final it in items) {
        final productId = it['product_id'] as int;
        final qty = (it['quantity'] as num).toDouble();
        await txn.rawUpdate('UPDATE products SET stock = COALESCE(stock,0) + ? WHERE id = ?', [qty, productId]);
      }
      await txn.delete('sale_items', where: 'sale_id=?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id=?', whereArgs: [saleId]);
    });
  }
}
