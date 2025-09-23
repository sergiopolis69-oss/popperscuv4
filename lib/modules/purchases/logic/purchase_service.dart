
import '../data/purchase_models.dart';
import '../data/purchase_repository.dart';

class PurchaseService {
  final PurchaseRepository repo;
  PurchaseService(this.repo);

  Future<int> create({
    required int supplierId,
    required PaymentMethod paymentMethod,
    required DateTime date,
    required List<({int productId, double qty, double unitCost})> lines,
  }) {
    if (lines.isEmpty) {
      throw ArgumentError('La compra no tiene artículos');
    }
    final items = <PurchaseItem>[];
    double total = 0;
    for (final l in lines) {
      if (l.qty <= 0 || l.unitCost < 0) {
        throw ArgumentError('Cantidad y costo deben ser positivos');
      }
      total += l.qty * l.unitCost;
      items.add(PurchaseItem(
        purchaseId: -1,
        productId: l.productId,
        qty: l.qty,
        unitCost: l.unitCost,
      ));
    }
    final p = Purchase(
      supplierId: supplierId,
      date: date,
      paymentMethod: paymentMethod,
      total: total,
    );
    return repo.createPurchase(purchase: p, items: items);
  }
}
