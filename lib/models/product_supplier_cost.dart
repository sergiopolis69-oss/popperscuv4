class ProductSupplierCost {
  final int? id;
  final int productId;
  final int supplierId;
  final double lastCost;
  final double averageCost;
  final int samples;

  ProductSupplierCost({
    this.id,
    required this.productId,
    required this.supplierId,
    required this.lastCost,
    required this.averageCost,
    required this.samples,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'supplier_id': supplierId,
    'last_cost': lastCost,
    'average_cost': averageCost,
    'samples': samples,
  };

  static ProductSupplierCost fromMap(Map<String, dynamic> m) => ProductSupplierCost(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    supplierId: m['supplier_id'] as int,
    lastCost: (m['last_cost'] as num).toDouble(),
    averageCost: (m['average_cost'] as num).toDouble(),
    samples: m['samples'] as int,
  );
}
