import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  /// Guarda una venta y sus renglones.
  /// `sale` debe traer: customerId (opcional), discount, shippingCost, paymentMethod (opcional), createdAt (opcional)
  /// `items` debe traer por renglón: productId, quantity, price, costAtSale (opcional), lineDiscount (opcional)
  Future<String> save(
    Map<String, dynamic> sale,
    List<Map<String, dynamic>> items,
  ) async {
    final Database db = await AppDatabase().database;

    return await db.transaction((txn) async {
      final String saleId = sale['id']?.toString() ?? _uuid.v4();

      // Subtotales de líneas
      double subtotal = 0;
      double profit = 0;
      for (final it in items) {
        final qty = (it['quantity'] as num).toInt();
        final price = (it['price'] as num).toDouble();
        final cost = (it['costAtSale'] as num?)?.toDouble() ?? 0.0;
        final lineDisc = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;

        final lineSubtotal = (price * qty) - lineDisc;
        subtotal += lineSubtotal < 0 ? 0.0 : lineSubtotal;

        // utilidad = (precio - costo) * qty - descuento_linea (no restamos envío)
        profit += ((price - cost) * qty) - lineDisc;
      }

      final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
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
