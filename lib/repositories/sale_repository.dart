import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/misc.dart';

class SaleRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> create(Map<String, Object?> sale, List<Map<String, Object?>> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      final saleId    = toStr(sale['id']).isNotEmpty ? toStr(sale['id']) : genId();
      final createdAt = toStr(sale['createdAt']).isNotEmpty ? toStr(sale['createdAt']) : nowIso();
      final discount  = toDouble(sale['discount']);
      final shipping  = toDouble(sale['shippingCost']);

      double subtotal  = 0.0;
      double costTotal = 0.0;

      for (final it in items) {
        final price        = toDouble(it['price']);
        final cost         = toDouble(it['cost']);
        final qty          = toInt(it['quantity'], fallback: 1);
        final lineDiscount = toDouble(it['lineDiscount']);
        final lineSubtotal = (price * qty - lineDiscount);

        subtotal  += lineSubtotal;
        costTotal += (cost * qty);

        await txn.insert('sale_items', {
          'id'           : toStr(it['id']).isNotEmpty ? toStr(it['id']) : genId(),
          'sale_id'      : saleId,
          'product_id'   : toStr(it['productId']).isNotEmpty ? toStr(it['productId']) : null,
          'sku'          : toStr(it['sku']).isNotEmpty ? toStr(it['sku']) : null,
          'name'         : toStr(it['name']).isNotEmpty ? toStr(it['name']) : null,
          'price'        : price,
          'cost'         : cost,
          'quantity'     : qty,
          'line_discount': lineDiscount,
          'subtotal'     : lineSubtotal,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (toStr(it['productId']).isNotEmpty && qty > 0) {
          final pid = toStr(it['productId']);
          final rows = await txn.query('products', columns: ['stock'], where: 'id = ?', whereArgs: [pid], limit: 1);
          if (rows.isNotEmpty) {
            final current = toInt(rows.first['stock'], fallback: 0);
            final newStock = current - qty;
            await txn.update('products', {'stock': newStock, 'updated_at': nowIso()}, where: 'id = ?', whereArgs: [pid]);
          }
        }
      }

      final computedTotal = subtotal - discount + shipping;
      final total  = toDouble(sale['total'], fallback: computedTotal);
      final profit = (subtotal - discount) - costTotal;

      await txn.insert('sales', {
        'id'            : saleId,
        'customer_id'   : toStr(sale['customerId']).isNotEmpty ? toStr(sale['customerId']) : null,
        'total'         : total,
        'discount'      : discount,
        'shipping_cost' : shipping,
        'profit'        : profit,
        'payment_method': toStr(sale['paymentMethod']).isNotEmpty ? toStr(sale['paymentMethod']) : 'Efectivo',
        'created_at'    : createdAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, Object?>>> topCustomers(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.customer_id AS customer_id,
             COALESCE(NULLIF(c.name,''), NULLIF(c.phone,''), NULLIF(s.customer_id,''), 'Mostrador') AS customer_name,
             COUNT(s.id)  AS orders,
             COALESCE(SUM(s.total),0)  AS total,
             COALESCE(SUM(s.profit),0) AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE datetime(s.created_at) BETWEEN datetime(?) AND datetime(?)
      GROUP BY s.customer_id, c.name, c.phone
      ORDER BY total DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final totalAll = rows.fold<double>(0, (acc, r) => acc + (r['total'] as num? ?? 0).toDouble());
    return rows.map((r) {
      final t = (r['total'] as num? ?? 0).toDouble();
      final pct = totalAll > 0 ? (t * 100 / totalAll) : 0.0;
      return {...r, 'pct': pct};
    }).toList();
  }
}