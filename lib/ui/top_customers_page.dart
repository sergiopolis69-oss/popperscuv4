// lib/repositories/sale_repository.dart
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<Database> get _db async => AppDatabase().database;

  // Alias por compatibilidad: algunos lugares llaman create(...).
  Future<void> create(
    Map<String, Object?> sale,
    List<Map<String, Object?>> items,
  ) =>
      save(sale, items);

  /// Guarda una venta con sus items.
  /// Espera:
  /// sale: { customerId?, discount?, paymentMethod?, shippingCost?, createdAt? ... }
  /// items: [ { productId, quantity, price, costAtSale, lineDiscount? } ... ]
  Future<void> save(
    Map<String, Object?> sale,
    List<Map<String, Object?>> items,
  ) async {
    final db = await _db;

    await db.transaction((txn) async {
      final saleId = (sale['id'] as String?) ?? _uuid.v4();

      // Calcular importes desde los items
      double subtotal = 0;
      double costTotal = 0;

      for (final it in items) {
        final q = (it['quantity'] as num?)?.toInt() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final lineDiscount = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
        final costAtSale = (it['costAtSale'] as num?)?.toDouble() ?? 0.0;

        final sub = max(0.0, price * q - lineDiscount);
        it['subtotal'] = sub; // por si lo necesitas después
        subtotal += sub;
        costTotal += costAtSale * q;
      }

      final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
      final shipping = (sale['shippingCost'] as num?)?.toDouble() ?? 0.0;

      // Total SIN envío (para utilidad) y total final CON envío.
      final totalNoShipping = max(0.0, subtotal - discount);
      final total = totalNoShipping + shipping;
      final profit = totalNoShipping - costTotal; // envío NO afecta utilidad

      final customerId = sale['customerId'] as String?;
      final paymentMethod = (sale['paymentMethod'] as String?) ?? 'Efectivo';
      final createdAt =
          (sale['createdAt'] as String?) ?? DateTime.now().toIso8601String();

      // Si existe columna shipping_cost la usamos; si no, insertamos sin ella.
      final hasShipping = await _tableHasColumn(txn, 'sales', 'shipping_cost');

      final salesRow = <String, Object?>{
        'id': saleId,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'profit': profit,
        'payment_method': paymentMethod,
        'created_at': createdAt,
      };
      if (hasShipping) salesRow['shipping_cost'] = shipping;

      await txn.insert('sales', salesRow);

      // Insertar items y actualizar inventario
      for (final it in items) {
        final itemId = (it['id'] as String?) ?? _uuid.v4();
        final pid = it['productId'];
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;

        await txn.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': pid,
          'quantity': qty,
          'price': (it['price'] as num?)?.toDouble() ?? 0.0,
          'cost_at_sale': (it['costAtSale'] as num?)?.toDouble() ?? 0.0,
          'line_discount': (it['lineDiscount'] as num?)?.toDouble() ?? 0.0,
          'subtotal': (it['subtotal'] as num?)?.toDouble() ?? 0.0,
        });

        // stock --
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [qty, pid],
        );

        // movimiento de inventario si existe la tabla
        if (await _tableExists(txn, 'inventory_movements')) {
          await txn.insert('inventory_movements', {
            'id': _uuid.v4(),
            'product_id': pid,
            'delta': -qty,
            'reason': 'sale',
            'created_at': createdAt,
          });
        }
      }
    });
  }

  /// Historial de ventas (opcionalmente filtrado por cliente)
  /// Devuelve filas agregadas por venta (con #items).
  Future<List<Map<String, Object?>>> history({
    String? customerId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;

    final params = <Object?>[
      from.toIso8601String(),
      to.toIso8601String(),
      if (customerId != null) customerId,
    ];

    final rows = await db.rawQuery('''
      SELECT
        s.id,
        s.customer_id                    AS customerId,
        COALESCE(c.name, 'Mostrador')    AS customerName,
        s.total,
        s.discount,
        s.profit,
        s.payment_method                 AS paymentMethod,
        COALESCE(s.shipping_cost, 0)     AS shippingCost,
        s.created_at                     AS createdAt,
        COUNT(si.id)                     AS items
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      LEFT JOIN sale_items si ON si.sale_id = s.id
      WHERE s.created_at BETWEEN ? AND ?
        ${customerId == null ? '' : 'AND s.customer_id = ?'}
      GROUP BY s.id, s.customer_id, c.name, s.total, s.discount, s.profit,
               s.payment_method, s.shipping_cost, s.created_at
      ORDER BY s.created_at DESC
      LIMIT 500
    ''', params);

    return rows;
  }

  /// Resumen (totales, utilidad, etc.) entre fechas.
  Future<Map<String, Object?>> summary(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        ROUND(SUM(total), 2)                         AS total,
        ROUND(SUM(discount), 2)                      AS discount,
        ROUND(SUM(COALESCE(shipping_cost, 0)), 2)    AS shipping,
        ROUND(SUM(profit), 2)                        AS profit,
        COUNT(*)                                     AS orders
      FROM sales
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    return rows.isNotEmpty
        ? rows.first
        : {'total': 0, 'discount': 0, 'shipping': 0, 'profit': 0, 'orders': 0};
  }

  /// Top clientes por total/profit entre fechas.
  Future<List<Map<String, Object?>>> topCustomers(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(s.customer_id, 'NO_ID') AS customerId,
        COALESCE(c.name, 'Mostrador')    AS name,
        COUNT(*)                         AS orders,
        ROUND(SUM(s.total), 2)           AS total,
        ROUND(SUM(s.profit), 2)          AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at BETWEEN ? AND ?
      GROUP BY COALESCE(s.customer_id, 'NO_ID'), COALESCE(c.name, 'Mostrador')
      ORDER BY total DESC
      LIMIT 50
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows;
  }

  // ===== Helpers =====
  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _tableHasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in info) {
      if ((row['name'] as String?) == column) return true;
    }
    return false;
  }
}
