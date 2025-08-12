class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double price;
  final double costAtSale;
  final double lineDiscount;
  final double subtotal;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.costAtSale,
    this.lineDiscount = 0,
  }) : subtotal = (price * quantity - lineDiscount) < 0 ? 0 : (price * quantity - lineDiscount);

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        id: m['id'] as String,
        saleId: m['sale_id'] as String,
        productId: m['product_id'] as String,
        quantity: (m['quantity'] as num).toInt(),
        price: (m['price'] as num).toDouble(),
        costAtSale: (m['cost_at_sale'] as num?)?.toDouble() ?? 0,
        lineDiscount: (m['line_discount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'price': price,
        'cost_at_sale': costAtSale,
        'line_discount': lineDiscount,
        'subtotal': subtotal,
      };
}
