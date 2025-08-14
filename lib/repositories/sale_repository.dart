import 'package:sqflite/sqflite.dart';
import 'package:popperscuv/db/app_database.dart';

class SaleRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<String> save(
          Map<String, Object?> sale, List<Map<String, Object?>> items) =>
      create(sale, items);

  Future<String> create(
      Map<String, Object?> sale, List<Map<String, Object?>> items) async {
    final db = await _db;

    double subtotal = 0;
    double itemsProfit = 0;

    final preparedItems = items.map<Map<String, Object?>>((it) {
      final qty = (it['quantity'] as num).toInt();
      final price = (it['price'] as num).toDouble();
      final cost = (it['cost'] as num?)?.toDouble() ?? 0.0;
      final lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;

      final sub = (price * qty) - lineDiscount;
      final prof = (price - cost) * qty - lineDiscount;

      subtotal += sub;
      itemsProfit += prof;

      return {
        'id': it['id']?.toString() ?? genId(),
        'product_id': it['productId'],
        'name': it['name'],
        'sku': it['sku'],
        'quantity': qty,
        'price': price,
        'cost': cost,
        'line_discount': lineDiscount,
        'subtotal': sub,
        'profit': prof,
      };
    }).toList();

    final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    final shipping = (sale['shippingCost'] as num?)?.toDouble() ?? 0.0;
    final profit = itemsProfit - discount;
    final total =
        (sale['total'] as num?)?.toDouble() ?? (subtotal - discount + shipping);

    final saleId = sale['id']?.toString() ?? genId();
    final createdAt = (sale['createdAt']?.toString()) ?? nowIso();
    final paymentMethod = sale['paymentMethod']?.toString() ?? 'Efectivo';
    final customerId = sale['customerId']?.toString();

    await db.transaction((txn) async {
      await txn.insert('sales', {
        'id': saleId,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'shipping_cost': shipping,
        'profit': profit,
        'payment_method': paymentMethod,
        'created_at': createdAt,
      });

      for (final it in preparedItems) {
        await txn.insert('sale_items', {
          'id': it['id'],
          'sale_id': saleId,
          'product_id': it['product_id'],
          'name': it['name'],
          'sku': it['sku'],
          'quantity': it['quantity'],
          'price': it['price'],
          'cost': it['cost'],
          'line_discount': it['line_discount'],
          'subtotal': it['subtotal'],
          'profit': it['profit'],
        });

        final productId = it['product_id']?.toString();
        if (productId != null && productId.isNotEmpty) {
          final cur = await txn.query('products',
              where: 'id = ?', whereArgs: [productId], limit: 1);
          if (cur.isNotEmpty) {
            final current = (cur.first['stock'] as int);
            final newStock = current - (it['quantity'] as int);
            await txn.update('products', {'stock': newStock, 'updated_at': nowIso()},
                where: 'id = ?', whereArgs: [productId]);
            await txn.insert('inventory_movements', {
              'id': genId(),
              'product_id': productId,
              'delta': -(it['quantity'] as int),
              'note': 'venta $saleId',
              'created_at': nowIso(),
            });
          }
        }
      }
    });

    return saleId;
  }

  Future<List<Map<String, Object?>>> history({
    String? customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (customerId != null && customerId.isNotEmpty) {
      where.add('s.customer_id = ?');
      args.add(customerId);
    }
    if (from != null && to != null) {
      where.add('s.created_at BETWEEN ? AND ?');
      args.add(from.toIso8601String());
      args.add(to.toIso8601String());
    }

    return db.rawQuery('''
      SELECT s.*, c.name AS customer_name
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY s.created_at DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> topCustomers(
      DateTime from, DateTime to) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        s.customer_id,
        COALESCE(c.name, 'Mostrador') AS name,
        COUNT(*) AS orders,
        SUM(s.total)  AS total,
        SUM(s.profit) AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at BETWEEN ? AND ?
      GROUP BY s.customer_id, c.name
      ORDER BY total DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  Future<Map<String, Object?>> summary(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        SUM(total)  AS total,
        SUM(discount) AS discount,
        SUM(shipping_cost) AS shipping_cost,
        SUM(profit) AS profit
      FROM sales
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final m = rows.isNotEmpty ? rows.first : <String, Object?>{};
    final total = (m['total'] as num?)?.toDouble() ?? 0.0;
    final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
    final discount = (m['discount'] as num?)?.toDouble() ?? 0.0;
    final shipping = (m['shipping_cost'] as num?)?.toDouble() ?? 0.0;
    final pct = total > 0 ? (profit / total) * 100.0 : 0.0;
    return {
      'total': total,
      'discount': discount,
      'shipping_cost': shipping,
      'profit': profit,
      'profit_pct': pct,
    };
  }
}
