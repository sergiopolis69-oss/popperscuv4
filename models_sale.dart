import 'package:flutter/foundation.dart';

class Sale {
  final String id;
  final String? customerId;
  final double total;
  final double discount;
  final double profit;
  final double shippingCost; // extra, no afecta utilidad
  final String paymentMethod;
  final DateTime createdAt;

  const Sale({
    required this.id,
    this.customerId,
    required this.total,
    required this.discount,
    required this.profit,
    required this.shippingCost,
    required this.paymentMethod,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'profit': profit,
        'shipping_cost': shippingCost,
        'payment_method': paymentMethod,
        'created_at': createdAt.toIso8601String(),
      };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as String,
        customerId: m['customer_id'] as String?,
        total: (m['total'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
        shippingCost: (m['shipping_cost'] == null) ? 0.0 : (m['shipping_cost'] as num).toDouble(),
        paymentMethod: m['payment_method'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
