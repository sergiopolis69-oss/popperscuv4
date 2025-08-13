// lib/repositories/sale_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<Database> get _db async => AppDatabase().database;

  /// Crea una venta y sus items en una transacción.
  /// [sale] espera:
  /// { id, customerId?, total(double), discount(double), shipping(double),
  ///   paymentMethod(String), profit(double), createdAt(String ISO) }
  /// [items] espera una lista de maps con:
  /// { id?, productId, name, price(double), costAtSale(double),
  ///   quantity(int), lineDiscount(double), subtotal(double?) }
  Future<String> create(
    Map<String, Object?> sale,
    List<Map<String, Object?>> items,
  ) async {
    final db = await _db;

    // Asegura ID y createdAt
    final saleId = (sale['id'] as String?) ?? _uuid.v4();
    final createdAt = (sale['createdAt'] as String?) ??
        DateTime.now().toIso8601String();

    // Normaliza numéricos
    double _toD(Object? v) => (v as num?)?.toDouble() ?? 0.0;
    int _toI(Object? v) => (v as num?)?.toInt() ?? 0;

    await db.transaction((txn) async {
      // Inserta venta
      await txn.insert('sales', {
        'id': saleId,
        'customerId': sale['customerId'],
        'total': _toD(sale['total']),
        'discount': _toD(sale['discount']),
        'shipping': _toD(sale['shipping']),
        'paymentMethod': sale['paymentMethod'] ?? 'Efectivo',
        'profit': _toD(sale['profit']),
        'createdAt': createdAt,
      });

      // Inserta items y afecta inventario
      for (final it in items) {
        final itemId = (it['id'] as String?) ?? _uuid.v4();
        final productId = (it['productId'] as String?) ?? '';
        final quantity = _toI(it['quantity']);
        final price = _toD(it['price']);
        final costAtSale = _toD(it['costAtSale']);
        final lineDiscount = _toD(it['lineDiscount']);
        final subtotal =
            (it['subtotal'] as num?)?.toDouble() ?? (price * quantity - lineDiscount);

        // Guarda item
        await txn.insert('sale_items', {
          'id': itemId,
          'saleId': saleId,
          'productId': productId,
          'quantity': quantity,
          'price': price,
          'costAtSale': costAtSale,
          'lineDiscount': lineDiscount,
          'subtotal': subtotal < 0 ? 0.0 : subtotal,
        });

        // Descuenta stock
        if (productId.isNotEmpty && quantity > 0) {
          await txn.rawUpdate(
            'UPDATE products SET stock = MAX(0, stock - ?) WHERE id = ?',
            [quantity, productId],
          );

          // (Opcional) registra movimiento de inventario si tienes esta tabla
          // Ignora si no existe.
          try {
            await txn.insert('inventory_movements', {
              'id': _uuid.v4(),
              'productId': productId,
              'change': -quantity,
              'reason': 'sale:$saleId',
              'createdAt': createdAt,
            });
          } catch (_) {/* tabla opcional */}
        }
      }
    });

    return saleId;
  }

  /// Historial de ventas (solo cabeceras), filtrable por cliente/fechas
  /// Regresa una lista de maps con columnas de `sales`.
  Future<List<Map<String, Object?>>> history({
    String? customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;

    final where = <String>[];
    final args = <Object?>[];

    if (customerId != null && customerId.isNotEmpty) {
      where.add('customerId = ?');
      args.add(customerId);
    }
    if (from != null) {
      where.add('createdAt >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('createdAt <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'createdAt DESC',
    );
    return rows;
  }

  /// Mejores clientes entre fechas (sumas de total y utilidad, y conteo)
  /// Retorna: id, name(opcional si existe tabla customers), orders, total, profit
  Future<List<Map<String, Object?>>> topCustomers(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db;

    // Intenta usar tabla customers si existe; si no, solo agrupa por customerId
    try {
      // Con join a customers
      final rows = await db.rawQuery('''
        SELECT s.customerId AS id,
               COALESCE(c.name, s.customerId) AS name,
               COUNT(*) AS orders,
               SUM(s.total) AS total,
               SUM(s.profit) AS profit
        FROM sales s
        LEFT JOIN customers c ON c.id = s.customerId
        WHERE s.createdAt >= ? AND s.createdAt <= ? AND s.customerId IS NOT NULL
        GROUP BY s.customerId
        ORDER BY total DESC
      ''', [from.toIso8601String(), to.toIso8601String()]);
      return rows;
    } catch (_) {
      // Sin join
      final rows = await db.rawQuery('''
        SELECT s.customerId AS id,
               s.customerId AS name,
               COUNT(*) AS orders,
               SUM(s.total) AS total,
               SUM(s.profit) AS profit
        FROM sales s
        WHERE s.createdAt >= ? AND s.createdAt <= ? AND s.customerId IS NOT NULL
        GROUP BY s.customerId
        ORDER BY total DESC
      ''', [from.toIso8601String(), to.toIso8601String()]);
      return rows;
    }
  }

  /// Resumen de periodo (para la vista de utilidades)
  /// Retorna: { total, profit, orders }
  Future<Map<String, Object?>> summary(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT IFNULL(SUM(total),0) AS total,
             IFNULL(SUM(profit),0) AS profit,
             COUNT(*) AS orders
      FROM sales
      WHERE createdAt >= ? AND createdAt <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);
    if (rows.isEmpty) {
      return {'total': 0.0, 'profit': 0.0, 'orders': 0};
    }
    return rows.first;
  }
}
