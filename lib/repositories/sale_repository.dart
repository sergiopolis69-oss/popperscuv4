import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/utils/db.dart';
import 'package:popperscuv/utils/helpers.dart';

class SaleRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  /// Inserta venta e items, descuenta stock y registra movimientos.
  /// Calcula utilidad así:
  ///   profit = (sum(price*qty - lineDiscount) - discount) - sum(cost*qty)
  /// El shipping no afecta la utilidad.
  Future<void> create(Map<String, Object?> sale, List<Map<String, Object?>> items) async {
    final db = await _db;

    // Cálculos base
    double gross = 0.0;      // sum(price*qty - lineDiscount)
    double costSum = 0.0;    // sum(cost*qty)

    for (final it in items) {
      final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse('${it['price']}') ?? 0.0;
      final cost  = (it['cost']  is num) ? (it['cost']  as num).toDouble() : double.tryParse('${it['cost']}')  ?? 0.0;
      final qty   = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : int.tryParse('${it['quantity']}') ?? 0;
      final lineDiscount = (it['lineDiscount'] is num) ? (it['lineDiscount'] as num).toDouble() : double.tryParse('${it['lineDiscount']}') ?? 0.0;

      gross += (price * qty) - lineDiscount;
      costSum += (cost * qty);
    }

    final discount = (sale['discount'] is num) ? (sale['discount'] as num).toDouble() : double.tryParse('${sale['discount']}') ?? 0.0;
    final shipping = (sale['shippingCost'] is num) ? (sale['shippingCost'] as num).toDouble() : double.tryParse('${sale['shippingCost']}') ?? 0.0;

    final profit = (gross - discount) - costSum;
    final computedTotal = gross - discount + shipping;

    final saleId = (sale['id']?.toString().trim().isNotEmpty ?? false) ? sale['id']!.toString() : genId();
    final createdAt = (sale['createdAt']?.toString().trim().isNotEmpty ?? false) ? sale['createdAt']!.toString() : nowIso();

    await db.transaction((txn) async {
      // Insert sale
      await txn.insert('sales', {
        'id': saleId,
        'customer_id': sale['customerId']?.toString(),
        'total': (sale['total'] is num) ? (sale['total'] as num).toDouble() : computedTotal,
        'discount': discount,
        'shipping_cost': shipping,
        'profit': profit,
        'payment_method': sale['paymentMethod']?.toString() ?? 'Efectivo',
        'created_at': createdAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert items + descuento de stock + movimiento inventario
      for (final it in items) {
        final itemId = (it['id']?.toString().trim().isNotEmpty ?? false) ? it['id']!.toString() : genId();
        final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse('${it['price']}') ?? 0.0;
        final cost  = (it['cost']  is num) ? (it['cost']  as num).toDouble() : double.tryParse('${it['cost']}')  ?? 0.0;
        final qty   = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : int.tryParse('${it['quantity']}') ?? 0;
        final lineDiscount = (it['lineDiscount'] is num) ? (it['lineDiscount'] as num).toDouble() : double.tryParse('${it['lineDiscount']}') ?? 0.0;
        final subtotal = (price * qty) - lineDiscount;

        await txn.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': it['productId']?.toString(),
          'name': it['name']?.toString(),
          'sku': it['sku']?.toString(),
          'price': price,
          'cost': cost,
          'quantity': qty,
          'line_discount': lineDiscount,
          'subtotal': subtotal,
          'created_at': createdAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // descontar stock
        final pid = it['productId']?.toString();
        if (pid != null && pid.isNotEmpty && qty != 0) {
          final curRows = await txn.query('products', columns: ['stock'], where: 'id=?', whereArgs: [pid], limit: 1);
          final cur = curRows.isEmpty ? 0 : (curRows.first['stock'] as num?)?.toInt() ?? 0;
          final newStock = cur - qty;
          await txn.update('products', {'stock': newStock, 'updated_at': nowIso()}, where: 'id=?', whereArgs: [pid]);

          await txn.insert('inventory_movements', {
            'id': genId(),
            'product_id': pid,
            'delta': -qty,
            'reason': 'sale:$saleId',
            'created_at': createdAt,
          });
        }
      }
    });
  }

  Future<List<Map<String, Object?>>> history({
    String? customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (customerId != null && customerId.trim().isNotEmpty) {
      where.add('s.customer_id = ?');
      args.add(customerId.trim());
    }
    if (from != null) {
      where.add('s.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      // para incluir el día completo, sumamos 1 día exclusivo si quieres
      final excl = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      where.add('s.created_at <= ?');
      args.add(excl.toIso8601String());
    }

    final sql = '''
      SELECT
        s.id,
        s.created_at,
        s.customer_id,
        c.name AS customer_name,
        s.total,
        s.discount,
        s.shipping_cost,
        s.profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY s.created_at DESC
    ''';

    return db.rawQuery(sql, args);
  }

  Future<List<Map<String, Object?>>> topCustomers(DateTime from, DateTime to) async {
    final db = await _db;
    final sql = '''
      SELECT
        s.customer_id AS id,
        COALESCE(c.name, s.customer_id) AS name,
        COUNT(*) AS orders,
        SUM(s.total) AS total,
        SUM(s.profit) AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at >= ? AND s.created_at <= ?
      GROUP BY s.customer_id, name
      ORDER BY total DESC
    ''';
    final excl = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();
    return db.rawQuery(sql, [from.toIso8601String(), excl]);
  }

  Future<Map<String, Object?>> summary(DateTime from, DateTime to) async {
    final db = await _db;
    final sql = '''
      SELECT
        COUNT(*) AS orders,
        SUM(total) AS total,
        SUM(discount) AS discount,
        SUM(shipping_cost) AS shipping,
        SUM(profit) AS profit
      FROM sales
      WHERE created_at >= ? AND created_at <= ?
    ''';
    final excl = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();
    final rows = await db.rawQuery(sql, [from.toIso8601String(), excl]);
    return rows.isEmpty ? <String, Object?>{} : rows.first;
  }
}