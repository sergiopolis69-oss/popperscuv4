import 'purchase_item.dart';
import 'payment_method.dart';

class Purchase {
  final int? id;
  final int supplierId;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final String? notes;
  final bool isCanceled;
  final List<PurchaseItem> items;

  Purchase({
    this.id,
    required this.supplierId,
    required this.createdAt,
    required this.paymentMethod,
    this.notes,
    this.isCanceled = false,
    required this.items,
  });

  double get subtotal => items.where((it) => !it.isCanceled).fold(0.0, (s, it) => s + it.lineTotal);

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplier_id': supplierId,
    'created_at': createdAt.toIso8601String(),
    'payment_method': paymentMethod.dbValue,
    'notes': notes,
    'is_canceled': isCanceled ? 1 : 0,
    'subtotal': subtotal,
  };
}
