import 'package:sqflite/sqflite.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/payment_method.dart';

class PurchaseRepository {
  final Database db;
  PurchaseRepository(this.db);

  Future<int> create(Purchase p) async {
    return await db.transaction<int>((txn) async {
      final purchaseId = await txn.insert('purchases', {
        'supplier_id': p.supplierId,
        'created_at': p.createdAt.toIso8601String(),
        'payment_method': p.paymentMethod.dbValue,
        'notes': p.notes,
        'is_canceled': 0,
        'subtotal': p.subtotal,
      });

      for (final it in p.items) {
        await txn.insert('purchase_items', it.toMap(purchaseId));
        await txn.rawUpdate('UPDATE products SET stock = COALESCE(stock,0) + ? WHERE id = ?', [it.quantity, it.productId]);

        final existing = await txn.query('product_supplier_costs', where: 'product_id=? AND supplier_id=?', whereArgs: [it.productId, p.supplierId], limit: 1);
        if (existing.isEmpty) {
          await txn.insert('product_supplier_costs', {
            'product_id': it.productId,
            'supplier_id': p.supplierId,
            'last_cost': it.unitCost,
            'average_cost': it.unitCost,
            'samples': 1,
          });
        } else {
          final row = existing.first;
          final samples = (row['samples'] as int);
          final avg = (row['average_cost'] as num).toDouble();
          final newAvg = ((avg * samples) + it.unitCost) / (samples + 1);
          await txn.update('product_supplier_costs', {
            'last_cost': it.unitCost,
            'average_cost': newAvg,
            'samples': samples + 1,
          }, where: 'id=?', whereArgs: [row['id']]);
        }
        await txn.rawUpdate('UPDATE products SET last_cost = ? WHERE id = ?', [it.unitCost, it.productId]);
      }
      return purchaseId;
    });
  }

  Future<void> _recalcSubtotal(Transaction txn, int purchaseId) async {
    final sum = await txn.rawQuery('SELECT COALESCE(SUM(line_total),0) AS s FROM purchase_items WHERE purchase_id=? AND is_canceled=0', [purchaseId]);
    final s = (sum.first['s'] as num).toDouble();
    await txn.update('purchases', {'subtotal': s}, where: 'id=?', whereArgs: [purchaseId]);
  }

  Future<void> cancelItem(int itemId) async {
    await db.transaction((txn) async {
      final rows = await txn.query('purchase_items', where: 'id=?', whereArgs: [itemId], limit: 1);
      if (rows.isEmpty) return;
      final it = rows.first;
      if ((it['is_canceled'] as int? ?? 0) == 1) return;
      final pid = it['purchase_id'] as int;
      final productId = it['product_id'] as int;
      final qty = (it['quantity'] as num).toDouble();

      await txn.rawUpdate('UPDATE products SET stock = COALESCE(stock,0) - ? WHERE id = ?', [qty, productId]);
      await txn.update('purchase_items', {'is_canceled': 1}, where: 'id=?', whereArgs: [itemId]);
      await _recalcSubtotal(txn, pid);
    });
  }

  Future<void> cancelPurchase(int purchaseId) async {
    await db.transaction((txn) async {
      final header = await txn.query('purchases', where: 'id=?', whereArgs: [purchaseId], limit: 1);
      if (header.isEmpty) return;
      if ((header.first['is_canceled'] as int? ?? 0) == 1) return;

      final items = await txn.query('purchase_items', where: 'purchase_id=? AND is_canceled=0', whereArgs: [purchaseId]);
      for (final it in items) {
        final productId = it['product_id'] as int;
        final qty = (it['quantity'] as num).toDouble();
        await txn.rawUpdate('UPDATE products SET stock = COALESCE(stock,0) - ? WHERE id = ?', [qty, productId]);
        await txn.update('purchase_items', {'is_canceled': 1}, where: 'id=?', whereArgs: [it['id']]);
      }

      await txn.update('purchases', {'is_canceled': 1, 'subtotal': 0}, where: 'id=?', whereArgs: [purchaseId]);
    });
  }

  Future<List<Map<String, dynamic>>> listWithSupplier() async {
    return await db.rawQuery('''
      SELECT p.id, p.created_at, p.payment_method, p.subtotal, p.is_canceled, s.name AS supplier_name
      FROM purchases p
      JOIN suppliers s ON s.id = p.supplier_id
      ORDER BY p.created_at DESC
    ''');
  }

  Future<Map<String, dynamic>?> getWithItems(int purchaseId) async {
    final headerRows = await db.query('purchases', where: 'id=?', whereArgs: [purchaseId], limit: 1);
    if (headerRows.isEmpty) return null;
    final items = await db.rawQuery('''
      SELECT i.*, pr.name AS product_name, pr.sku
      FROM purchase_items i
      JOIN products pr ON pr.id = i.product_id
      WHERE i.purchase_id = ?
      ORDER BY i.id ASC
    ''', [purchaseId]);
    final h = headerRows.first;
    return {'header': h, 'items': items};
  }
}
