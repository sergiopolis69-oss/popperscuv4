class PurchaseItem {
  final int? id;
  final int productId;
  final double quantity;
  final double unitCost;
  final bool isCanceled;

  PurchaseItem({
    this.id,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    this.isCanceled = false,
  });

  double get lineTotal => quantity * unitCost;

  Map<String, dynamic> toMap(int purchaseId) => {
    'id': id,
    'purchase_id': purchaseId,
    'product_id': productId,
    'quantity': quantity,
    'unit_cost': unitCost,
    'line_total': lineTotal,
    'is_canceled': isCanceled ? 1 : 0,
  };

  static PurchaseItem fromMap(Map<String, dynamic> m) => PurchaseItem(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    quantity: (m['quantity'] as num).toDouble(),
    unitCost: (m['unit_cost'] as num).toDouble(),
    isCanceled: (m['is_canceled'] as int? ?? 0) == 1,
  );
}
