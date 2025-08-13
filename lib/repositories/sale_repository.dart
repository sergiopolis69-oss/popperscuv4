// lib/repositories/sale_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<Database> _db() => AppDatabase().database;

  /// Crea una venta con sus items. `sale` e `items` son Maps (POS ya los arma).
  /// - shipping se suma al total pero **no** afecta la utilidad.
  Future<void> create(
    Map<String, Object?> sale,
    List<Map<String, Object?>> items,
  ) async {
    final db = await _db();
    await db.transaction((txn) async {
      final saleId = (sale['id'] as String?) ?? _uuid.v4();

      // Recalcular utilidad si no viene (o viene 0)
      double profit = (sale['profit'] as num?)?.toDouble() ?? 0.0;
      if (profit <= 0) {
        for (final it in items) {
          final qty = (it['quantity'] as num?)?.toInt() ?? 0;
          final price = (it['price'] as num?)?.toDouble() ?? 0.0;
          final cost = (it['costAtSale'] as num?)?.toDouble() ?? 0.0;
          final lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
          final line = (price * qty) - lineDiscount - (cost * qty);
          profit += line < 0 ? 0 : line;
        }
      }

      // Total = suma subtotales + shipping (si POS no lo calculó)
      final shipping = (sale['shipping'] as num?)?.toDouble() ?? 0.0;
      final totalFromItems = items.fold<double>(0.0, (acc, it) {
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
        final sub = (price * qty) - lineDiscount;
        return acc + (sub < 0 ? 0 : sub);
      });

      final total = (sale['total'] as num?)?.toDouble() ?? (totalFromItems + shipping);

      // Inserta venta
      await txn.insert('sales', {
        'id': saleId,
        'customerId': sale['customerId'],
        'total': total,
        'discount': (sale['discount'] as num?)?.toDouble() ?? 0.0,
        'shipping': shipping,
        'profit': profit, // OJO: ya excluye envío
        'paymentMethod': (sale['paymentMethod'] as String?) ?? 'Efectivo',
        'createdAt': (sale['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      });

      // Inserta items, descuenta stock y registra movimiento
      for (final it in items) {
        final itId = (it['id'] as String?) ?? _uuid.v4();
        final productId = (it['productId'] as String?) ?? '';
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final cost = (it['costAtSale'] as num?)?.toDouble() ?? 0.0;
        final lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
        final subtotal = (price * qty) - lineDiscount;

        if (productId.isEmpty) {
          throw StateError('Falta productId en un item de venta');
        }

        await txn.insert('sale_items', {
          'id': itId,
          'saleId': saleId,
          'productId': productId,
          'quantity': qty,
          'price': price,
          'costAtSale': cost,
          'lineDiscount': lineDiscount,
          'subtotal': subtotal < 0 ? 0 : subtotal,
          'createdAt': DateTime.now().toIso8601String(),
        });

        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [qty, productId],
        );

        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'productId': productId,
          'quantity': -qty,
          'reason': 'SALE',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Historial de ventas (opcional por cliente) en un rango.
  Future<List<Map<String, Object?>>> history({
    String? customerId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db();
    final fromIso = DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

    final args = <Object?>[fromIso, toIso];
    final where = StringBuffer('s.createdAt BETWEEN ? AND ?');
    if (customerId != null) {
      where.write(' AND s.customerId = ?');
      args.add(customerId);
    }

    return db.rawQuery('''
      SELECT s.id, s.customerId, s.total, s.discount, s.shipping, s.profit,
             s.paymentMethod, s.createdAt,
             (SELECT COUNT(*) FROM sale_items si WHERE si.saleId = s.id) AS items
      FROM sales s
      WHERE $where
      ORDER BY s.createdAt DESC
    ''', args);
  }

  /// Top clientes por rango (para TopCustomersPage).
  Future<List<Map<String, Object?>>> topCustomers(DateTime from, DateTime to) async {
    final db = await _db();
    final fromIso = DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

    return db.rawQuery('''
      SELECT s.customerId,
             COALESCE(c.name, 'Mostrador') AS name,
             COUNT(*) AS orders,
             SUM(s.total)  AS total,
             SUM(s.profit) AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customerId
      WHERE s.createdAt BETWEEN ? AND ?
      GROUP BY s.customerId, c.name
      ORDER BY total DESC
    ''', [fromIso, toIso]);
  }

  /// Resumen (ventas, utilidad, etc.) para el módulo de utilidad.
  Future<Map<String, double>> summary(DateTime from, DateTime to) async {
    final db = await _db();
    final fromIso = DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total),0)    AS total,
             COALESCE(SUM(profit),0)   AS profit,
             COALESCE(SUM(discount),0) AS discount,
             COALESCE(SUM(shipping),0) AS shipping,
             COUNT(*) AS orders
      FROM sales
      WHERE createdAt BETWEEN ? AND ?
    ''', [fromIso, toIso]);

    final m = rows.isNotEmpty ? rows.first : <String, Object?>{};
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;

    return {
      'total': d('total'),
      'profit': d('profit'),
      'discount': d('discount'),
      'shipping': d('shipping'),
      // orders como double para graficar fácil; convierte a int si lo necesitas
      'orders': (m['orders'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
      final shipping = (sale['shippingCost'] as num?)?.toDouble() ?? 0.0;
      double total = (sale['total'] as num?)?.toDouble() ?? (subtotal - discount + shipping);
      if (total < 0) total = 0;

      await txn.insert('sales', {
        'id': saleId,
        'customer_id': sale['customerId'],
        'total': total,
        'discount': discount,
        'shipping_cost': shipping, // no afecta utilidad
        'profit': profit,
        'payment_method': sale['paymentMethod']?.toString() ?? 'Efectivo',
        'created_at': (sale['createdAt'] ?? DateTime.now()).toString(),
      });

      for (final it in items) {
        final itemId = it['id']?.toString() ?? _uuid.v4();
        final qty = (it['quantity'] as num).toInt();
        final price = (it['price'] as num).toDouble();
        final cost = (it['costAtSale'] as num?)?.toDouble() ?? 0.0;
        final lineDisc = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
        final lineSubtotal = (price * qty) - lineDisc;

        await txn.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': it['productId'],
          'quantity': qty,
          'price': price,
          'cost_at_sale': cost,
          'line_discount': lineDisc,
          'subtotal': lineSubtotal < 0 ? 0.0 : lineSubtotal,
        });

        // stock
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [qty, it['productId']],
        );

        // movimiento de inventario (opcional)
        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'product_id': it['productId'],
          'delta': -qty,
          'note': 'Venta $saleId',
          'created_at': DateTime.now().toString(),
        });
      }

      return saleId;
    });
  }

  // --- Si ya usabas estos, déjalos; si no, puedes agregarlos:

  /// Resumen entre fechas: total y utilidad agregada.
  Future<Map<String, double>> summary(DateTime from, DateTime to) async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery(
      'SELECT SUM(total) AS t, SUM(profit) AS p FROM sales WHERE datetime(created_at) BETWEEN ? AND ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    final m = rows.isNotEmpty ? rows.first : <String, Object?>{};
    return {
      'total': (m['t'] as num?)?.toDouble() ?? 0.0,
      'profit': (m['p'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Historial de ventas (opcional, si lo usas en reportes)
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
      where.add('datetime(created_at) >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('datetime(created_at) <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'datetime(created_at) DESC',
    );
    return rows;
  }
}
