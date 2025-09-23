import 'package:sqflite/sqflite.dart';
import 'purchase_models.dart';

class PurchaseRepository {
  final Database db;
  PurchaseRepository(this.db);

  Future<int> createPurchase({
    required Purchase purchase,
    required List<PurchaseItem> items,
  }) async {
    return db.transaction<int>((txn) async {
      final id = await txn.insert('purchases', purchase.toMap());
      for (final it in items) {
        final withId = it.copyWith(purchaseId: id);
        await txn.insert('purchase_items', withId.toMap());
        await _applyInventoryChange(txn,
          productId: it.productId, qty: it.qty, unitCost: it.unitCost);
      }
      final total = items.fold<double>(0.0, (a, b) => a + b.qty * b.unitCost);
      await txn.update('purchases', {'total': total}, where: 'id = ?', whereArgs: [id]);
      return id;
    });
  }

  Future<void> _applyInventoryChange(
    Transaction txn, { required int productId, required double qty, required double unitCost }
  ) async {
    final rows = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
    if (rows.isEmpty) throw StateError('Producto $productId no encontrado');
    final p = rows.first;
    final currentStock = (p['stock'] as num?)?.toDouble() ?? 0.0;
    final currentCost  = (p['cost']  as num?)?.toDouble() ?? unitCost;

    final newStock = currentStock + qty;
    final newCost  = newStock > 0
      ? ((currentCost * currentStock) + (unitCost * qty)) / (newStock)
      : unitCost;

    await txn.update(
      'products',
      {
        'stock': newStock,
        'cost': newCost,
        'last_cost': unitCost,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }
}
