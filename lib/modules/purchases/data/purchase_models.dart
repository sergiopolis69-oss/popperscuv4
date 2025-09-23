// (same as before)
import 'package:flutter/foundation.dart';

@immutable
class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;

  const Supplier({this.id, required this.name, this.phone, this.email, this.notes});

  Supplier copyWith({int? id, String? name, String? phone, String? email, String? notes}) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        notes: notes ?? this.notes,
      );

  static Supplier fromMap(Map<String, Object?> m) => Supplier(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        notes: m['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
      };
}

enum PaymentMethod { cash, card, transfer, other }

@immutable
class Purchase {
  final int? id;
  final int supplierId;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final double total;

  const Purchase({
    this.id,
    required this.supplierId,
    required this.date,
    required this.paymentMethod,
    required this.total,
  });

  static Purchase fromMap(Map<String, Object?> m) => Purchase(
        id: m['id'] as int?,
        supplierId: m['supplier_id'] as int,
        date: DateTime.parse(m['date'] as String),
        paymentMethod: PaymentMethod.values[m['payment_method'] as int],
        total: (m['total'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'date': date.toIso8601String(),
        'payment_method': paymentMethod.index,
        'total': total,
      };
}

@immutable
class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int productId;
  final double qty;
  final double unitCost;

  const PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.productId,
    required this.qty,
    required this.unitCost,
  });

  static PurchaseItem fromMap(Map<String, Object?> m) => PurchaseItem(
        id: m['id'] as int?,
        purchaseId: m['purchase_id'] as int,
        productId: m['product_id'] as int,
        qty: (m['qty'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'purchase_id': purchaseId,
        'product_id': productId,
        'qty': qty,
        'unit_cost': unitCost,
      };

  PurchaseItem copyWith({int? id, int? purchaseId, int? productId, double? qty, double? unitCost}) =>
      PurchaseItem(
        id: id ?? this.id,
        purchaseId: purchaseId ?? this.purchaseId,
        productId: productId ?? this.productId,
        qty: qty ?? this.qty,
        unitCost: unitCost ?? this.unitCost,
      );
}
