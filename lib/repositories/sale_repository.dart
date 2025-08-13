
import 'package:uuid/uuid.dart';
import '../services/db.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<void> createSale({
    String? customerId,
    required List<Map<String, dynamic>> items,
    required double total,
    required double discount,
    required double profit,
    required double shipping,
    required String paymentMethod,
  }) async {
    final db = await AppDatabase().database;
    final saleId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('sales', {
        'id': saleId,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'profit': profit,
        'shipping': shipping,
        'payment_method': paymentMethod,
        'created_at': now,
      });

      for (final it in items) {
        final q = (it['quantity'] as num).toInt();
        await txn.insert('sale_items', {
          'id': it['id'] ?? _uuid.v4(),
          'sale_id': saleId,
          'product_id': it['product_id'] ?? it['productId'],
          'quantity': q,
          'price': (it['price'] as num).toDouble(),
          'cost_at_sale': (it['cost_at_sale'] ?? it['cost']) as num,
          'line_discount': (it['line_discount'] ?? 0) as num,
          'subtotal': (it['subtotal'] ?? 0) as num,
        });

        await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [q, it['product_id'] ?? it['productId']]);
        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'product_id': it['product_id'] ?? it['productId'],
          'delta': -q,
          'reason': 'sale',
          'created_at': now,
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> history({String? customerId, DateTime? from, DateTime? to}) async {
    final db = await AppDatabase().database;
    final where = <String>[];
    final args = <Object?>[];

    if (customerId != null) {
      where.add('s.customer_id = ?');
      args.add(customerId);
    }
    if (from != null) {
      where.add('s.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('s.created_at <= ?');
      args.add(to.toIso8601String());
    }

    final sql = '''
      SELECT s.*, c.name AS customer_name
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      ${where.isEmpty ? '' : 'WHERE ' + where.join(' AND ')}
      ORDER BY s.created_at DESC
    ''';

    return db.rawQuery(sql, args);
  }

  Future<List<Map<String, Object?>>> topCustomers(DateTime from, DateTime to) async {
    final db = await AppDatabase().database;
    final sql = '''
      SELECT
        s.customer_id AS customer_id,
        COALESCE(c.name, s.customer_id) AS name,
        COUNT(*) AS orders,
        SUM(s.total) AS total,
        SUM(s.profit) AS profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at >= ? AND s.created_at <= ?
      GROUP BY s.customer_id
      ORDER BY total DESC
      LIMIT 100
    ''';
    return db.rawQuery(sql, [from.toIso8601String(), to.toIso8601String()]);
  }

  Future<Map<String, Object?>> summary(DateTime from, DateTime to) async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery(
      'SELECT SUM(total) AS total, SUM(profit) AS profit FROM sales WHERE created_at >= ? AND created_at <= ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    final m = rows.isNotEmpty ? rows.first : <String, Object?>{};
    final total = (m['total'] as num?)?.toDouble() ?? 0.0;
    final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
    final pct = total == 0 ? 0.0 : (profit / total * 100.0);
    return {
      'total': total,
      'profit': profit,
      'profit_percent': pct,
    };
  }
}
