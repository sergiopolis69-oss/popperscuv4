import 'package:uuid/uuid.dart';
import '../services/db.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<void> createSale({
    String? customerId,
    required List<SaleItem> items,
    required double discount,
    required String paymentMethod,
  }) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      double subtotal = 0;
      double costTotal = 0;
      for (final it in items) {
        subtotal += it.subtotal;
        costTotal += (it.costAtSale * it.quantity);
      }
      double total = subtotal - discount;
      if (total < 0) total = 0;
      final profit = total - costTotal;

      final saleId = _uuid.v4();
      final sale = Sale(
        id: saleId,
        customerId: customerId,
        total: total,
        discount: discount,
        paymentMethod: paymentMethod,
        profit: profit,
      );
      await txn.insert('sales', sale.toMap());

      for (final it in items) {
        final row = it.toMap();
        row['id'] = _uuid.v4();
        row['sale_id'] = saleId;
        await txn.insert('sale_items', row);
        await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [it.quantity, it.productId]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> history({String? customerId, DateTime? from, DateTime? to}) async {
    final db = await AppDatabase().database;
    final where = <String>[]; final args = <dynamic>[];
    if (customerId != null && customerId.isNotEmpty) { where.add('s.customer_id = ?'); args.add(customerId); }
    if (from != null) { where.add('s.created_at >= ?'); args.add(from.toIso8601String()); }
    if (to != null)   { where.add('s.created_at <= ?'); args.add(to.toIso8601String()); }
    final sql = '''
      SELECT s.id, s.created_at, s.total, s.discount, s.payment_method, s.profit,
             c.name as customer_name
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      ${where.isEmpty ? '' : 'WHERE ' + where.join(' AND ')}
      ORDER BY s.created_at DESC
    ''';
    return db.rawQuery(sql, args);
  }

  Future<List<Map<String, dynamic>>> topCustomers(DateTime from, DateTime to, {int limit = 50}) async {
    final db = await AppDatabase().database;
    final sql = '''
      SELECT s.customer_id, COALESCE(c.name, '(sin cliente)') as customer_name,
             COUNT(*) as orders, SUM(s.total) as spent, SUM(s.profit) as profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at >= ? AND s.created_at <= ?
      GROUP BY s.customer_id, c.name
      ORDER BY spent DESC
      LIMIT ?
    ''';
    return db.rawQuery(sql, [from.toIso8601String(), to.toIso8601String(), limit]);
  }

  Future<Map<String, double>> summary(DateTime from, DateTime to) async {
    final db = await AppDatabase().database;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(total),0) as revenue,
             COALESCE(SUM(profit),0) as profit
      FROM sales
      WHERE created_at >= ? AND created_at <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final row = res.isNotEmpty ? res.first : {'revenue': 0, 'profit': 0};
    final rev = (row['revenue'] as num).toDouble();
    final prof = (row['profit'] as num).toDouble();
    return {'revenue': rev, 'profit': prof};
  }
}
