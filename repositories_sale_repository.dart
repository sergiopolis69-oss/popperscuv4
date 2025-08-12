import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<String> createSale({
    String? customerId,
    required String paymentMethod,
    double discount = 0.0,
    double shippingCost = 0.0,
    required List<SaleItem> items,
  }) async {
    final db = await AppDatabase().database;

    double subtotal = 0.0;
    double costTotal = 0.0;
    for (final it in items) {
      final line = (it.price * it.quantity) - it.lineDiscount;
      if (line > 0) subtotal += line;
      costTotal += (it.costAtSale * it.quantity);
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
        final subtotalLine = (it.price * it.quantity) - it.lineDiscount;
        await txn.insert('sale_items', {
          'id': id,
          'sale_id': saleId,
          'product_id': it.productId,
          'quantity': it.quantity,
          'price': it.price,
          'cost_at_sale': it.costAtSale,
          'line_discount': it.lineDiscount,
          'subtotal': subtotalLine < 0 ? 0 : subtotalLine,
        });

        // Actualiza stock
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [it.quantity, it.productId],
        );

        // Movimiento de inventario
        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'product_id': it.productId,
          'delta': -it.quantity,
          'reason': 'sale',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    return saleId;
  }
}
