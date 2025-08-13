// lib/repositories/sale_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();
  Future<Database> _db() => AppDatabase().database;

  /// Crea una venta y sus renglones.
  /// - `shipping` se suma al total pero **no** afecta la utilidad.
  Future<void> create(
    Map<String, Object?> sale,
    List<Map<String, Object?>> items,
  ) async {
    final db = await _db();
    await db.transaction((txn) async {
      final saleId = (sale['id'] as String?) ?? _uuid.v4();

      // Calcular utilidad si no viene.
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

      // Subtotal por items (sin envío)
      final subtotalItems = items.fold<double>(0.0, (acc, it) {
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
        final sub = (price * qty) - lineDiscount;
        return acc + (sub < 0 ? 0 : sub);
      });

      final shipping = (sale['shipping'] as num?)?.toDouble() ?? 0.0;
      final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;

      // Si POS ya mandó total lo respetamos; si no, lo calculamos.
      final total = (sale['total'] as num?)?.toDouble() ??
          ((subtotalItems - discount) + shipping);

      // Insert venta
      await txn.insert('sales', {
        'id': saleId,
        'customerId': sale['customerId'],
        'total': total,
        'discount': discount,
        'shipping': shipping,
        'profit': profit, // excluye envío
        'paymentMethod': (sale['paymentMethod'] as String?) ?? 'Efectivo',
        'createdAt':
            (sale['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      });

      // Insert items + actualizar stock + movimiento
      for (final it in items) {
        final itemId = (it['id'] as String?) ?? _uuid.v4();
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
          'id': itemId,
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

  /// Historial de ventas (opcional filtrado por cliente).
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

  /// Top clientes por rango.
  Future<List<Map<String, Object?>>> topCustomers(
      DateTime from, DateTime to) async {
    final db = await _db();
    final fromIso =
        DateTime(from.year, from.month, from.day).toIso8601String();
    final toIso =
        DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toIso8601String();

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

  /// Resumen de utilidad/ventas para día, semana, mes, año.
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
      WHERE createdAt BETWEEN ? AND ?
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
