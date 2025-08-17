import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/misc.dart';

class SaleRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  /// Crea una venta con items, descuenta stock y calcula utilidad correcta.
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

        // Descontar stock si es un producto del catálogo
        if (toStr(it['productId']).isNotEmpty && qty > 0) {
          final pid = toStr(it['productId']);
          final rows = await txn.query('products', columns: ['stock'], where: 'id = ?', whereArgs: [pid], limit: 1);
          if (rows.isNotEmpty) {
            final current  = toInt(rows.first['stock'], fallback: 0);
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

  /// Top clientes entre fechas, con nombre/phone/ID correcto.
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

  /// HISTORIAL de ventas con filtros: por cliente, rango y búsqueda libre.
  ///
  /// Uso típico desde UI:
  ///   _repo.history(customerId: _customerId, from: _from, to: _to, query: _q)
  Future<List<Map<String, Object?>>> history({
    String? customerId,
    required DateTime from,
    required DateTime to,
    String? query,
  }) async {
    final db = await _db;

    final where = <String>[];
    final args  = <Object?>[];

    // Rango de fechas
    where.add('datetime(s.created_at) BETWEEN datetime(?) AND datetime(?)');
    args.addAll([from.toIso8601String(), to.toIso8601String()]);

    // Por cliente (opcional)
    if ((customerId ?? '').isNotEmpty) {
      where.add('s.customer_id = ?');
      args.add(customerId);
    }

    // Búsqueda libre (opcional) por id de venta, nombre/phone del cliente
    if ((query ?? '').trim().isNotEmpty) {
      final q = '%${query!.trim()}%';
      where.add('(s.id LIKE ? OR c.name LIKE ? OR c.phone LIKE ?)');
      args.addAll([q, q, q]);
    }

    final sql = '''
      SELECT
        s.id,
        s.customer_id,
        COALESCE(NULLIF(c.name,''), NULLIF(c.phone,''), 'Mostrador') AS customer_name,
        s.total, s.discount, s.shipping_cost, s.profit, s.payment_method,
        s.created_at
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(s.created_at) DESC
    ''';

    final rows = await db.rawQuery(sql, args);

    // Garantiza tipos consistentes
    return rows.map((r) => {
      'id'            : r['id'],
      'customer_id'   : r['customer_id'],
      'customer_name' : r['customer_name'],
      'total'         : (r['total'] as num?)?.toDouble() ?? 0.0,
      'discount'      : (r['discount'] as num?)?.toDouble() ?? 0.0,
      'shipping_cost' : (r['shipping_cost'] as num?)?.toDouble() ?? 0.0,
      'profit'        : (r['profit'] as num?)?.toDouble() ?? 0.0,
      'payment_method': r['payment_method'],
      'created_at'    : r['created_at'],
    }).toList();
  }

  /// RESUMEN de utilidad/ventas en rango (para dashboards).
  ///
  /// Devuelve: {orders, total, discount, shipping, profit, avgTicket}
  Future<Map<String, Object?>> summary(DateTime from, DateTime to) async {
    final db = await _db;
    final row = (await db.rawQuery('''
      SELECT
        COUNT(id)                              AS orders,
        COALESCE(SUM(total),0)                 AS total,
        COALESCE(SUM(discount),0)              AS discount,
        COALESCE(SUM(shipping_cost),0)         AS shipping,
        COALESCE(SUM(profit),0)                AS profit
      FROM sales
      WHERE datetime(created_at) BETWEEN datetime(?) AND datetime(?)
    ''', [from.toIso8601String(), to.toIso8601String()])).first;

    final orders   = (row['orders']   as num? ?? 0).toInt();
    final total    = (row['total']    as num? ?? 0).toDouble();
    final discount = (row['discount'] as num? ?? 0).toDouble();
    final shipping = (row['shipping'] as num? ?? 0).toDouble();
    final profit   = (row['profit']   as num? ?? 0).toDouble();

    final avgTicket = orders > 0 ? total / orders : 0.0;

    return {
      'orders'   : orders,
      'total'    : total,
      'discount' : discount,
      'shipping' : shipping,
      'profit'   : profit,
      'avgTicket': avgTicket,
    };
  }
}