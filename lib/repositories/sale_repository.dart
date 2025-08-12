
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  /// Crea una venta. `items` debe contener mapas con:
  /// { productId, quantity, price, costAtSale, lineDiscount }
  Future<String> createSale({
    String? customerId,
    required String paymentMethod,
    double discount = 0.0,
    double shippingCost = 0.0,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await AppDatabase().database;

    double subtotal = 0.0;
    double costTotal = 0.0;
    for (final it in items) {
      final int quantity = (it['quantity'] as num).toInt();
      final double price = (it['price'] as num).toDouble();
      final double lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
      final double cost = (it['costAtSale'] as num).toDouble();
      final line = (price * quantity) - lineDiscount;
      if (line > 0) subtotal += line;
      costTotal += (cost * quantity);
    }
    if (subtotal < 0) subtotal = 0.0;

    final total = (subtotal - discount + shippingCost);
    final profit = (subtotal - discount - costTotal);
    final saleId = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert('sales', {
        'id': saleId,
        'customer_id': customerId,
        'total': total < 0 ? 0 : total,
        'discount': discount < 0 ? 0 : discount,
        'profit': profit < 0 ? 0 : profit,
        'shipping_cost': shippingCost < 0 ? 0 : shippingCost,
        'payment_method': paymentMethod,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final it in items) {
        final id = _uuid.v4();
        final int quantity = (it['quantity'] as num).toInt();
        final double price = (it['price'] as num).toDouble();
        final double lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
        final double cost = (it['costAtSale'] as num).toDouble();
        final String productId = it['productId'] as String;
        final subtotalLine = (price * quantity) - lineDiscount;

        await txn.insert('sale_items', {
          'id': id,
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'price': price,
          'cost_at_sale': cost,
          'line_discount': lineDiscount,
          'subtotal': subtotalLine < 0 ? 0 : subtotalLine,
        });

        // Actualiza stock
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [quantity, productId],
        );

        // Movimiento de inventario
        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'product_id': productId,
          'delta': -quantity,
          'reason': 'sale',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    return saleId;
  }

  /// Historial de ventas (opcionalmente por cliente y rango de fechas)
  Future<List<Map<String, Object?>>> history({
    String? customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase().database;
    final where = <String>[];
    final args = <Object?>[];
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    if (from != null) {
      where.add("datetime(created_at) >= datetime(?)");
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add("datetime(created_at) <= datetime(?)");
      args.add(to.toIso8601String());
    }
    final sql = StringBuffer('SELECT * FROM sales');
    if (where.isNotEmpty) {
      sql.write(' WHERE ' + where.join(' AND '));
    }
    sql.write(' ORDER BY datetime(created_at) DESC');
    return db.rawQuery(sql.toString(), args);
  }

  /// Mejores clientes por rango
  Future<List<Map<String, Object?>>> topCustomers(DateTime from, DateTime to) async {
    final db = await AppDatabase().database;
    return db.rawQuery('''
      SELECT c.id as customer_id, c.name as customer_name,
             COUNT(s.id) as orders, COALESCE(SUM(s.total),0) as total, COALESCE(SUM(s.profit),0) as profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE datetime(s.created_at) >= datetime(?) AND datetime(s.created_at) <= datetime(?)
      GROUP BY c.id, c.name
      ORDER BY total DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  /// Resumen (ventas, utilidad, descuento, envío) para un rango
  Future<Map<String, double>> summary(DateTime from, DateTime to) async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total),0) as total,
             COALESCE(SUM(profit),0) as profit,
             COALESCE(SUM(discount),0) as discount,
             COALESCE(SUM(shipping_cost),0) as shipping
      FROM sales
      WHERE datetime(created_at) >= datetime(?) AND datetime(created_at) <= datetime(?)
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final r = rows.first;
    return {
      'total': (r['total'] as num).toDouble(),
      'profit': (r['profit'] as num).toDouble(),
      'discount': (r['discount'] as num).toDouble(),
      'shipping': (r['shipping'] as num).toDouble(),
    };
  }
}
