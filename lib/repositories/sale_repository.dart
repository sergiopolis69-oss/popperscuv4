import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();
  Future<Database> _db() => AppDatabase().database;

  // Crea la venta + renglones. `shipping` se suma al total pero NO afecta utilidad.
  Future<void> create(
    Map<String, Object?> sale,
    List<Map<String, Object?>> items,
  ) async {
    final db = await _db();

    // Lectura tolerante de claves que pueden venir camelCase o snake_case:
    T? _get<T>(Map m, String a, String b) =>
        (m[a] as T?) ?? (m[b] as T?);

    final saleId = _get<String>(sale, 'id', 'id') ?? _uuid.v4();
    final customerId = _get<String>(sale, 'customerId', 'customer_id');
    final paymentMethod =
        _get<String>(sale, 'paymentMethod', 'payment_method') ?? 'Efectivo';
    final createdAt =
        _get<String>(sale, 'createdAt', 'created_at') ??
            DateTime.now().toIso8601String();

    final discount = (_get<num>(sale, 'discount', 'discount') ?? 0).toDouble();
    final shipping = (_get<num>(sale, 'shipping', 'shipping') ??
            _get<num>(sale, 'shippingCost', 'shipping_cost') ??
            0)
        .toDouble();

    // Calcular utilidad por items (sin incluir envío).
    double profit = (_get<num>(sale, 'profit', 'profit') ?? 0).toDouble();
    if (profit <= 0) {
      for (final it in items) {
        final qty = (_get<num>(it, 'quantity', 'quantity') ?? 0).toInt();
        final price = (_get<num>(it, 'price', 'price') ?? 0).toDouble();
        final cost = (_get<num>(it, 'costAtSale', 'cost_at_sale') ?? 0).toDouble();
        final lineDiscount =
            (_get<num>(it, 'lineDiscount', 'line_discount') ?? 0).toDouble();
        final line = (price * qty) - lineDiscount - (cost * qty);
        if (line > 0) profit += line;
      }
    }

    // Subtotal por items (sin envío)
    final subtotalItems = items.fold<double>(0.0, (acc, it) {
      final qty = (_get<num>(it, 'quantity', 'quantity') ?? 0).toInt();
      final price = (_get<num>(it, 'price', 'price') ?? 0).toDouble();
      final lineDiscount =
          (_get<num>(it, 'lineDiscount', 'line_discount') ?? 0).toDouble();
      final sub = (price * qty) - lineDiscount;
      return acc + (sub < 0 ? 0 : sub);
    });

    final total =
        (_get<num>(sale, 'total', 'total')?.toDouble()) ??
            ((subtotalItems - discount) + shipping);

    await db.transaction((txn) async {
      // Insert venta
      await txn.insert('sales', {
        'id': saleId,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'shipping': shipping, // columna en snake_case
        'profit': profit,     // utilidad sin envío
        'payment_method': paymentMethod,
        'created_at': createdAt,
      });

      // Items + stock + movimientos
      for (final it in items) {
        final itemId = _get<String>(it, 'id', 'id') ?? _uuid.v4();
        final productId = _get<String>(it, 'productId', 'product_id') ?? '';
        final qty = (_get<num>(it, 'quantity', 'quantity') ?? 0).toInt();
        final price = (_get<num>(it, 'price', 'price') ?? 0).toDouble();
        final cost = (_get<num>(it, 'costAtSale', 'cost_at_sale') ?? 0).toDouble();
        final lineDiscount =
            (_get<num>(it, 'lineDiscount', 'line_discount') ?? 0).toDouble();
        final subtotal = (price * qty) - lineDiscount;

        if (productId.isEmpty) {
          throw StateError('Falta product_id en un item de venta');
        }

        await txn.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': productId,
          'quantity': qty,
          'price': price,
          'cost_at_sale': cost,
          'line_discount': lineDiscount,
          'subtotal': subtotal < 0 ? 0 : subtotal,
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [qty, productId],
        );

        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'product_id': productId,
          'quantity': -qty,
          'reason': 'SALE',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> topCustomers(
      DateTime from, DateTime to) async {
    final db = await _db();
    final fromIso =
        DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso =
        DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

    return db.rawQuery('''
      SELECT s.customer_id,
             COALESCE(c.name, 'Mostrador') AS name,
             COUNT(*) AS orders,
             SUM(s.total)  AS total,
             SUM(s.profit) AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at BETWEEN ? AND ?
      GROUP BY s.customer_id, c.name
      ORDER BY total DESC
    ''', [fromIso, toIso]);
  }

  Future<List<Map<String, Object?>>> history({
    String? customerId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db();
    final fromIso =
        DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso =
        DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

    final args = <Object?>[fromIso, toIso];
    final where = StringBuffer('s.created_at BETWEEN ? AND ?');
    if (customerId != null) {
      where.write(' AND s.customer_id = ?');
      args.add(customerId);
    }

    return db.rawQuery('''
      SELECT s.id, s.customer_id, s.total, s.discount, s.shipping, s.profit,
             s.payment_method, s.created_at,
             (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) AS items
      FROM sales s
      WHERE $where
      ORDER BY s.created_at DESC
    ''', args);
  }

  Future<Map<String, double>> summary(DateTime from, DateTime to) async {
    final db = await _db();
    final fromIso =
        DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso =
        DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total),0)    AS total,
             COALESCE(SUM(profit),0)   AS profit,
             COALESCE(SUM(discount),0) AS discount,
             COALESCE(SUM(shipping),0) AS shipping,
             COUNT(*) AS orders
      FROM sales
      WHERE created_at BETWEEN ? AND ?
    ''', [fromIso, toIso]);

    final m = rows.isNotEmpty ? rows.first : <String, Object?>{};
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;

    return {
      'total': d('total'),
      'profit': d('profit'),
      'discount': d('discount'),
      'shipping': d('shipping'),
      'orders': (m['orders'] as num?)?.toDouble() ?? 0.0,
    };
  }
}